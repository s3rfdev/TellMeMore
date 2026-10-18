// lib/ui/settings/ui_tab_mixin.dart
//
// "UI" tab: opacity, titlebar mode, window options, hotkeys, font, spacing,
// text color picker.
// Mixed into _SettingsDialogState.

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../session.dart';
import '../theme.dart';
import 'shared_widgets_mixin.dart';

/// Builds the third settings tab (appearance / UI settings).
mixin UiTabMixin on SharedWidgetsMixin {
  Session get session;

  void onTouch();

  // ── Tab root ───────────────────────────────────────────────────────────────

  Widget buildUiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _opacityRow(),
          const SizedBox(height: 10),
          _miniChoiceRow(
            S.t('titlebarMode'),
            c.titlebarMode,
            [
              ('transparent', Icons.blur_on, S.t('tbTransparent')),
              ('opaque', Icons.dock, S.t('tbOpaque')),
              ('hidden', Icons.visibility_off, S.t('tbHidden')),
            ],
            (v) {
              c.titlebarMode = v;
              session.applyTitlebar();
              onTouch();
            },
          ),
          const SizedBox(height: 10),
          switchRow(
            S.t('hideFromScreenShare'),
            c.hideFromScreenShare,
            (v) {
              c.hideFromScreenShare = v;
              session.applyWindowSettings();
              onTouch();
            },
            subtitle: S.t('hideFromScreenShareSub'),
          ),
          const SizedBox(height: 4),
          switchRow(
            S.t('alwaysOnTop'),
            c.alwaysOnTop,
            (v) {
              c.alwaysOnTop = v;
              session.applyWindowSettings();
              onTouch();
            },
            subtitle: S.t('alwaysOnTopSub'),
          ),
          const SizedBox(height: 12),
          sectionHeader(S.t('sectionHotkeys')),
          _hotkeyRow('⌥ 1', S.t('hotkeyGetAnswer'), S.t('hotkeyGetAnswerDesc')),
          const SizedBox(height: 6),
          _hotkeyRow('⌥ 2', S.t('hotkeyScreenshot'), S.t('hotkeyScreenshotDesc')),
          const SizedBox(height: 12),
          sectionHeader(S.t('sectionText')),
          _fontSizeRow(),
          const SizedBox(height: 8),
          _turnSpacingRow(),
          switchRow(S.t('boldText'), c.boldText, (v) {
            c.boldText = v;
            onTouch();
          }),
          const SizedBox(height: 6),
          _colorSwatchesRow(),
        ],
      ),
    );
  }

  // ── Opacity slider ─────────────────────────────────────────────────────────

  Widget _opacityRow() {
    final pct = (c.windowOpacity * 100).round();
    return Row(
      children: [
        Text(S.t('bgOpacity'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: sliderTheme(context),
            child: Slider(
              value: c.windowOpacity.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              onChanged: (v) {
                setState(() => c.windowOpacity = v);
                session.changed();
              },
              onChangeEnd: (_) => session.saveConfig(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text('$pct%', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, color: Palette.sec)),
        ),
      ],
    );
  }

  // ── Font size slider ───────────────────────────────────────────────────────

  Widget _fontSizeRow() {
    return Row(
      children: [
        Text(S.t('fontSize'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: sliderTheme(context),
            child: Slider(
              value: c.fontSize.clamp(6.0, 24.0),
              min: 6.0,
              max: 24.0,
              onChanged: (v) {
                setState(() => c.fontSize = v);
                session.changed();
              },
              onChangeEnd: (_) => session.saveConfig(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            '${c.fontSize.round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
        ),
      ],
    );
  }

  // ── Turn spacing slider ────────────────────────────────────────────────────

  Widget _turnSpacingRow() {
    return Row(
      children: [
        Text(S.t('turnSpacing'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: sliderTheme(context),
            child: Slider(
              value: c.turnSpacing.clamp(0.0, 20.0),
              min: 0.0,
              max: 20.0,
              onChanged: (v) {
                setState(() => c.turnSpacing = v);
                session.changed();
              },
              onChangeEnd: (_) => session.saveConfig(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            '${c.turnSpacing.round()} px',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
        ),
      ],
    );
  }

  // ── Titlebar mode segmented control ───────────────────────────────────────

  Widget _miniChoiceRow(
    String label,
    String value,
    List<(String, IconData, String)> options,
    ValueChanged<String> onSelected,
  ) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                InkWell(
                  onTap: () => onSelected(options[i].$1),
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: value == options[i].$1
                          ? Palette.green.withValues(alpha: 0.14)
                          : Colors.transparent,
                      border: value == options[i].$1
                          ? Border.all(color: Palette.green.withValues(alpha: 0.55))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          options[i].$2,
                          size: 11,
                          color: value == options[i].$1 ? Palette.green : Palette.sec,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          options[i].$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: value == options[i].$1 ? Palette.green : Palette.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < options.length - 1) const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Hotkey display row ─────────────────────────────────────────────────────

  Widget _hotkeyRow(String keyCombo, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Palette.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Palette.border),
            ),
            child: Text(
              keyCombo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Palette.green,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.pri),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Palette.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Color swatches ─────────────────────────────────────────────────────────

  Widget _colorSwatchesRow() {
    const swatches = <int>[
      0xFFFFFFFF, 0xFFE8EAED, 0xFFCCCCCC, 0xFFA0A5AD,
      0xFF2FBF71, 0xFF56C8D8, 0xFF5B9DFF, 0xFFF5A524,
      0xFFE5484D, 0xFFB58CFF,
    ];

    final currentColor = Color(c.hintColor);
    final currentHsv = HSVColor.fromColor(currentColor);
    final brightness = currentHsv.value.clamp(0.2, 1.0);
    final isCustomSelected = !swatches.contains(c.hintColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(S.t('textColor'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final argb in swatches)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _swatchCircle(
                          Color(argb),
                          isSelected: c.hintColor == argb,
                          onTap: () {
                            c.hintColor = argb;
                            onTouch();
                            session.saveConfig();
                          },
                        ),
                      ),
                    if (isCustomSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _swatchCircle(
                          currentColor,
                          isSelected: true,
                          onTap: () => _openCustomColorPicker(context),
                        ),
                      ),
                    Tooltip(
                      message: S.t('customColor'),
                      child: InkWell(
                        onTap: () => _openCustomColorPicker(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCustomSelected ? Palette.green : Palette.border,
                              width: 1.2,
                            ),
                            gradient: const SweepGradient(
                              colors: [
                                Colors.red, Colors.yellow, Colors.green,
                                Colors.cyan, Colors.blue, Colors.purple, Colors.red,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.colorize_rounded, size: 11, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(S.t('brightness'), style: const TextStyle(fontSize: 11, color: Palette.sec)),
            const Spacer(),
            Text(
              '${(brightness * 100).round()}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Palette.pri),
            ),
          ],
        ),
        SliderTheme(
          data: sliderTheme(context),
          child: Slider(
            value: brightness,
            min: 0.2,
            max: 1.0,
            divisions: 16,
            onChanged: (v) {
              final newColor = currentHsv.withValue(v).toColor();
              c.hintColor = newColor.toARGB32();
              onTouch();
              session.saveConfig();
            },
          ),
        ),
      ],
    );
  }

  Widget _swatchCircle(Color color, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: isSelected ? Palette.green : Palette.border,
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Palette.green.withValues(alpha: 0.4), blurRadius: 4)]
              : null,
        ),
      ),
    );
  }

  // ── Custom color picker dialog ─────────────────────────────────────────────

  Future<void> _openCustomColorPicker(BuildContext context) async {
    final initial = Color(c.hintColor);
    var hsv = HSVColor.fromColor(initial);

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            final activeColor = hsv.toColor();
            final hex = activeColor
                .toARGB32()
                .toRadixString(16)
                .padLeft(8, '0')
                .substring(2)
                .toUpperCase();

            return Dialog(
              backgroundColor: Palette.dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Palette.border),
              ),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          S.t('customColor'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Palette.pri,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 20,
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Palette.border),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#$hex',
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Palette.sec,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(S.t('hue'), style: const TextStyle(fontSize: 10, color: Palette.sec)),
                    SliderTheme(
                      data: sliderTheme(context),
                      child: Slider(
                        value: hsv.hue,
                        min: 0,
                        max: 360,
                        onChanged: (v) => setPickerState(() => hsv = hsv.withHue(v)),
                      ),
                    ),
                    Text(S.t('saturation'), style: const TextStyle(fontSize: 10, color: Palette.sec)),
                    SliderTheme(
                      data: sliderTheme(context),
                      child: Slider(
                        value: hsv.saturation,
                        min: 0,
                        max: 1.0,
                        onChanged: (v) => setPickerState(() => hsv = hsv.withSaturation(v)),
                      ),
                    ),
                    Text(S.t('brightness'), style: const TextStyle(fontSize: 10, color: Palette.sec)),
                    SliderTheme(
                      data: sliderTheme(context),
                      child: Slider(
                        value: hsv.value.clamp(0.15, 1.0),
                        min: 0.15,
                        max: 1.0,
                        onChanged: (v) => setPickerState(() => hsv = hsv.withValue(v)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          style: TextButton.styleFrom(
                            foregroundColor: Palette.sec,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(S.t('cancel'), style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(hsv.toColor()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.green,
                            foregroundColor: const Color(0xFF06130C),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                          child: Text(
                            S.t('save'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      c.hintColor = result.toARGB32();
      onTouch();
      session.saveConfig();
    }
  }
}
