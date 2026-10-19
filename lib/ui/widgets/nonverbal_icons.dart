import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';

/// Векторные SVG-иконки и компактная панель микро-индикаторов невербалики оппонента.
class NonverbalIconsBar extends StatelessWidget {
  const NonverbalIconsBar({
    super.key,
    required this.tags,
  });

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final badges = <Widget>[];

    // 1. Глазная динамика (моргание / блокирование)
    final eyeTag = tags.firstWhere(
      (t) =>
          t.contains('Глазное блокирование') ||
          t.contains('моргание') ||
          t.contains('Стресс (моргание') ||
          t.contains('bpm'),
      orElse: () => '',
    );
    if (eyeTag.isNotEmpty) {
      final isBlocking = eyeTag.contains('Глазное блокирование');
      final isHighStress = eyeTag.contains('Стресс') || eyeTag.contains('Учащённое');
      final color = isBlocking
          ? Palette.red
          : (isHighStress ? Palette.amber : Palette.green);
      badges.add(
        _MicroBadge(
          svgString: isBlocking ? _svgEyeClosed : _svgEyeOpen,
          color: color,
          tooltip: eyeTag,
        ),
      );
    }

    // 2. Вектор взгляда (Gaze target)
    final gazeTag = tags.firstWhere(
      (t) => t.startsWith('Взгляд:') || t.contains('взгляд'),
      orElse: () => '',
    );
    if (gazeTag.isNotEmpty) {
      final isAverted = !gazeTag.contains('Прямой') && !gazeTag.contains('контакт');
      badges.add(
        _MicroBadge(
          svgString: _svgGaze,
          color: isAverted ? Palette.amber : Palette.sec,
          tooltip: gazeTag,
        ),
      );
    }

    // 3. Губы и челюсть (AU24 Lip Compression)
    final mouthTag = tags.firstWhere(
      (t) =>
          t.contains('губ') ||
          t.contains('челюст') ||
          t.contains('AU24') ||
          t.contains('Сжатие губ') ||
          t.contains('Поджатие'),
      orElse: () => '',
    );
    if (mouthTag.isNotEmpty) {
      badges.add(
        _MicroBadge(
          svgString: _svgLips,
          color: Palette.amber,
          tooltip: mouthTag,
        ),
      );
    }

    // 4. Брови (AU4 Brow Furrow / AU1+2 Raise)
    final browTag = tags.firstWhere(
      (t) =>
          t.contains('бров') ||
          t.contains('AU4') ||
          t.contains('AU1') ||
          t.contains('Сведение'),
      orElse: () => '',
    );
    if (browTag.isNotEmpty) {
      badges.add(
        _MicroBadge(
          svgString: _svgBrows,
          color: Palette.amber,
          tooltip: browTag,
        ),
      );
    }

    // 5. Односторонняя ухмылка / асимметрия (AU14)
    final smirkTag = tags.firstWhere(
      (t) =>
          t.contains('ухмылк') ||
          t.contains('AU14') ||
          t.contains('Асимметри'),
      orElse: () => '',
    );
    if (smirkTag.isNotEmpty) {
      badges.add(
        _MicroBadge(
          svgString: _svgSmirk,
          color: Palette.amber,
          tooltip: smirkTag,
        ),
      );
    }

    // 6. Микродвижения головы (кивок «да» / покачивание «нет» / рассинхрон)
    final headTag = tags.firstWhere(
      (t) =>
          t.contains('головой') ||
          t.contains('Покачивание') ||
          t.contains('Кивок') ||
          t.contains('неконгруэнт') ||
          t.contains('ложное'),
      orElse: () => '',
    );
    if (headTag.isNotEmpty) {
      final isNegativeOrFalse = headTag.contains('«нет»') ||
          headTag.contains('неконгруэнт') ||
          headTag.contains('ложное');
      badges.add(
        _MicroBadge(
          svgString: _svgHeadMotion,
          color: isNegativeOrFalse ? Palette.red : Palette.green,
          tooltip: headTag,
        ),
      );
    }

    // 7. Психологический кластер или тревога (Red Flag)
    final clusterTags = tags.where(
      (t) =>
          t != eyeTag &&
          t != gazeTag &&
          t != mouthTag &&
          t != browTag &&
          t != smirkTag &&
          t != headTag,
    ).toList();
    if (clusterTags.isNotEmpty) {
      badges.add(
        _MicroBadge(
          svgString: _svgAlert,
          color: Palette.amber,
          tooltip: clusterTags.join(' · '),
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: 2.5),
          badges[i],
        ],
      ],
    );
  }

  // ── Векторные SVG-строки ──────────────────────────────────────────────────

  static const _svgSmirk = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M2.5 10.5C4.5 10.2 7 9.8 9.5 8.5C11.5 7.2 13 5.5 14 4.5" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round"/>
  <circle cx="14" cy="4.5" r="1.1" fill="#FFFFFF"/>
</svg>
''';

  static const _svgHeadMotion = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="8" cy="7.2" r="4.2" stroke="#FFFFFF" stroke-width="1.2"/>
  <path d="M3.2 14.5C4.5 12.8 6.2 12 8 12C9.8 12 11.5 12.8 12.8 14.5" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
  <path d="M2.2 7.2H0.8M0.8 7.2L1.8 6.2M0.8 7.2L1.8 8.2" stroke="#FFFFFF" stroke-width="1.1" stroke-linecap="round"/>
  <path d="M13.8 7.2H15.2M15.2 7.2L14.2 6.2M15.2 7.2L14.2 8.2" stroke="#FFFFFF" stroke-width="1.1" stroke-linecap="round"/>
</svg>
''';

  static const _svgEyeOpen = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M1 8C2.5 4.5 5.5 2.5 8 2.5C10.5 2.5 13.5 4.5 15 8C13.5 11.5 10.5 13.5 8 13.5C5.5 13.5 2.5 11.5 1 8Z" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="8" cy="8" r="2.3" fill="#FFFFFF"/>
</svg>
''';

  static const _svgEyeClosed = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M2.5 10C4 12 6 12.8 8 12.8C10 12.8 12 12 13.5 10M8 12.8V14.5M4.5 11.5L3.5 13.5M11.5 11.5L12.5 13.5" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round"/>
  <line x1="2" y1="2.5" x2="14" y2="13.5" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round"/>
</svg>
''';

  static const _svgGaze = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="8" cy="8" r="5.5" stroke="#FFFFFF" stroke-width="1.2"/>
  <circle cx="8" cy="8" r="2" fill="#FFFFFF"/>
  <line x1="8" y1="1" x2="8" y2="3.2" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="8" y1="12.8" x2="8" y2="15" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="1" y1="8" x2="3.2" y2="8" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="12.8" y1="8" x2="15" y2="8" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
</svg>
''';

  static const _svgLips = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M2 8C4 6.6 6 6.2 8 7C10 6.2 12 6.6 14 8C12 9.4 10 9.8 8 9C6 9.8 4 9.4 2 8Z" stroke="#FFFFFF" stroke-width="1.2" stroke-linejoin="round"/>
  <line x1="2.5" y1="8" x2="13.5" y2="8" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
</svg>
''';

  static const _svgBrows = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M2.5 8C4.5 6.4 6.5 6.8 7.5 8.2" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round"/>
  <path d="M13.5 8C11.5 6.4 9.5 6.8 8.5 8.2" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round"/>
</svg>
''';

  static const _svgAlert = '''
<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M8 2.2L14.5 13.5H1.5L8 2.2Z" stroke="#FFFFFF" stroke-width="1.2" stroke-linejoin="round"/>
  <line x1="8" y1="6.2" x2="8" y2="9.5" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round"/>
  <circle cx="8" cy="11.5" r="0.75" fill="#FFFFFF"/>
</svg>
''';
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({
    required this.svgString,
    required this.color,
    required this.tooltip,
  });

  final String svgString;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 150),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 0.6,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(2.2),
          child: SvgPicture.string(
            svgString,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
