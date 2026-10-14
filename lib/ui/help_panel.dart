import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import '../l10n.dart';
import '../services/llm_service.dart';
import '../services/window_service.dart';
import '../session.dart';
import 'settings_dialog.dart';
import 'theme.dart';

/// Виджет для плавного перетаскивания окна macOS при клике и движении мыши.
class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  static void _drag() {
    WindowService.drag();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
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

          // Левая часть: кнопка закрытия, сворачивания, меню чата (...), плашка Gemini
          Positioned(
            left: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(width: 8),
                _chatMenuButton(context),
                const SizedBox(width: 8),
                _providerPill(p, hasKey),
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

  Widget _providerPill(LlmProvider p, bool hasKey) {
    return Tooltip(
      message:
          '${p.label} · ${session.config.modelFor(p)} · ${hasKey ? S.t('keySet') : S.t('keyMissing')}',
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 7),
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
        PopupMenuItem(
          value: 'clear',
          height: 34,
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 15, color: Palette.red),
              const SizedBox(width: 8),
              Text(
                S.t('clearChat'),
                style: const TextStyle(fontSize: 12, color: Palette.pri),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'export',
          height: 34,
          child: Row(
            children: [
              const Icon(Icons.file_upload_outlined,
                  size: 15, color: Palette.sec),
              const SizedBox(width: 8),
              Text(
                S.t('exportChat'),
                style: const TextStyle(fontSize: 12, color: Palette.pri),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          height: 34,
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined,
                  size: 15, color: Palette.sec),
              const SizedBox(width: 8),
              Text(
                S.t('importChat'),
                style: const TextStyle(fontSize: 12, color: Palette.pri),
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
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Palette.border),
        ),
        title: Text(
          S.t('clearChatTitle'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Palette.pri,
          ),
        ),
        content: Text(
          S.t('clearChatConfirm'),
          style: const TextStyle(fontSize: 13, color: Palette.sec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(S.t('cancel'), style: const TextStyle(color: Palette.sec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.t('clearAction')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await session.clearChat();
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(S.t('chatCleared')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportChat(BuildContext context) async {
    if (session.turns.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(S.t('chatEmptyExport')),
          duration: const Duration(seconds: 2),
        ),
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
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(S.t('exportSuccess')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('${S.t('exportFailed')}: $e'),
            backgroundColor: Palette.red,
          ),
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
      final parsed = Session.parseImportedChat(text);
      if (parsed.isEmpty) {
        throw Exception(S.t('importEmptyError'));
      }
      await session.importChat(parsed);
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(S.t('importSuccess', '${parsed.length}')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('${S.t('importFailed')}: $e'),
            backgroundColor: Palette.red,
          ),
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
