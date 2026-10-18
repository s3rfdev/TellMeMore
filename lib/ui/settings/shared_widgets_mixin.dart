// lib/ui/settings/shared_widgets_mixin.dart
//
// Reusable micro-widgets shared across all Settings tabs.
// Mixed into _SettingsDialogState; declares what it needs from the host state
// via abstract members instead of an `on State<...>` constraint, avoiding
// circular imports between the mixin files and settings_dialog.dart.

import 'package:flutter/material.dart';

import '../../services/config_store.dart';
import '../theme.dart';

/// Primitive UI helpers that are tab-agnostic.
///
/// The mixin requires the host `State` to supply:
/// - [c] — the live [AppConfig] instance
/// - [context], [mounted], [setState] — from Flutter's State (already available
///   since the mixin is always mixed into a State subclass)
mixin SharedWidgetsMixin {
  // Flutter State members we rely on — provided automatically because
  // this mixin is only ever used on a State subclass.
  BuildContext get context;
  bool get mounted;
  // ignore: invalid_use_of_protected_member
  void setState(VoidCallback fn);

  /// Live config shortcut — implemented by _SettingsDialogState.
  AppConfig get c;

  // ── Slider theme ──────────────────────────────────────────────────────────

  SliderThemeData sliderTheme(BuildContext ctx) {
    return SliderTheme.of(ctx).copyWith(
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      activeTrackColor: Palette.green,
      inactiveTrackColor: Palette.border,
      thumbColor: Palette.pri,
    );
  }

  // ── Toggle row ────────────────────────────────────────────────────────────

  Widget switchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment:
            subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Palette.pri)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Palette.sec, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeThumbColor: Palette.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Palette.faint,
        ),
      ),
    );
  }

  // ── Eye (show/hide) button ────────────────────────────────────────────────

  Widget eyeButton({
    required bool obscured,
    required VoidCallback onToggle,
    required String showLabel,
    required String hideLabel,
  }) {
    return Tooltip(
      message: obscured ? showLabel : hideLabel,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 16,
            color: obscured ? Palette.sec : Palette.green,
          ),
        ),
      ),
    );
  }

  // ── Text input ────────────────────────────────────────────────────────────

  Widget settingsInput(
    TextEditingController controller, {
    bool obscure = false,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
    bool autofocus = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      style: const TextStyle(fontSize: 13, color: Palette.pri),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Palette.faint),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Palette.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Palette.green),
        ),
      ),
    );
  }
}
