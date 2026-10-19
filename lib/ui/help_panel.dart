import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import '../l10n.dart';
import '../services/llm_service.dart';
import '../services/window_service.dart';
import '../session.dart';
import 'formatted_answer.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets/context_inspector_dialog.dart';
import 'widgets/crop_selector_dialog.dart';
import 'widgets/hud_toast.dart';

/// Виджет для плавного перетаскивания окна macOS при клике и движении мыши.
class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  static void _drag() {
    WindowService.drag();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _drag(),
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
          if (session.pendingScreenshots.isNotEmpty)
            _pendingScreenshotsStrip(context),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isNarrow = w < 540;
        final isUltraNarrow = w < 400;

        return SizedBox(
          height: 32,
          child: Stack(
            children: [
              // Вся фоновая область шапки — нативное перетаскивание окна
              const Positioned.fill(child: _WindowDragArea()),

              Row(
                children: [
                  // Левая часть: кнопка закрытия, сворачивания (только в прозрачном/скрытом режиме), меню чата (...), плашка модели
                  if (session.config.titlebarMode != 'opaque') ...[
                    _winButton(
                      icon: Icons.close,
                      tooltip: S.t('winClose'),
                      onTap: () {
                        if (Platform.isMacOS) {
                          WindowManipulator.closeWindow();
                        } else {
                          WindowService.close();
                        }
                      },
                    ),
                    const SizedBox(width: 5),
                    _winButton(
                      icon: Icons.remove,
                      tooltip: S.t('winMinimize'),
                      onTap: () {
                        if (Platform.isMacOS) {
                          WindowManipulator.miniaturizeWindow();
                        } else {
                          WindowService.minimize();
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  _chatMenuButton(context),
                  if (!isUltraNarrow) ...[
                    const SizedBox(width: 6),
                    _providerPill(p, hasKey, compact: isNarrow),
                  ],

                  const Spacer(),

                  // Центр: Get answer / Stop + Camera (скриншот экрана + код)
                  GradientButton(
                    icon: session.helpLoading ? Icons.stop_rounded : Icons.bolt,
                    label: isNarrow
                        ? ''
                        : (session.helpLoading ? S.t('stop') : 'Get answer'),
                    height: 28,
                    fontSize: 12,
                    onTap: session.helpLoading
                        ? session.stopHelp
                        : session.getHelp,
                    tooltip: session.helpLoading
                        ? S.t('stopGeneration')
                        : S.t('hintPlaceholder'),
                  ),
                  const SizedBox(width: 5),
                  _promptModeButton(context, compact: isNarrow),
                  const SizedBox(width: 4),
                  _cameraButton(context),
                  const SizedBox(width: 4),
                  _addScreenshotButton(context),
                  if (session.llmHistory.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _followUpButton(context),
                  ],

                  const Spacer(),

                  // Правая часть: мини-кнопка видеозахвата, язык, инспектор, настройки
                  if (!isUltraNarrow) ...[
                    _videoCaptureButton(context),
                    const SizedBox(width: 4),
                    _langToggle(),
                    const SizedBox(width: 4),
                  ],
                  _inspectorButton(context),
                  const SizedBox(width: 4),
                  _settingsButton(context),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _providerPill(LlmProvider p, bool hasKey, {bool compact = false}) {
    return Tooltip(
      message:
          '${p.label} · ${session.config.modelFor(p)} · ${hasKey ? S.t('keySet') : S.t('keyMissing')}',
      child: Container(
        height: 20,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7),
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
            if (!compact) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _promptModeButton(BuildContext context, {bool compact = false}) {
    final isBullets = session.config.promptMode == 'bullets';
    final tooltip = isBullets
        ? S.t('promptModeTooltipBullets')
        : S.t('promptModeTooltipFull');

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            session.togglePromptMode();
            final nowBullets = session.config.promptMode == 'bullets';
            HudToast.show(
              context,
              nowBullets
                  ? S.t('promptModeToastBullets')
                  : S.t('promptModeToastFull'),
              icon: nowBullets
                  ? Icons.flash_on_rounded
                  : Icons.chat_bubble_outline_rounded,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 28,
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
            decoration: BoxDecoration(
              color: isBullets
                  ? Palette.amber.withValues(alpha: 0.15)
                  : Palette.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBullets
                    ? Palette.amber.withValues(alpha: 0.6)
                    : Palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBullets
                      ? Icons.flash_on_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: isBullets ? Palette.amber : Palette.sec,
                ),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    isBullets ? S.t('promptModeBullets') : S.t('promptModeFull'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isBullets ? FontWeight.w700 : FontWeight.w500,
                      color: isBullets ? Palette.amber : Palette.sec,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraButton(BuildContext context) {
    final enabled = !session.helpLoading;
    final count = session.pendingScreenshots.length;
    final tooltip = count > 0
        ? '${S.t('sendQueuedScreenshots')} ($count)'
        : S.t('screenshotAnswer');
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? session.getHelpWithScreenshot : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 30,
                height: 28,
                decoration: BoxDecoration(
                  color: count > 0
                      ? Palette.blue.withValues(alpha: 0.2)
                      : (enabled
                          ? Palette.border.withValues(alpha: 0.5)
                          : Palette.border.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: count > 0
                        ? Palette.blue.withValues(alpha: 0.7)
                        : (enabled
                            ? Palette.border
                            : Palette.border.withValues(alpha: 0.5)),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: count > 0
                      ? Palette.blue
                      : (enabled
                          ? Palette.pri
                          : Palette.sec.withValues(alpha: 0.4)),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Palette.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addScreenshotButton(BuildContext context) {
    final enabled = !session.helpLoading && !session.isCapturingScreenshot;
    return Tooltip(
      message: S.t('addScreenshot'),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? session.addPendingScreenshot : null,
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
            child: session.isCapturingScreenshot
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: Palette.pri,
                    ),
                  )
                : Icon(
                    Icons.add,
                    size: 17,
                    color: enabled
                        ? Palette.pri
                        : Palette.sec.withValues(alpha: 0.4),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _followUpButton(BuildContext context) {
    final round = session.llmHistory.length ~/ 2 + 1;
    final enabled = !session.helpLoading;
    return Tooltip(
      message: S.t('followUpHelp', '$round'),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? session.getFollowUpHelp : null,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: Palette.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.blue.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Palette.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  'R$round',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Palette.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingScreenshotsStrip(BuildContext context) {
    final count = session.pendingScreenshots.length;
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final imgBytes = session.pendingScreenshots[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Palette.border),
                        color: Colors.black26,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        imgBytes,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                    Positioned(
                      left: 3,
                      bottom: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Tooltip(
                        message: S.t('removeScreenshot'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => session.removePendingScreenshot(index),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2D30),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Palette.border,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.close,
                                size: 10,
                                color: Palette.pri,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: S.t('clearScreenshots'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: session.clearPendingScreenshots,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 13, color: Palette.sec),
                      SizedBox(width: 3),
                      Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 10,
                          color: Palette.sec,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: S.t('chatHistoryMenu'),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Palette.border),
      ),
      color: Palette.dialogBg,
      elevation: 6,
      offset: const Offset(0, 24),
      onSelected: (value) {
        switch (value) {
          case 'reset_history':
            session.resetLlmHistory();
            HudToast.show(context, S.t('resetLlmContextSuccess'));
            break;
          case 'clear':
            _confirmClearChat(context);
            break;
          case 'export':
            _exportChat(context);
            break;
          case 'import':
            _importChat(context);
            break;
        }
      },
      itemBuilder: (context) => [
        if (session.llmHistory.isNotEmpty) ...[
          PopupMenuItem(
            value: 'reset_history',
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.restart_alt, size: 14, color: Palette.sec),
                const SizedBox(width: 8),
                Text(
                  S.t('resetLlmContext'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                    color: Palette.pri,
                  ),
                ),
              ],
            ),
          ),
          const _ChatMenuDivider(),
        ],
        PopupMenuItem(
          value: 'clear',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 14,
                color: Palette.red.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                S.t('clearChat'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                  color: Palette.pri,
                ),
              ),
            ],
          ),
        ),
        const _ChatMenuDivider(),
        PopupMenuItem(
          value: 'export',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const Icon(Icons.file_upload_outlined,
                  size: 14, color: Palette.sec),
              const SizedBox(width: 8),
              Text(
                S.t('exportChat'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                  color: Palette.pri,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined,
                  size: 14, color: Palette.sec),
              const SizedBox(width: 8),
              Text(
                S.t('importChat'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                  color: Palette.pri,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Palette.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 12, color: Palette.sec),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearChat(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Palette.border),
        ),
        contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        title: Text(
          S.t('clearChatTitle'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Palette.pri,
          ),
        ),
        content: Text(
          S.t('clearChatConfirm'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Palette.sec,
            height: 1.35,
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Palette.border),
                ),
                child: Text(
                  S.t('cancel'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Palette.sec,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Palette.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  S.t('clearAction'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await session.clearChat();
      if (context.mounted) {
        HudToast.show(context, S.t('chatCleared'));
      }
    }
  }

  Future<void> _exportChat(BuildContext context) async {
    if (session.turns.isEmpty) {
      HudToast.show(
        context,
        S.t('chatEmptyExport'),
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final now = DateTime.now();
    final dateSlug =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final suggested = 'tellmemore_chat_$dateSlug.json';
    final location = await getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return;
    try {
      final json = session.exportChatJson();
      final file = File(location.path);
      await file.writeAsString(json);
      if (context.mounted) {
        HudToast.show(context, S.t('exportSuccess'));
      }
    } catch (e) {
      if (context.mounted) {
        HudToast.show(
          context,
          '${S.t('exportFailed')}: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _importChat(BuildContext context) async {
    const groups = [
      XTypeGroup(label: 'Chat file', extensions: ['json', 'txt']),
    ];
    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) return;
    try {
      final text = await file.readAsString();
      final parsed = Session.parseImportedChatFull(text);
      if (parsed.turns.isEmpty) {
        throw Exception(S.t('importEmptyError'));
      }
      await session.importChat(
        parsed.turns,
        conversationSummary: parsed.conversationSummary,
        summarizedUpToTurn: parsed.summarizedUpToTurn,
      );
      if (context.mounted) {
        HudToast.show(
          context,
          S.t('importSuccess', '${parsed.turns.length}'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        HudToast.show(
          context,
          '${S.t('importFailed')}: $e',
          isError: true,
        );
      }
    }
  }

  Widget _winButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.border.withValues(alpha: 0.15),
              border: Border.all(color: Palette.border),
            ),
            child: Icon(icon, size: 10, color: Palette.sec),
          ),
        ),
      ),
    );
  }

  Widget _langToggle() {
    final next = session.config.uiLang == 'ru' ? 'en' : 'ru';
    return Tooltip(
      message: next == 'en' ? 'English' : 'Русский',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => session.setUiLang(next),
          child: Container(
            width: 30,
            height: 28,
            decoration: BoxDecoration(
              color: Palette.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.border),
            ),
            alignment: Alignment.center,
            child: Text(
              session.config.uiLang.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Palette.sec,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoCaptureButton(BuildContext context) {
    final active = session.visionMode == VisionMode.screenCrop;
    return Tooltip(
      message: active
          ? 'Захват кропа активен. Клик: управление рамкой'
          : 'Захват области экрана (кроп лица оппонента)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!active) {
              CropSelectorDialog.show(context, session);
            } else {
              _showCaptureMenu(context);
            }
          },
          child: Container(
            width: 30,
            height: 28,
            decoration: BoxDecoration(
              color: active
                  ? Palette.green.withValues(alpha: 0.15)
                  : Palette.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? Palette.green.withValues(alpha: 0.8)
                    : Palette.border,
              ),
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.crop_free_rounded,
                  size: 15,
                  color: active ? Palette.green : Palette.sec,
                ),
                if (active)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Palette.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCaptureMenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 40,
        offset.dx + 40,
        offset.dy + 80,
      ),
      color: Palette.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Palette.border),
      ),
      elevation: 6,
      items: const [
        PopupMenuItem(
          value: 'reframe',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.aspect_ratio_rounded, size: 14, color: Palette.green),
              SizedBox(width: 8),
              Text(
                'Изменить рамку...',
                style: TextStyle(fontSize: 12, color: Palette.pri),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'stop',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.stop_circle_outlined, size: 14, color: Palette.red),
              SizedBox(width: 8),
              Text(
                'Остановить захват',
                style: TextStyle(fontSize: 12, color: Palette.red),
              ),
            ],
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    if (choice == 'reframe') {
      CropSelectorDialog.show(context, session);
    } else if (choice == 'stop') {
      session.setVisionMode(VisionMode.off);
    }
  }

  Widget _inspectorButton(BuildContext context) {
    return Tooltip(
      message: 'Инспектор импульсов: Что видит нейросеть прямо сейчас',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ContextInspectorDialog.show(context, session),
          child: Container(
            width: 30,
            height: 28,
            decoration: BoxDecoration(
              color: Palette.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.border),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.psychology_outlined, size: 16, color: Palette.sec),
          ),
        ),
      ),
    );
  }

  Widget _settingsButton(BuildContext context) {
    return Tooltip(
      message: S.t('settings'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showSettingsDialog(context, session),
          child: Container(
            width: 30,
            height: 28,
            decoration: BoxDecoration(
              color: Palette.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.border),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.tune, size: 16, color: Palette.sec),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (session.helpError != null) {
      return SingleChildScrollView(
        child: Text(
          session.helpError!,
          style: const TextStyle(color: Palette.red, fontSize: 13, height: 1.4),
        ),
      );
    }
    if (session.helpAnswer != null && session.helpAnswer!.isNotEmpty) {
      final c = session.config;
      final (dossier, speech) = _splitDossierAndSpeech(session.helpAnswer!);
      final isVisionActive = session.visionMode != VisionMode.off;
      final showDossier = c.showPsychologicalDossier && isVisionActive && dossier != null && dossier.isNotEmpty;

      return Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDossier) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Palette.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Palette.amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.psychology_outlined,
                          size: 13,
                          color: Palette.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(
                          dossier,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Palette.amber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: FormattedAnswerView(
                  text: speech.isNotEmpty
                      ? speech
                      : (showDossier ? '…' : session.helpAnswer!),
                  baseColor: Color(c.hintColor),
                  fontSize: c.fontSize,
                  isBold: c.boldText,
                ),
              ),
            ],
          ),
          if (session.helpLoading)
            const Positioned(
              right: 6,
              bottom: 2,
              child: _StreamingBadge(),
            ),
        ],
      );
    }
    if (session.helpLoading) {
      return Row(
        children: [
          const Icon(Icons.bolt, size: 17, color: Palette.green),
          const SizedBox(width: 8),
          Text(S.t('thinking'), style: const TextStyle(color: Palette.sec)),
        ],
      );
    }
    return Text(
      S.t('hintPlaceholder'),
      style: const TextStyle(color: Palette.sec, fontSize: 13, height: 1.4),
    );
  }

  static (String?, String) _splitDossierAndSpeech(String text) {
    final dossierMatch = RegExp(
      r'<dossier>([\s\S]*?)(?:<\/dossier>|$)',
      caseSensitive: false,
    ).firstMatch(text);
    final speechMatch = RegExp(
      r'<speech>([\s\S]*?)(?:<\/speech>|$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (dossierMatch != null) {
      final dossier = dossierMatch.group(1)?.trim();
      final speech = speechMatch != null
          ? speechMatch.group(1)?.trim() ?? ''
          : text
              .replaceAll(
                RegExp(r'<dossier>[\s\S]*?(?:<\/dossier>|$)', caseSensitive: false),
                '',
              )
              .trim();
      return (dossier, speech);
    }
    return (null, text);
  }
}

/// Анимированный бейдж текущей потоковой генерации ответа модели
class _StreamingBadge extends StatefulWidget {
  const _StreamingBadge();

  @override
  State<_StreamingBadge> createState() => _StreamingBadgeState();
}

class _StreamingBadgeState extends State<_StreamingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.dialogBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Palette.green.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Palette.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              S.t('generating'),
              style: const TextStyle(
                fontSize: 10,
                color: Palette.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Тонкий разделитель для контекстного меню чата с деликатной границей Palette.border.
class _ChatMenuDivider extends PopupMenuEntry<Never> {
  const _ChatMenuDivider();

  @override
  double get height => 1;

  @override
  bool represents(void value) => false;

  @override
  State<_ChatMenuDivider> createState() => _ChatMenuDividerState();
}

class _ChatMenuDividerState extends State<_ChatMenuDivider> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Palette.border.withValues(alpha: 0.6),
    );
  }
}
