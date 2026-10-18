import 'dart:io';

import 'package:flutter/services.dart';

/// Сервис взаимодействия с нативным окном macOS:
/// - перетаскивание окна
/// - защита от захвата экрана при демонстрации (Zoom, Meet, Teams, скриншоты)
/// - режим «поверх всех окон»
class WindowService {
  static const _channel = MethodChannel('tellmemo/window');

  /// Начать перетаскивание окна macOS по текущему событию указателя.
  static Future<void> drag() async {
    try {
      await _channel.invokeMethod('dragWindow');
    } catch (_) {}
  }

  /// Установить режим невидимости окна для захвата экрана:
  /// true  => NSWindow.SharingType.none (окно не видно в трансляциях и скриншотах)
  /// false => NSWindow.SharingType.readOnly (стандартный режим)
  static Future<void> setScreenShareHidden(bool hidden) async {
    try {
      await _channel.invokeMethod('setScreenShareHidden', {'hidden': hidden});
    } catch (_) {}
  }

  /// Установить плавающий режим окна (поверх всех остальных окон):
  /// true  => NSWindow.Level.floating
  /// false => NSWindow.Level.normal
  static Future<void> setAlwaysOnTop(bool onTop) async {
    try {
      await _channel.invokeMethod('setAlwaysOnTop', {'alwaysOnTop': onTop});
    } catch (_) {}
  }

  /// Установить прозрачность нативного окна (0.1..1.0)
  static Future<void> setWindowOpacity(double opacity) async {
    try {
      await _channel.invokeMethod('setWindowOpacity', {'opacity': opacity});
    } catch (_) {}
  }

  /// Сделать скриншот экрана без окна TellMeMore.
  /// При указании remoteMacHost выполняет удалённый захват экрана Mac через SSH.
  /// Возвращает JPEG байты (Uint8List).
  static Future<Uint8List?> captureScreen({
    String remoteMacHost = '',
    String remoteMacUser = '',
  }) async {
    if (remoteMacHost.isNotEmpty) {
      try {
        final user = remoteMacUser.isNotEmpty ? remoteMacUser : 'vanmac';
        final cmd =
            "screencapture -x -t jpg /tmp/mac_cap.jpg && sips -Z 1536 /tmp/mac_cap.jpg >/dev/null && cat /tmp/mac_cap.jpg";
        final result = await Process.run(
          'ssh',
          ['-T', '-q', '-o', 'StrictHostKeyChecking=no', '$user@$remoteMacHost', cmd],
          stdoutEncoding: null,
        );
        if (result.exitCode == 0 && result.stdout is List<int>) {
          final bytes = Uint8List.fromList(result.stdout as List<int>);
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (_) {}
    }
    return _channel.invokeMethod<Uint8List>('captureScreen');
  }

  /// Открыть раздел настроек macOS: Запись экрана
  static Future<void> openScreenCaptureSettings() async {
    try {
      await _channel.invokeMethod('openScreenCaptureSettings');
    } catch (_) {}
  }

  /// Закрыть окно приложения
  static Future<void> close() async {
    try {
      await _channel.invokeMethod('closeWindow');
    } catch (_) {}
  }

  /// Свернуть окно приложения
  static Future<void> minimize() async {
    try {
      await _channel.invokeMethod('minimizeWindow');
    } catch (_) {}
  }
}

