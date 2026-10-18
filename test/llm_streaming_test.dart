import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tellmemore/services/llm_service.dart';
import 'package:tellmemore/session.dart';

class _FakeStreamClient extends http.BaseClient {
  _FakeStreamClient(this._handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler(request);
}

void main() {
  group('LlmService.askStream tests', () {
    test('Gemini streams tokens sequentially from SSE response', () async {
      final client = _FakeStreamClient((request) async {
        expect(request.url.path, contains('streamGenerateContent'));
        expect(request.url.queryParameters['alt'], equals('sse'));
        expect(request.headers['x-goog-api-key'], equals('test-key'));
        expect(request.headers['Content-Type'], contains('application/json'));

        if (request is http.Request) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['contents'], isNotEmpty);
        }

        final sseChunks = [
          'data: {"candidates":[{"content":{"parts":[{"text":"Для решения этой задачи"}]}}]}\n\n',
          ': comment line to ignore\n\n',
          'data: {"candidates":[{"content":{"parts":[{"text":" используйте алгоритм DFS."}]}}]}\n\n',
          'data: [DONE]\n\n',
        ];

        final stream = Stream<List<int>>.fromIterable(
          sseChunks.map((chunk) => utf8.encode(chunk)),
        );
        return http.StreamedResponse(stream, 200);
      });

      final tokens = await LlmService.askStream(
        provider: LlmProvider.gemini,
        apiKey: 'test-key',
        model: 'gemini-3.8-flash',
        prompt: 'Как решить задачу?',
        client: client,
      ).toList();

      expect(tokens, equals(['Для решения этой задачи', ' используйте алгоритм DFS.']));
    });

    test('Gemini stream with imageBytes adds inline_data part', () async {
      final fakeImage = Uint8List.fromList([1, 2, 3, 4]);
      var checkedImageInBody = false;

      final client = _FakeStreamClient((request) async {
        if (request is http.Request) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final contents = body['contents'] as List<dynamic>;
          final parts = contents[0]['parts'] as List<dynamic>;
          expect(parts.length, equals(2));
          expect(parts[0]['inline_data']['mime_type'], equals('image/jpeg'));
          expect(parts[0]['inline_data']['data'], equals(base64Encode(fakeImage)));
          expect(parts[1]['text'], equals('Explain code'));
          checkedImageInBody = true;
        }

        final stream = Stream<List<int>>.fromIterable([
          utf8.encode('data: {"candidates":[{"content":{"parts":[{"text":"Answer with image"}]}}]}\n\n'),
        ]);
        return http.StreamedResponse(stream, 200);
      });

      final tokens = await LlmService.askStream(
        provider: LlmProvider.gemini,
        apiKey: 'test-key',
        model: 'gemini-3.8-flash',
        prompt: 'Explain code',
        imageBytes: fakeImage,
        client: client,
      ).toList();

      expect(checkedImageInBody, isTrue);
      expect(tokens, equals(['Answer with image']));
    });

    test('Gemini stream with multiple images adds multiple inline_data parts', () async {
      final img1 = Uint8List.fromList([1, 2]);
      final img2 = Uint8List.fromList([3, 4]);
      var checkedParts = false;

      final client = _FakeStreamClient((request) async {
        if (request is http.Request) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final contents = body['contents'] as List<dynamic>;
          final parts = contents[0]['parts'] as List<dynamic>;
          expect(parts.length, equals(3));
          expect(parts[0]['inline_data']['data'], equals(base64Encode(img1)));
          expect(parts[1]['inline_data']['data'], equals(base64Encode(img2)));
          expect(parts[2]['text'], equals('Explain 2 screenshots'));
          checkedParts = true;
        }

        final stream = Stream<List<int>>.fromIterable([
          utf8.encode('data: {"candidates":[{"content":{"parts":[{"text":"Answer with 2 images"}]}}]}\n\n'),
        ]);
        return http.StreamedResponse(stream, 200);
      });

      final tokens = await LlmService.askStream(
        provider: LlmProvider.gemini,
        apiKey: 'test-key',
        model: 'gemini-3.8-flash',
        prompt: 'Explain 2 screenshots',
        images: [img1, img2],
        client: client,
      ).toList();

      expect(checkedParts, isTrue);
      expect(tokens, equals(['Answer with 2 images']));
    });

    test('Gemini stream throws on non-200 HTTP status', () async {
      final client = _FakeStreamClient((request) async {
        final stream = Stream<List<int>>.fromIterable([
          utf8.encode('{"error":{"message":"API_KEY_INVALID"}}'),
        ]);
        return http.StreamedResponse(stream, 403);
      });

      expect(
        () => LlmService.askStream(
          provider: LlmProvider.gemini,
          apiKey: 'invalid-key',
          model: 'gemini-3.8-flash',
          prompt: 'test',
          client: client,
        ).toList(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 403'),
        )),
      );
    });

    test('Gemini stream throws when response is empty', () async {
      final client = _FakeStreamClient((request) async {
        final stream = Stream<List<int>>.fromIterable([
          utf8.encode('data: {}\n\n'),
        ]);
        return http.StreamedResponse(stream, 200);
      });

      expect(
        () => LlmService.askStream(
          provider: LlmProvider.gemini,
          apiKey: 'key',
          model: 'gemini-3.8-flash',
          prompt: 'test',
          client: client,
        ).toList(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('LLM вернул пустой ответ'),
        )),
      );
    });

    test('Non-Gemini providers route to standard ask and yield single token safely', () async {
      final client = MockClient((request) async {
        expect(request.url.host, equals('api.openai.com'));
        final responseBody = jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'OpenAI answer'},
            }
          ]
        });
        return http.Response(responseBody, 200);
      });

      await http.runWithClient(() async {
        final tokens = await LlmService.askStream(
          provider: LlmProvider.openai,
          apiKey: 'sk-test',
          model: 'gpt-4o-mini',
          prompt: 'Hello OpenAI',
        ).toList();

        expect(tokens, equals(['OpenAI answer']));
      }, () => client);
    });
  });

  group('Session streaming and UI control tests', () {
    test('Session stopHelp cancels stream and preserves already received tokens', () async {
      final session = Session();
      session.helpLoading = true;
      session.helpAnswer = 'Первая часть ответа';

      expect(session.helpLoading, isTrue);
      expect(session.helpAnswer, equals('Первая часть ответа'));

      session.stopHelp();

      expect(session.helpLoading, isFalse);
      expect(session.helpAnswer, equals('Первая часть ответа'));
    });
  });
}
