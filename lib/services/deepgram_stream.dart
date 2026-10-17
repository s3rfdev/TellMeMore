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
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final Speaker source;
  final TurnPhase phase;
  final int turnIndex;
  final String transcript;
  final double? eotConfidence;
  final DateTime timestamp;
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
  Timer? _keepAliveTimer;
  bool _manuallyClosed = false;
  final _events = StreamController<DeepgramTurnEvent>.broadcast();
  final _errors = StreamController<String>.broadcast();

  int? _firstSpeaker;
  String _buffer = '';
  Speaker? _bufferSpeaker;
  DateTime? _turnStartTime;

  Stream<DeepgramTurnEvent> get events => _events.stream;
  Stream<String> get errors => _errors.stream;

  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  Future<void> start() async {
    _manuallyClosed = false;
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    await _connect();
  }

  Future<void> _connect() async {
    // Все потоки ходят в v1 nova-3 (стабильно работает с ключами без v2-скоупа).
    // diarize=true добавляет разделение спикеров по голосам (простой режим).
    final lang = languageHint == 'en' ? 'en' : 'multi';
    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen'
      '?model=nova-3&language=$lang'
      '&diarize=${diarize ? 'true' : 'false'}'
      '&interim_results=true&endpointing=500'
      '&encoding=linear16&sample_rate=16000',
    );
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Token $token'},
    );
    _channel = channel;

    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'KeepAlive'}));
      } catch (_) {}
    });

    channel.stream.listen(
      (data) {
        _reconnectAttempts = 0;
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
        _keepAliveTimer?.cancel();
        if (!_manuallyClosed) {
          debugPrint('[DG $source] error: $e, attempting recovery...');
          _scheduleReconnect();
        }
      },
      onDone: () {
        _keepAliveTimer?.cancel();
        if (!_manuallyClosed) {
          debugPrint('[DG $source] closed unexpectedly, attempting recovery...');
          _scheduleReconnect();
        } else {
          debugPrint('[DG $source] closed normally');
        }
      },
    );
  }

  void _scheduleReconnect() {
    if (_manuallyClosed || _isReconnecting) return;
    if (_reconnectAttempts >= 5) {
      debugPrint('[DG $source] max reconnect attempts reached');
      if (!_manuallyClosed && !_errors.isClosed) {
        _errors.add(S.t('errDgClosed'));
      }
      return;
    }
    _isReconnecting = true;
    _reconnectAttempts++;
    final delay = Duration(milliseconds: 600 * _reconnectAttempts);
    debugPrint(
        '[DG $source] reconnecting in ${delay.inMilliseconds}ms (attempt $_reconnectAttempts)...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_manuallyClosed) return;
      try {
        await _connect();
        _isReconnecting = false;
        debugPrint('[DG $source] reconnected successfully!');
      } catch (e) {
        _isReconnecting = false;
        _scheduleReconnect();
      }
    });
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
        _turnStartTime ??= DateTime.now();
        final fullInterim =
            _buffer.isEmpty ? transcript : '$_buffer $transcript';
        _events.add(
          DeepgramTurnEvent(
            source: diarize ? (_bufferSpeaker ?? source) : source,
            phase: TurnPhase.update,
            turnIndex: 0,
            transcript: fullInterim,
            timestamp: _turnStartTime,
          ),
        );
      }
      return;
    }

    // Готовый фрагмент — в буфер.
    if (transcript.isNotEmpty) {
      _turnStartTime ??= DateTime.now();
      if (diarize) {
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
      } else {
        _bufferSpeaker = source;
      }
      _buffer = _buffer.isEmpty ? transcript : '$_buffer $transcript';
    }

    final trimmed = _buffer.trim();
    final isSentenceEnd = trimmed.endsWith('.') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?') ||
        trimmed.endsWith('…');
    final isLongBuffer = trimmed.length >= 90;

    // Завершаем реплику, если пришёл speech_final, либо закончилось предложение,
    // либо буфер длинный (чтобы непрерывная речь не копилась в один огромный блок).
    if (speechFinal || (isFinal && (isSentenceEnd || isLongBuffer))) {
      final text = _buffer.trim();
      final sp = diarize ? (_bufferSpeaker ?? source) : source;
      final startTime = _turnStartTime ?? DateTime.now();
      _buffer = '';
      _bufferSpeaker = null;
      _turnStartTime = null;
      if (text.isNotEmpty) {
        debugPrint('[DG $source] END $sp "$text"');
        _events.add(
          DeepgramTurnEvent(
            source: sp,
            phase: TurnPhase.end,
            turnIndex: 0,
            transcript: text,
            timestamp: startTime,
          ),
        );
      }
    }
  }

  void send(Uint8List chunk) {
    if (_manuallyClosed) return;
    try {
      _channel?.sink.add(chunk);
    } catch (_) {}
  }

  Future<void> stop() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    final c = _channel;
    _channel = null;
    try {
      await c?.sink.close();
    } catch (_) {}
  }
}
