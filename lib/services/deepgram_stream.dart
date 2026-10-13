import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../l10n.dart';

/// Источник аудио. Микрофон — «я», системный звук — «собеседник».
/// Разделение спикеров делаем двумя независимыми потоками, диаризация не нужна.
enum Speaker { me, them }

enum TurnPhase { start, update, end }

class DeepgramTurnEvent {
  DeepgramTurnEvent({
    required this.source,
    required this.phase,
    required this.turnIndex,
    required this.transcript,
    this.eotConfidence,
  });

  final Speaker source;
  final TurnPhase phase;
  final int turnIndex;
  final String transcript;
  final double? eotConfidence;
}

/// Один поток (WebSocket) к Deepgram v2 listen / Flux.
/// Принимает сырой PCM s16le 16 kHz mono, отдаёт события TurnInfo.
class DeepgramStream {
  DeepgramStream({
    required this.source,
    required this.token,
    required this.model,
    this.languageHint = 'ru',
  });

  final Speaker source;
  final String token;
  final String model;
  final String languageHint;

  WebSocketChannel? _channel;
  final _events = StreamController<DeepgramTurnEvent>.broadcast();
  final _errors = StreamController<String>.broadcast();

  Stream<DeepgramTurnEvent> get events => _events.stream;
  Stream<String> get errors => _errors.stream;

  Future<void> start() async {
    final uri = Uri.parse('wss://api.deepgram.com/v2/listen'
        '?model=$model'
        '&language_hint=$languageHint'
        '&eot_threshold=0.7'
        '&eot_timeout_ms=5000'
        '&encoding=linear16&sample_rate=16000');
    final channel =
        IOWebSocketChannel.connect(uri, headers: {'Authorization': 'Token $token'});
    _channel = channel;

    channel.stream.listen(
      (data) {
        if (data is! String) return;
        final Map<String, dynamic> j;
        try {
          j = jsonDecode(data) as Map<String, dynamic>;
        } on FormatException {
          return;
        }
        if (j['type'] != 'TurnInfo') return;
        final phase = switch (j['event']) {
          'StartOfTurn' => TurnPhase.start,
          'EndOfTurn' => TurnPhase.end,
          _ => TurnPhase.update,
        };
        _events.add(DeepgramTurnEvent(
          source: source,
          phase: phase,
          turnIndex: (j['turn_index'] as num?)?.toInt() ?? 0,
          transcript: (j['transcript'] as String?) ?? '',
          eotConfidence: (j['end_of_turn_confidence'] as num?)?.toDouble(),
        ));
      },
      onError: (Object e) => _errors.add('Deepgram ($model): $e'),
      onDone: () {
        if (!_errors.isClosed) _errors.add(S.t('errDgClosed'));
      },
    );
  }

  void send(Uint8List chunk) {
    _channel?.sink.add(chunk);
  }

  Future<void> stop() async {
    final c = _channel;
    _channel = null;
    await c?.sink.close();
  }
}
