import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../l10n.dart';

/// Источник аудио. Микрофон — «я», системный звук — «собеседник».
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

/// Один поток (WebSocket) к Deepgram.
/// Простой режим: v1 listen + diarize — один микрофон, спикеров определяет
/// нейронка по голосам (первый услышанный голос = «Вы»).
/// Точный режим: v2 listen / Flux — чистый поток с выбранного устройства.
class DeepgramStream {
  DeepgramStream({
    required this.source,
    required this.token,
    required this.model,
    this.languageHint = 'ru',
    this.diarize = false,
  });

  final Speaker source;
  final String token;
  final String model;
  final String languageHint;
  final bool diarize;

  WebSocketChannel? _channel;
  final _events = StreamController<DeepgramTurnEvent>.broadcast();
  final _errors = StreamController<String>.broadcast();

  int? _firstSpeaker;
  String _buffer = '';
  Speaker? _bufferSpeaker;

  Stream<DeepgramTurnEvent> get events => _events.stream;
  Stream<String> get errors => _errors.stream;

  Future<void> start() async {
    // Все потоки ходят в v1 nova-3 (стабильно работает с ключами без v2-скоупа).
    // diarize=true добавляет разделение спикеров по голосам (простой режим).
    final lang = languageHint == 'en' ? 'en' : 'multi';
    final uri = Uri.parse('wss://api.deepgram.com/v1/listen'
        '?model=nova-3&language=$lang'
        '&diarize=${diarize ? 'true' : 'false'}'
        '&interim_results=true&endpointing=500'
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
        _handleV1Results(j);
      },
      onError: (Object e) {
        debugPrint('[DG $source] ERROR: $e');
        _errors.add('Deepgram ($model): $e');
      },
      onDone: () {
        debugPrint('[DG $source] closed');
        if (!_errors.isClosed) _errors.add(S.t('errDgClosed'));
      },
    );
  }

  /// v1 + diarize: спикера определяет Deepgram по голосу.
  /// v1 шлёт речь фрагментами (is_final=true после каждой паузе endpointing),
  /// speech_final=true — конец реплики. Накапливаем фрагменты в буфер и
  /// отдаём готовую реплику одним событием; спикер — по первому фрагменту.
  void _handleV1Results(Map<String, dynamic> j) {
    if (j['type'] != 'Results') return;
    final alt =
        (((j['channel'] as Map?)?['alternatives'] as List?) ?? const [])[0];
    if (alt is! Map) return;
    final transcript = ((alt['transcript'] as String?) ?? '').trim();
    final isFinal = j['is_final'] == true;
    final speechFinal = j['speech_final'] == true;
    if (!isFinal) {
      // Промежуточный (незаконченный) фрагмент — показываем как interim.
      if (transcript.isNotEmpty) {
        _events.add(DeepgramTurnEvent(
          source: _bufferSpeaker ?? Speaker.me,
          phase: TurnPhase.update,
          turnIndex: 0,
          transcript: _buffer + transcript,
        ));
      }
      return;
    }

    // Готовый фрагмент — в буфер.
    if (transcript.isNotEmpty) {
      final words = (alt['words'] as List?) ?? const [];
      int? spk;
      for (final w in words) {
        if (w is Map && w['speaker'] is int) {
          spk = w['speaker'] as int;
          break;
        }
      }
      if (spk != null) {
        _firstSpeaker ??= spk;
        _bufferSpeaker ??= spk == _firstSpeaker ? Speaker.me : Speaker.them;
      }
      _buffer =
          _buffer.isEmpty ? transcript : '$_buffer $transcript';
    }

    if (speechFinal) {
      final text = _buffer;
      final sp = _bufferSpeaker ?? Speaker.me;
      _buffer = '';
      _bufferSpeaker = null;
      if (text.isNotEmpty) {
        debugPrint('[DG diarize] END $sp "$text"');
        _events.add(DeepgramTurnEvent(
          source: sp,
          phase: TurnPhase.end,
          turnIndex: 0,
          transcript: text,
        ));
      }
    }
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
