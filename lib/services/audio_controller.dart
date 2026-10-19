// lib/services/audio_controller.dart
//
// Manages dual-station audio capture: candidate microphone (local) and interviewer
// voice (local BlackHole/cable or remote Mac over TCP/SSH). Streams PCM to Deepgram.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../l10n.dart';
import 'config_store.dart';
import 'deepgram_stream.dart';

export 'config_store.dart'
    show kRemoteMacDeviceId, kRemoteMacMicDeviceId, kSystemAudioDeviceId;

/// Controller responsible for all audio hardware, sockets, and Deepgram streams.
class AudioController {
  AudioRecorder? _recorder;
  AudioRecorder? _themRecorder;
  Socket? _remoteSocket;
  Socket? _remoteMicSocket;
  Process? _remoteAudioProcess;
  Process? _remoteMicAudioProcess;
  DeepgramStream? _micStream;
  DeepgramStream? _themStream;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<dynamic>? _themAudioSub;
  StreamSubscription<dynamic>? _remoteMicSub;
  final _eventSubs = <StreamSubscription<dynamic>>[];

  int _sessionGeneration = 0;

  bool get themActive => _themStream != null;

  /// Discovers audio input devices and filters out internal macOS aggregate devices.
  Future<List<InputDevice>> loadAudioDevices(AppConfig config) async {
    try {
      final rec = AudioRecorder();
      final list = await rec.listInputDevices();
      await rec.dispose();
      debugPrint(
        '[AUDIO] Discovered devices: ${list.map((d) => "${d.label} [${d.id}]").toList()}',
      );
      final devices = list.where(_isUserFacingDevice).toList();
      if (config.remoteMacHost.isNotEmpty) {
        devices.insert(
          0,
          const InputDevice(
            id: kRemoteMacMicDeviceId,
            label: 'Микрофон с Mac (по SSH)',
          ),
        );
        devices.insert(
          1,
          const InputDevice(
            id: kRemoteMacDeviceId,
            label: 'Звук с Mac (BlackHole по SSH)',
          ),
        );
      }
      if (config.myDeviceId.isNotEmpty &&
          !devices.any((d) => d.id == config.myDeviceId)) {
        config.myDeviceId = '';
      }
      if (config.remoteMacHost.isNotEmpty && config.myDeviceId.isEmpty) {
        config.myDeviceId = kRemoteMacMicDeviceId;
      }
      _ensureDefaultThemDevice(config, devices);
      return devices;
    } catch (_) {
      return [];
    }
  }

  void _ensureDefaultThemDevice(
    AppConfig config,
    List<InputDevice> audioDevices,
  ) {
    if (config.remoteMacHost.isNotEmpty) {
      config.themDeviceId = kRemoteMacDeviceId;
      return;
    }
    final currentThemExists = config.themDeviceId.isNotEmpty &&
        config.themDeviceId != '__sckit__' &&
        audioDevices.any((d) => d.id == config.themDeviceId);
    if (!currentThemExists) {
      InputDevice? virtualDevice;
      for (final d in audioDevices) {
        final l = d.label.toLowerCase();
        final id = d.id.toLowerCase();
        if (l.contains('blackhole') ||
            id.contains('blackhole') ||
            l.contains('cable') ||
            id.contains('cable')) {
          virtualDevice = d;
          break;
        }
      }
      if (virtualDevice != null) {
        config.themDeviceId = virtualDevice.id;
      } else {
        config.themDeviceId = '';
      }
    }
  }

  static bool _isUserFacingDevice(InputDevice d) {
    final l = d.label.toLowerCase();
    final id = d.id.toLowerCase();
    if (l.contains('cadefaultdeviceaggregate') ||
        id.contains('cadefaultdeviceaggregate')) {
      return false;
    }
    if (l.contains('aggregate-') || id.contains('aggregate-')) return false;
    return true;
  }

  /// Starts live streaming audio to Deepgram.
  Future<void> startStream({
    required AppConfig config,
    required void Function(DeepgramTurnEvent event) onTurnEvent,
    required void Function(String error) onMicError,
    required void Function(String error) onThemError,
  }) async {
    final gen = ++_sessionGeneration;
    try {
      final isRemoteMic = config.remoteMacHost.isNotEmpty &&
          config.myDeviceId == kRemoteMacMicDeviceId;

      if (!isRemoteMic) {
        _recorder = AudioRecorder();
        final granted = await _recorder!.hasPermission();
        if (_sessionGeneration != gen) {
          await teardown();
          return;
        }
        if (!granted) {
          throw Exception(S.t('errMicDenied'));
        }
      }

      _micStream = DeepgramStream(
        source: Speaker.me,
        token: config.deepgramToken,
        model: config.deepgramModel,
        languageHint: config.languageHint,
        diarize: false,
      );
      _eventSubs.add(_micStream!.events.listen(onTurnEvent));
      _eventSubs.add(_micStream!.errors.listen(onMicError));
      await _micStream!.start();

      if (isRemoteMic) {
        await _startRemoteMacMicStream(
          config: config,
          onMicError: onMicError,
        );
      } else {
        Stream<Uint8List> audio;
        try {
          debugPrint(
            '[AUDIO me] starting stream with device: ${config.myDeviceId.isNotEmpty ? config.myDeviceId : "default"}',
          );
          audio = await _recorder!.startStream(
            RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
              device: config.myDeviceId.isNotEmpty
                  ? InputDevice(id: config.myDeviceId, label: config.myDeviceId)
                  : null,
            ),
          );
        } catch (err) {
          debugPrint(
            '[AUDIO me] Failed with device "${config.myDeviceId}": $err. Retrying with default device...',
          );
          audio = await _recorder!.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
              device: null,
            ),
          );
        }
        var micChunks = 0;
        debugPrint('[AUDIO me] stream started successfully');
        _audioSub = audio.listen((chunk) {
          micChunks++;
          if (micChunks % 50 == 1) {
            debugPrint('[AUDIO me] chunk #$micChunks ${chunk.length}B');
          }
          _micStream?.send(chunk);
        }, onError: (Object e) => onMicError('Микрофон: $e'));
      }

      // Второй поток — голос собеседника (BlackHole, Remote Mac через SSH или выбранное аудиоустройство).
      if (config.remoteMacHost.isNotEmpty &&
          config.themDeviceId == kRemoteMacDeviceId) {
        await _startRemoteMacStream(
          config: config,
          onTurnEvent: onTurnEvent,
          onThemError: onThemError,
        );
      } else if (config.themDeviceId.isNotEmpty &&
          config.themDeviceId != kSystemAudioDeviceId) {
        await _startLocalThemStream(
          config: config,
          onTurnEvent: onTurnEvent,
          onThemError: onThemError,
        );
      }
    } catch (e, st) {
      debugPrint('[AUDIO startStream FATAL]: $e\n$st');
      await teardown();
      rethrow;
    }
  }

  Future<void> _ensureRemoteRelayRunning(AppConfig config) async {
    if (config.remoteMacHost.isEmpty) return;
    try {
      final user =
          config.remoteMacUser.isNotEmpty ? config.remoteMacUser : 'vanmac';
      await Process.run('ssh', [
        '-T',
        '-q',
        '-o',
        'StrictHostKeyChecking=no',
        '$user@${config.remoteMacHost}',
        'launchctl load ~/Library/LaunchAgents/com.tellmemore.audiorelay.plist 2>/dev/null; nohup python3 /Users/vanmac/sobes123/audio_relay_server.py >/dev/null 2>&1 &',
      ]).timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  Future<void> _startRemoteMacMicStream({
    required AppConfig config,
    required void Function(String) onMicError,
  }) async {
    try {
      debugPrint('[MIC remote] connecting to TCP ${config.remoteMacHost}:5006...');
      var micChunks = 0;
      final micBuffer = BytesBuilder(copy: false);
      const targetChunkSize = 3200; // 100ms at 16kHz 16-bit mono

      void handleData(List<int> chunk) {
        micBuffer.add(chunk);
        while (micBuffer.length >= targetChunkSize) {
          final bytes = micBuffer.takeBytes();
          final toSend = bytes.sublist(0, targetChunkSize);
          if (bytes.length > targetChunkSize) {
            micBuffer.add(bytes.sublist(targetChunkSize));
          }
          micChunks++;
          if (micChunks % 50 == 1) {
            debugPrint('[AUDIO me remote] chunk #$micChunks ${toSend.length}B');
          }
          _micStream?.send(toSend);
        }
      }

      Socket? socket;
      try {
        socket = await Socket.connect(
          config.remoteMacHost,
          5006,
          timeout: const Duration(milliseconds: 2000),
        );
      } catch (_) {
        debugPrint('[MIC remote] TCP connect failed, waking relay on Mac...');
        await _ensureRemoteRelayRunning(config);
        try {
          socket = await Socket.connect(
            config.remoteMacHost,
            5006,
            timeout: const Duration(milliseconds: 2500),
          );
        } catch (e) {
          onMicError(
              'Микрофон (Mac): не удалось подключиться к аудио-серверу на ${config.remoteMacHost}:5006 ($e)');
          return;
        }
      }

      socket.setOption(SocketOption.tcpNoDelay, true);
      _remoteMicSocket = socket;
      debugPrint('[MIC remote] TCP connected successfully!');
      _remoteMicSub = socket.listen(
        handleData,
        onError: (Object e) => onMicError('Микрофон (Mac TCP): $e'),
        onDone: () => debugPrint('[MIC remote] TCP disconnected'),
      );
    } catch (e) {
      onMicError('Микрофон (Mac): $e');
    }
  }

  Future<void> _startRemoteMacStream({
    required AppConfig config,
    required void Function(DeepgramTurnEvent) onTurnEvent,
    required void Function(String) onThemError,
  }) async {
    try {
      debugPrint('[THEM remote] stream starting from ${config.remoteMacHost}...');
      _themStream = DeepgramStream(
        source: Speaker.them,
        token: config.deepgramToken,
        model: config.deepgramModel,
        languageHint: config.languageHint,
        diarize: false,
      );
      _eventSubs.add(_themStream!.events.listen(onTurnEvent));
      _eventSubs.add(_themStream!.errors.listen(onThemError));
      await _themStream!.start();
      debugPrint('[THEM remote] ws requested');

      var themChunks = 0;
      final themBuffer = BytesBuilder(copy: false);
      const targetChunkSize = 3200; // 100ms at 16kHz 16-bit mono

      void handleData(List<int> chunk) {
        themBuffer.add(chunk);
        while (themBuffer.length >= targetChunkSize) {
          final bytes = themBuffer.takeBytes();
          final toSend = bytes.sublist(0, targetChunkSize);
          if (bytes.length > targetChunkSize) {
            themBuffer.add(bytes.sublist(targetChunkSize));
          }
          themChunks++;
          if (themChunks % 50 == 1) {
            debugPrint('[AUDIO them remote] chunk #$themChunks ${toSend.length}B');
          }
          _themStream?.send(toSend);
        }
      }

      Socket? socket;
      try {
        socket = await Socket.connect(
          config.remoteMacHost,
          5005,
          timeout: const Duration(milliseconds: 2000),
        );
      } catch (_) {
        debugPrint('[THEM remote] TCP connect failed, waking relay on Mac...');
        await _ensureRemoteRelayRunning(config);
        try {
          socket = await Socket.connect(
            config.remoteMacHost,
            5005,
            timeout: const Duration(milliseconds: 2500),
          );
        } catch (e) {
          onThemError(
              'Собеседник (Mac): не удалось подключиться к аудио-серверу на ${config.remoteMacHost}:5005 ($e)');
          return;
        }
      }

      socket.setOption(SocketOption.tcpNoDelay, true);
      _remoteSocket = socket;
      debugPrint('[THEM remote] TCP connected successfully!');
      _themAudioSub = socket.listen(
        handleData,
        onError: (Object e) => onThemError('Собеседник (Mac TCP): $e'),
        onDone: () => debugPrint('[THEM remote] TCP disconnected'),
      );
    } catch (e) {
      onThemError('Собеседник (Mac): $e');
    }
  }

  Future<void> _startLocalThemStream({
    required AppConfig config,
    required void Function(DeepgramTurnEvent) onTurnEvent,
    required void Function(String) onThemError,
  }) async {
    try {
      debugPrint('[THEM] init: device=${config.themDeviceId}');
      _themStream = DeepgramStream(
        source: Speaker.them,
        token: config.deepgramToken,
        model: config.deepgramModel,
        languageHint: config.languageHint,
        diarize: false,
      );
      _eventSubs.add(_themStream!.events.listen(onTurnEvent));
      _eventSubs.add(_themStream!.errors.listen(onThemError));
      await _themStream!.start();
      debugPrint('[THEM] ws requested');
      _themRecorder = AudioRecorder();
      final themAudio = await _themRecorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          device: InputDevice(
            id: config.themDeviceId,
            label: config.themDeviceId,
          ),
        ),
      );
      debugPrint('[THEM] recorder ok');
      var themChunks = 0;
      _themAudioSub = themAudio.listen((chunk) {
        themChunks++;
        if (themChunks % 50 == 1) {
          debugPrint('[AUDIO them] chunk #$themChunks ${chunk.length}B');
        }
        _themStream?.send(chunk);
      }, onError: (Object e) => onThemError('Собеседник: $e'));
    } catch (e) {
      onThemError('Собеседник: $e');
    }
  }

  /// Shuts down interviewer stream only (when interviewer audio fails).
  void stopThemStream() {
    try {
      _themAudioSub?.cancel();
      _themAudioSub = null;
      _themStream?.stop();
      _themStream = null;
      _themRecorder?.stop();
      _themRecorder?.dispose();
      _themRecorder = null;
      _remoteAudioProcess?.kill();
      _remoteAudioProcess = null;
      _remoteSocket?.destroy();
      _remoteSocket = null;
    } catch (_) {}
  }

  /// Complete teardown of all recording hardware and connections.
  Future<void> teardown() async {
    _sessionGeneration++;
    try {
      await _audioSub?.cancel();
    } catch (_) {}
    _audioSub = null;

    try {
      await _themAudioSub?.cancel();
    } catch (_) {}
    _themAudioSub = null;

    try {
      await _remoteMicSub?.cancel();
    } catch (_) {}
    _remoteMicSub = null;

    try {
      _remoteSocket?.destroy();
    } catch (_) {}
    _remoteSocket = null;

    try {
      _remoteMicSocket?.destroy();
    } catch (_) {}
    _remoteMicSocket = null;

    try {
      _remoteAudioProcess?.kill();
    } catch (_) {}
    _remoteAudioProcess = null;

    try {
      _remoteMicAudioProcess?.kill();
    } catch (_) {}
    _remoteMicAudioProcess = null;

    final mic = _micStream;
    _micStream = null;
    if (mic != null) {
      try {
        await mic.stop().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => null,
        );
      } catch (_) {}
    }

    final them = _themStream;
    _themStream = null;
    if (them != null) {
      try {
        await them.stop().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => null,
        );
      } catch (_) {}
    }

    for (final s in _eventSubs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _eventSubs.clear();

    final rec = _recorder;
    _recorder = null;
    if (rec != null) {
      try {
        await rec.stop().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => null,
        );
      } catch (_) {}
      try {
        await rec.dispose().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => null,
        );
      } catch (_) {}
    }

    final themRec = _themRecorder;
    _themRecorder = null;
    if (themRec != null) {
      try {
        await themRec.stop().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => null,
        );
      } catch (_) {}
      try {
        await themRec.dispose().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => null,
        );
      } catch (_) {}
    }
  }

  Future<void> dispose() => teardown();
}
