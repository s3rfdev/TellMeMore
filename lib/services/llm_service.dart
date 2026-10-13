import 'dart:convert';

import 'package:http/http.dart' as http;

/// Провайдеры LLM для подсказок.
enum LlmProvider { gemini, zai, openai, anthropic }

const kDefaultGeminiModel = 'gemini-3.5-flash-lite';
const kDefaultZaiModel = 'glm-5.3-flash';
const kDefaultOpenaiModel = 'gpt-4o-mini';
const kDefaultAnthropicModel = 'claude-3-5-haiku-latest';

/// Пресеты моделей по провайдерам (name из LlmProvider).
const kModelPresets = <String, List<String>>{
  'gemini': [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
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

  static LlmProvider fromName(String? name) =>
      LlmProvider.values.firstWhere((p) => p.name == name,
          orElse: () => LlmProvider.gemini);
}

class LlmService {
  static const _timeout = Duration(seconds: 30);

  static Future<String> ask({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    switch (provider) {
      case LlmProvider.gemini:
        return _gemini(apiKey: apiKey, model: model, prompt: prompt);
      case LlmProvider.zai:
        return _openAiCompatible(
          url: 'https://api.z.ai/api/paas/v4/chat/completions',
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          maxTokensField: 'max_tokens',
        );
      case LlmProvider.openai:
        return _openAiCompatible(
          url: 'https://api.openai.com/v1/chat/completions',
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          maxTokensField: 'max_completion_tokens',
        );
      case LlmProvider.anthropic:
        return _anthropic(apiKey: apiKey, model: model, prompt: prompt);
    }
  }

  static Future<String> _gemini({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    final resp = await http
        .post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 300},
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception(_errBody('Gemini', resp));
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final candidates = j['candidates'] as List<dynamic>?;
    final content = candidates?[0] is Map ? candidates![0]['content'] : null;
    final parts = content is Map ? content['parts'] as List<dynamic>? : null;
    final text = parts?.map((p) => p is Map ? (p['text'] ?? '') : '').join();
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
  }) async {
    final resp = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            maxTokensField: 300,
            'temperature': 0.4,
            'messages': [
              {'role': 'user', 'content': prompt}
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
  }) async {
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
            'max_tokens': 300,
            'temperature': 0.4,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception(_errBody('Anthropic', resp));
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final blocks = j['content'] as List<dynamic>?;
    final text = blocks
            ?.map((b) => b is Map && b['type'] == 'text' ? (b['text'] ?? '') : '')
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
