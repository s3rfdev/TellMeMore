import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Сервис глобальных горячих клавиш macOS.
/// Позволяет вызывать подсказки даже когда фокус ввода находится в другом приложении
/// (например, в IDE или браузере во время написания кода).
class HotkeyService {
  HotkeyService._();

  /// ⌥ 1 — получить обычный ответ по диалогу
  static final HotKey hotKeyGetAnswer = HotKey(
    key: LogicalKeyboardKey.digit1,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  /// ⌥ 2 — получить ответ со скриншотом экрана и кодом
  static final HotKey hotKeyGetAnswerScreenshot = HotKey(
    key: LogicalKeyboardKey.digit2,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  static bool _registered = false;

  /// Регистрация глобальных хоткеев: ⌥1 и ⌥2
  static Future<void> registerGlobalHotkeys({
    required VoidCallback onGetAnswer,
    required VoidCallback onGetAnswerWithScreenshot,
  }) async {
    try {
      await hotKeyManager.unregisterAll();

      await hotKeyManager.register(
        hotKeyGetAnswer,
        keyDownHandler: (_) {
          onGetAnswer();
        },
      );

      await hotKeyManager.register(
        hotKeyGetAnswerScreenshot,
        keyDownHandler: (_) {
          onGetAnswerWithScreenshot();
        },
      );

      _registered = true;
      debugPrint('[HotkeyService] Registered ⌥1 and ⌥2 global hotkeys');
    } catch (e) {
      debugPrint('[HotkeyService] Failed to register global hotkeys: $e');
    }
  }

  /// Снятие регистрации горячих клавиш
  static Future<void> unregisterAll() async {
    if (!_registered) return;
    try {
      await hotKeyManager.unregisterAll();
      _registered = false;
      debugPrint('[HotkeyService] Unregistered all global hotkeys');
    } catch (e) {
      debugPrint('[HotkeyService] Failed to unregister global hotkeys: $e');
    }
  }
}
