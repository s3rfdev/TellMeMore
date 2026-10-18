import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Провайдеры LLM для подсказок.
enum LlmProvider { gemini, zai, openai, anthropic }

const kDefaultGeminiModel = 'gemini-3.8-flash';
const kDefaultZaiModel = 'glm-4.7-flash';
const kDefaultOpenaiModel = 'gpt-4o-mini';
const kDefaultAnthropicModel = 'claude-3-5-haiku-latest';

/// Пресеты моделей по провайдерам (name из LlmProvider).
const kModelPresets = <String, List<String>>{
  'gemini': [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
  ],
  'zai': [
    'glm-5.3-flash',
    'glm-5.3',
    'glm-5.2',
    'glm-5.1',
    'glm-4.7',
    'glm-4.6',
  ],
  'openai': ['gpt-4o-mini', 'gpt-4.1-mini', 'gpt-4o'],
  'anthropic': [
    'claude-3-5-haiku-latest',
    'claude-haiku-4-5',
    'claude-sonnet-4-5',
  ],
};

extension LlmProviderMeta on LlmProvider {
  String get label => switch (this) {
    LlmProvider.gemini => 'Google Gemini',
    LlmProvider.zai => 'Z.ai (GLM)',
    LlmProvider.openai => 'OpenAI',
    LlmProvider.anthropic => 'Anthropic Claude',
  };

  String get shortLabel => switch (this) {
    LlmProvider.gemini => 'Gemini',
    LlmProvider.zai => 'Z.ai',
    LlmProvider.openai => 'OpenAI',
    LlmProvider.anthropic => 'Claude',
  };

  String get defaultModel => switch (this) {
    LlmProvider.gemini => kDefaultGeminiModel,
    LlmProvider.zai => kDefaultZaiModel,
    LlmProvider.openai => kDefaultOpenaiModel,
    LlmProvider.anthropic => kDefaultAnthropicModel,
  };

  static LlmProvider fromName(String? name) => LlmProvider.values.firstWhere(
    (p) => p.name == name,
    orElse: () => LlmProvider.gemini,
  );
}

class LlmService {
  static const _timeout = Duration(seconds: 35);

  static Future<String> ask({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    required String prompt,
    Uint8List? imageBytes,
    List<Uint8List>? images,
  }) async {
    final imgs = images ??
        (imageBytes != null && imageBytes.isNotEmpty ? [imageBytes] : null);
    switch (provider) {
      case LlmProvider.gemini:
        return _gemini(
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          images: imgs,
        );
      case LlmProvider.zai:
        return _openAiCompatible(
          url: 'https://api.z.ai/api/paas/v4/chat/completions',
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          images: imgs,
          maxTokensField: 'max_tokens',
        );
      case LlmProvider.openai:
        return _openAiCompatible(
          url: 'https://api.openai.com/v1/chat/completions',
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          images: imgs,
          maxTokensField: 'max_completion_tokens',
        );
      case LlmProvider.anthropic:
        return _anthropic(
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          images: imgs,
        );
    }
  }

  /// Потоковый запрос подсказки.
  /// Для Google Gemini используется нативный Server-Sent Events (SSE) поток
  /// (streamGenerateContent?alt=sse), благодаря которому первые слова появляются
  /// через 300-600 мс прямо во время разговора.
  /// Для остальных провайдеров (Z.ai, OpenAI, Claude) выполняется стандартный надежный
  /// запрос ask(), гарантируя 100% стабильность и совместимость.
  static Stream<String> askStream({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    required String prompt,
    Uint8List? imageBytes,
    List<Uint8List>? images,
    http.Client? client,
  }) async* {
    final imgs = images ??
        (imageBytes != null && imageBytes.isNotEmpty ? [imageBytes] : null);
    switch (provider) {
      case LlmProvider.gemini:
        yield* _geminiStream(
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          images: imgs,
          client: client,
        );
      case LlmProvider.zai:
      case LlmProvider.openai:
      case LlmProvider.anthropic:
        final answer = await ask(
          provider: provider,
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          images: imgs,
        );
        yield answer;
    }
  }

  static Stream<String> _geminiStream({
    required String apiKey,
    required String model,
    required String prompt,
    List<Uint8List>? images,
    http.Client? client,
  }) async* {
    final parts = <Map<String, dynamic>>[];
    if (images != null) {
      for (final img in images) {
        if (img.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Encode(img),
            },
          });
        }
      }
    }
    parts.add({'text': prompt});

    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse',
        ),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['x-goog-api-key'] = apiKey;
      request.body = jsonEncode({
        'contents': [
          {'parts': parts},
        ],
        'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1500},
      });

      final streamedResponse = await httpClient.send(request).timeout(_timeout);

      if (streamedResponse.statusCode != 200) {
        final bytes = await streamedResponse.stream.toBytes();
        var detail = utf8.decode(bytes, allowMalformed: true);
        if (detail.length > 300) detail = detail.substring(0, 300);
        throw Exception('Gemini ${streamedResponse.statusCode}: $detail');
      }

      var hasYielded = false;

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final jsonStr = trimmed.substring(5).trim();
        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

        try {
          final j = jsonDecode(jsonStr) as Map<String, dynamic>;
          final candidates = j['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final first = candidates[0];
            if (first is Map) {
              final content = first['content'];
              if (content is Map) {
                final partsOut = content['parts'] as List<dynamic>?;
                if (partsOut != null) {
                  for (final p in partsOut) {
                    if (p is Map && p['text'] is String) {
                      final text = p['text'] as String;
                      if (text.isNotEmpty) {
                        hasYielded = true;
                        yield text;
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (_) {
          // Игнорируем неполные или служебные чанки SSE
        }
      }

      if (!hasYielded) {
        throw Exception('LLM вернул пустой ответ');
      }
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  static Future<String> _gemini({
    required String apiKey,
    required String model,
    required String prompt,
    List<Uint8List>? images,
  }) async {
    final parts = <Map<String, dynamic>>[];
    if (images != null) {
      for (final img in images) {
        if (img.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Encode(img),
            },
          });
        }
      }
    }
    parts.add({'text': prompt});

    final resp = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {'parts': parts},
            ],
            'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1500},
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception(_errBody('Gemini', resp));
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final candidates = j['candidates'] as List<dynamic>?;
    final content = candidates?[0] is Map ? candidates![0]['content'] : null;
    final partsOut = content is Map ? content['parts'] as List<dynamic>? : null;
    final text = partsOut?.map((p) => p is Map ? (p['text'] ?? '') : '').join();
    if (text == null || text.trim().isEmpty) {
      throw Exception('LLM вернул пустой ответ');
    }
    return text.trim();
  }

  /// Z.ai и OpenAI используют OpenAI-совместимый chat/completions.
  static Future<String> _openAiCompatible({
    required String url,
    required String apiKey,
    required String model,
    required String prompt,
    required String maxTokensField,
    List<Uint8List>? images,
  }) async {
    final dynamic content;
    final validImages =
        images?.where((img) => img.isNotEmpty).toList() ?? const [];
    if (validImages.isNotEmpty) {
      final list = <Map<String, dynamic>>[];
      list.add({'type': 'text', 'text': prompt});
      for (final img in validImages) {
        list.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,${base64Encode(img)}',
          },
        });
      }
      content = list;
    } else {
      content = prompt;
    }

    final resp = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            maxTokensField: validImages.isNotEmpty ? 1500 : 500,
            'temperature': 0.3,
            'messages': [
              {'role': 'user', 'content': content},
            ],
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception(_errBody('LLM', resp));
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = j['choices'] as List<dynamic>?;
    final message = choices?[0] is Map ? choices![0]['message'] : null;
    final text = message is Map ? (message['content'] ?? '') : '';
    if (text is! String || text.trim().isEmpty) {
      throw Exception('LLM вернул пустой ответ');
    }
    return text.trim();
  }

  static Future<String> _anthropic({
    required String apiKey,
    required String model,
    required String prompt,
    List<Uint8List>? images,
  }) async {
    final dynamic content;
    final validImages =
        images?.where((img) => img.isNotEmpty).toList() ?? const [];
    if (validImages.isNotEmpty) {
      final list = <Map<String, dynamic>>[];
      for (final img in validImages) {
        list.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': base64Encode(img),
          },
        });
      }
      list.add({'type': 'text', 'text': prompt});
      content = list;
    } else {
      content = prompt;
    }

    final resp = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': validImages.isNotEmpty ? 1500 : 500,
            'temperature': 0.3,
            'messages': [
              {'role': 'user', 'content': content},
            ],
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception(_errBody('Anthropic', resp));
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final blocks = j['content'] as List<dynamic>?;
    final text =
        blocks
            ?.map(
              (b) => b is Map && b['type'] == 'text' ? (b['text'] ?? '') : '',
            )
            .join() ??
        '';
    if (text.trim().isEmpty) {
      throw Exception('LLM вернул пустой ответ');
    }
    return text.trim();
  }

  static String _errBody(String who, http.Response resp) {
    var detail = utf8.decode(resp.bodyBytes, allowMalformed: true);
    if (detail.length > 300) detail = detail.substring(0, 300);
    return '$who ${resp.statusCode}: $detail';
  }
}
