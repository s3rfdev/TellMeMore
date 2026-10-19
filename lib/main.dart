import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import 'l10n.dart';
import 'services/hotkey_service.dart';
import 'session.dart';
import 'ui/help_panel.dart';
import 'ui/theme.dart';
import 'ui/transcript_panel.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.loadConfig();
  await session.loadAudioDevices();

  // Настоящая per-pixel прозрачность окна macOS: фон и титлбар полностью
  // прозрачны (0%), сквозь окно виден рабочий стол.
  if (Platform.isMacOS) {
    try {
      WindowManipulator.initialize();
      WindowManipulator.makeWindowFullyTransparent();
      WindowManipulator.disableShadow();
    } catch (_) {
      /* работаем в стандартном режиме */
    }
    session.applyTitlebar();
  }
  await session.applyWindowSettings();
  await HotkeyService.registerGlobalHotkeys(
    onGetAnswer: () {
      if (!session.helpLoading) {
        session.getHelp();
      }
    },
    onGetAnswerWithScreenshot: () {
      if (!session.helpLoading) {
        session.getHelpWithScreenshot();
      }
    },
    onAddScreenshot: () {
      session.addPendingScreenshot();
    },
  );
  runApp(MimicApp(session: session));
}

class MimicApp extends StatelessWidget {
  const MimicApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIMIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Palette.green,
          onPrimary: Color(0xFF06130C),
          surface: Palette.bg,
          onSurface: Palette.pri,
          error: Palette.red,
        ),
        scaffoldBackgroundColor: Palette.bg,
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: const Color(0xFF22262C),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.border),
          ),
          textStyle: const TextStyle(fontSize: 11, color: Palette.pri),
          waitDuration: const Duration(milliseconds: 400),
        ),
      ),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final opacity = session.config.windowOpacity;
          return Scaffold(
            backgroundColor: Palette.bg.withValues(alpha: opacity),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalH = constraints.maxHeight;
                  final topH = totalH * session.config.splitRatio;
                  return Column(
                    children: [
                      // Верхняя тактическая панель подсказок LLM
                      SizedBox(
                        height: topH,
                        child: HelpPanel(session: session),
                      ),

                      // Тонкий прозрачный разделитель высоты (бегунок)
                      _ResizeDivider(
                        session: session,
                        topHeight: topH,
                        totalHeight: totalH,
                      ),

                      // Нижняя панель стека транскрипта диалога
                      Expanded(child: TranscriptPanel(session: session)),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Минималистичный прозрачный бегунок изменения пропорций панелей
class _ResizeDivider extends StatefulWidget {
  const _ResizeDivider({
    required this.session,
    required this.topHeight,
    required this.totalHeight,
  });

  final Session session;
  final double topHeight;
  final double totalHeight;

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) {
          final r = ((widget.topHeight + d.delta.dy) / widget.totalHeight)
              .clamp(0.2, 0.8);
          widget.session.updateSplitRatio(r);
        },
        onVerticalDragEnd: (_) => widget.session.saveConfig(),
        child: Tooltip(
          message: S.t('resizeHint'),
          child: Container(
            height: 10,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _hover ? 48 : 32,
              height: 3,
              decoration: BoxDecoration(
                color: _hover
                    ? Palette.green.withValues(alpha: 0.9)
                    : Palette.border.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
