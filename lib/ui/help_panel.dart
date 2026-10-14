import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import '../l10n.dart';
import '../services/llm_service.dart';
import '../services/window_service.dart';
import '../session.dart';
import 'settings_dialog.dart';
import 'theme.dart';

/// Виджет для плавного перетаскивания окна macOS при клике и движении мыши.
class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea({this.child});

  final Widget? child;

  static void _drag() {
    WindowService.drag();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _drag(),
      child: child,
    );
  }
}

/// Верхняя панель: шапка с центрированной кнопкой Get answer + текст подсказки.
class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    // Без собственной заливки: фон всего окна уже красит Scaffold,
    // дополнительный слой делал верхнюю панель темнее нижней.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 2, right: 4, top: 6),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final p = session.config.provider;
    final hasKey = session.config.keyFor(p).trim().isNotEmpty;
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Вся фоновая область шапки — нативное перетаскивание окна
          const Positioned.fill(child: _WindowDragArea()),

          // Левая часть: кнопки окна (если скрыта нативная шапка), логотип, заголовок, статус
          Positioned(
            left: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (session.config.titlebarMode == 'hidden') ...[
                  _winButton(
                    icon: Icons.close,
                    tooltip: S.t('winClose'),
                    onTap: () => WindowManipulator.closeWindow(),
                  ),
                  const SizedBox(width: 6),
                  _winButton(
                    icon: Icons.remove,
                    tooltip: S.t('winMinimize'),
                    onTap: () => WindowManipulator.miniaturizeWindow(),
                  ),
                  const SizedBox(width: 10),
                ],
                _WindowDragArea(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SvgPicture.asset(
                          'assets/logo.svg',
                          width: 16,
                          height: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        S.t('helpTitle'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Palette.sec,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message:
                            '${p.label} · ${session.config.modelFor(p)} · ${hasKey ? S.t('keySet') : S.t('keyMissing')}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: hasKey ? Palette.green : Palette.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p.shortLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Palette.sec,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Центр: Get answer + Camera (скриншот экрана + код)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientButton(
                  icon: Icons.bolt,
                  label: 'Get answer',
                  height: 28,
                  fontSize: 12,
                  onTap: session.helpLoading ? null : session.getHelp,
                  tooltip: S.t('hintPlaceholder'),
                ),
                const SizedBox(width: 6),
                _cameraButton(context),
              ],
            ),
          ),

          // Правая часть: переключение языка и настройки
          Positioned(
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _langToggle(),
                IconButton(
                  tooltip: S.t('settings'),
                  icon: const Icon(Icons.tune, size: 18, color: Palette.sec),
                  onPressed: () => showSettingsDialog(context, session),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraButton(BuildContext context) {
    final enabled = !session.helpLoading;
    return Tooltip(
      message: S.t('screenshotAnswer'),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? session.getHelpWithScreenshot : null,
          child: Container(
            width: 30,
            height: 28,
            decoration: BoxDecoration(
              color: enabled
                  ? Palette.border.withValues(alpha: 0.5)
                  : Palette.border.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled
                    ? Palette.border
                    : Palette.border.withValues(alpha: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.camera_alt_outlined,
              size: 16,
              color: enabled ? Palette.pri : Palette.sec.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _winButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Palette.border),
          ),
          child: Icon(icon, size: 10, color: Palette.sec),
        ),
      ),
    );
  }

  Widget _langToggle() {
    final next = session.config.uiLang == 'ru' ? 'en' : 'ru';
    return Tooltip(
      message: next == 'en' ? 'English' : 'Русский',
      child: TextButton(
        onPressed: () => session.setUiLang(next),
        style: TextButton.styleFrom(
          foregroundColor: Palette.sec,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(30, 26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Palette.border),
          ),
        ),
        child: Text(
          session.config.uiLang.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _body() {
    if (session.helpLoading) {
      return Row(
        children: [
          const Icon(Icons.bolt, size: 17, color: Palette.green),
          const SizedBox(width: 8),
          Text(S.t('thinking'), style: const TextStyle(color: Palette.sec)),
        ],
      );
    }
    if (session.helpError != null) {
      return SingleChildScrollView(
        child: Text(
          session.helpError!,
          style: const TextStyle(color: Palette.red, fontSize: 13, height: 1.4),
        ),
      );
    }
    if (session.helpAnswer != null) {
      final c = session.config;
      return SingleChildScrollView(
        child: SelectableText(
          session.helpAnswer!,
          style: TextStyle(
            color: Color(c.hintColor),
            fontSize: c.fontSize,
            height: 1.45,
            fontWeight: c.boldText ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }
    return Text(
      S.t('hintPlaceholder'),
      style: const TextStyle(color: Palette.sec, fontSize: 13, height: 1.4),
    );
  }
}
