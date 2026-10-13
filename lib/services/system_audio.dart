import 'dart:async';

import 'package:flutter/services.dart';

/// Системный звук macOS через ScreenCaptureKit (нативный захват, без драйверов).
/// Отдаёт чанки PCM s16le 16k mono — тот же формат, что и микрофонный стрим.
class SystemAudio {
  static const _channel = EventChannel('tellmemo/system_audio');

  static Stream<dynamic> stream() => _channel.receiveBroadcastStream();
}
