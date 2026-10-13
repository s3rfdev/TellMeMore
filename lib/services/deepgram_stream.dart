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
  String _interim = '';

  Stream<DeepgramTurnEvent> get events => _events.stream;
  Stream<String> get errors => _errors.stream;

  Future<void> start() async {
    final Uri uri;
    if (diarize) {
      final lang = languageHint == 'en' ? 'en' : 'multi';
      uri = Uri.parse('wss://api.deepgram.com/v1/listen'
          '?model=nova-3&language=$lang'
          '&diarize=true&interim_results=true&endpointing=500'
          '&encoding=linear16&sample_rate=16000');
    } else {
      uri = Uri.parse('wss://api.deepgram.com/v2/listen'
          '?model=$model'
          '&language_hint=$languageHint'
          '&eot_threshold=0.7'
          '&eot_timeout_ms=5000'
          '&encoding=linear16&sample_rate=16000');
    }
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
        if (diarize) {
          _handleV1Results(j);
        } else {
          _handleV2TurnInfo(j);
        }
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

  /// v2 Flux: события TurnInfo.
  void _handleV2TurnInfo(Map<String, dynamic> j) {
    if (j['type'] != 'TurnInfo') return;
    final phase = switch (j['event']) {
      'StartOfTurn' => TurnPhase.start,
      'EndOfTurn' => TurnPhase.end,
      _ => TurnPhase.update,
    };
    final t = (j['transcript'] as String?) ?? '';
    if (t.trim().isNotEmpty || phase != TurnPhase.update) {
      debugPrint('[DG $source] $phase "$t"');
    }
    _events.add(DeepgramTurnEvent(
      source: source,
      phase: phase,
      turnIndex: (j['turn_index'] as num?)?.toInt() ?? 0,
      transcript: t,
      eotConfidence: (j['end_of_turn_confidence'] as num?)?.toDouble(),
    ));
  }

  /// v1 + diarize: спикера определяет Deepgram по голосу.
  void _handleV1Results(Map<String, dynamic> j) {
    if (j['type'] != 'Results') return;
    final alt =
        (((j['channel'] as Map?)?['alternatives'] as List?) ?? const [])[0];
    if (alt is! Map) return;
    final transcript = ((alt['transcript'] as String?) ?? '').trim();
    final words = (alt['words'] as List?) ?? const [];
    int? spk;
    for (final w in words) {
      if (w is Map && w['speaker'] is int) {
        spk = w['speaker'] as int;
        break;
      }
    }
    Speaker sp = source;
    if (spk != null) {
      _firstSpeaker ??= spk;
      sp = spk == _firstSpeaker ? Speaker.me : Speaker.them;
    }
    final isUtteranceEnd =
        (j['is_final'] == true) && (j['speech_final'] == true);
    if (isUtteranceEnd) {
      final text = transcript.isNotEmpty ? transcript : _interim;
      _interim = '';
      if (text.isNotEmpty) {
        debugPrint('[DG diarize] END spk=$spk($sp) "$text"');
        _events.add(DeepgramTurnEvent(
          source: sp,
          phase: TurnPhase.end,
          turnIndex: 0,
          transcript: text,
        ));
      }
    } else {
      _interim = transcript;
      if (transcript.isNotEmpty) {
        _events.add(DeepgramTurnEvent(
          source: sp,
          phase: TurnPhase.update,
          turnIndex: 0,
          transcript: transcript,
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
