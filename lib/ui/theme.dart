import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFF0E1013);
  static const panel = Color(0xFF15181C);
  static const border = Color(0xFF262A31);
  static const sec = Color(0xFF8B9199);
  static const faint = Color(0xFF5A6069);
  static const pri = Color(0xFFE8EAED);
  static const green = Color(0xFF2FBF71);
  static const red = Color(0xFFE5484D);
  static const them = Color(0xFF5B9DFF);
  static const amber = Color(0xFFF5A524);
  static const inputBorder = Color(0xFF33383F);
  static const dialogBg = Color(0xFF1A1E23);

  static const greenGradient = LinearGradient(
    colors: [Color(0xFF37CD80), Color(0xFF1D9A58)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Минималистичная кнопка с градиентом: иконка + подпись, тултип опционально.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.tooltip,
    this.height = 40,
    this.fontSize = 14,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    Widget btn = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: enabled ? Palette.greenGradient : null,
            color: enabled ? null : Palette.border.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white.withValues(alpha: enabled ? 1 : 0.6)),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: enabled ? 1 : 0.6))),
            ],
          ),
        ),
      ),
    );
    if (expand) btn = SizedBox(width: double.infinity, child: btn);
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}
