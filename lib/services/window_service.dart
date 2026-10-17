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

  /// Сделать скриншот экрана без окна TellMeMore.
  /// Возвращает JPEG байты (Uint8List).
  static Future<Uint8List?> captureScreen() async {
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

