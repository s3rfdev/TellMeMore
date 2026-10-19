import 'package:flutter/material.dart';
import '../theme.dart';

/// Элегантный десктопный тост-HUD для минималистичных системных уведомлений.
/// Компактная плашка с тонкой обводкой, центрированная внизу окна.
class HudToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2200),
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(bottom: 24),
        duration: duration,
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Palette.dialogBg.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isError
                    ? Palette.red.withValues(alpha: 0.6)
                    : Palette.border.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ??
                      (isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded),
                  size: 14,
                  color: isError ? Palette.red : Palette.green,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Palette.pri,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
