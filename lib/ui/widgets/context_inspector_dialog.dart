import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../session.dart';
import '../theme.dart';
import 'hud_toast.dart';

/// Компактный диалог инспектора импульсов и контекста LLM.
/// Выполнен строго в минималистичном HUD-стиле без громоздких элементов.
class ContextInspectorDialog extends StatelessWidget {
  const ContextInspectorDialog({super.key, required this.session});

  final Session session;

  static void show(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (_) => ContextInspectorDialog(session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prompt = session.getCurrentPromptForInspection();
    final eye = session.nonverbal.latestEyeDynamics;
    final clusters = session.nonverbal.activeClusters;
    final snap = session.nonverbal.latestSnapshot;
    final faceBytes = session.latestCropImageBytes;

    final dialogH = math.min(390.0, MediaQuery.sizeOf(context).height * 0.62);

    return Dialog(
      backgroundColor: Palette.dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Palette.border),
      ),
      child: SizedBox(
        width: 520,
        height: dialogH,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Шапка
              _buildHeader(context, prompt),
              const SizedBox(height: 8),

              // Вкладки
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: Palette.green,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Palette.border,
                        labelColor: Palette.pri,
                        unselectedLabelColor: Palette.sec,
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(
                            height: 26,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.crop_original_rounded, size: 12),
                                const SizedBox(width: 5),
                                Text(faceBytes != null ? 'Кадр лица' : 'Кадр (нет)'),
                              ],
                            ),
                          ),
                          const Tab(
                            height: 26,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove_red_eye_outlined, size: 12),
                                SizedBox(width: 5),
                                Text('Невербалика'),
                              ],
                            ),
                          ),
                          const Tab(
                            height: 26,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.code_rounded, size: 12),
                                SizedBox(width: 5),
                                Text('XML-промпт'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildFaceFrameTab(faceBytes),
                            _buildNonverbalTab(eye, clusters, snap),
                            _buildPromptTab(prompt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String prompt) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          const Icon(Icons.psychology_outlined, size: 15, color: Palette.green),
          const SizedBox(width: 6),
          const Text(
            'Инспектор импульсов',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Palette.pri,
            ),
          ),
          const Spacer(),
          // Скопировать сырой XML
          Tooltip(
            message: 'Скопировать XML-промпт в буфер',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: prompt));
                  HudToast.show(context, 'XML-промпт скопирован в буфер обмена');
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Palette.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Palette.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.copy_rounded, size: 12, color: Palette.sec),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Закрыть
          Tooltip(
            message: 'Закрыть',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Palette.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Palette.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close_rounded, size: 13, color: Palette.sec),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceFrameTab(Uint8List? faceBytes) {
    if (faceBytes == null || faceBytes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.crop_free_rounded, size: 24, color: Palette.faint),
            SizedBox(height: 6),
            Text(
              'Кадр лица не захвачен',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Palette.sec),
            ),
            SizedBox(height: 2),
            Text(
              'Включите кроп в шапке окна для анализа лица оппонента',
              style: TextStyle(fontSize: 10, color: Palette.faint),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.green,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${(faceBytes.lengthInBytes / 1024).toStringAsFixed(1)} КБ · Передаётся в модель с каждым Get answer',
                style: const TextStyle(fontSize: 10, color: Palette.green),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: Image.memory(faceBytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNonverbalTab(
    dynamic eye,
    List<dynamic> clusters,
    dynamic snapshot,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('ГЛАЗНАЯ ДИНАМИКА'),
          _metricRow(
            'Частота моргания',
            '${eye.blinkBpm.toInt()} bpm',
            badge: eye.blinkBpm > 30
                ? 'ВЫСОКАЯ'
                : (eye.blinkBpm < 10 ? 'НИЗКАЯ' : 'НОРМА'),
            badgeColor: eye.blinkBpm > 30 ? Palette.amber : Palette.green,
          ),
          _metricRow('Вектор взгляда', eye.gazeInterpretationRu.toString()),
          _metricRow(
            'Глазное блокирование (>350ms)',
            eye.isEyeBlocking ? '⚠️ ДА (скрытое отрицание)' : 'нет',
            alert: eye.isEyeBlocking,
          ),
          _metricRow(
            'Стрессовый всплеск',
            eye.isStressArousal ? '⚠️ ДА' : 'нет',
            alert: eye.isStressArousal,
          ),
          const SizedBox(height: 10),
          _sectionHeader('APPLE VISION FACS (МИКРОМИМИКА)'),
          if (snapshot == null || !snapshot.hasFace)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Text(
                'Лицо не зафиксировано в кадре кропа',
                style: TextStyle(fontSize: 10, color: Palette.faint),
              ),
            )
          else ...[
            _metricRow(
              'AU4 Сведение бровей (концентрация/сомнение)',
              '${(snapshot.blendshapes.browDownLeft * 100).toInt()}%',
              alert: snapshot.blendshapes.browDownLeft > 0.45,
            ),
            _metricRow(
              'AU1+2 Подъём бровей (вопрос/удивление)',
              '${(snapshot.blendshapes.browInnerUp * 100).toInt()}%',
              alert: snapshot.blendshapes.browInnerUp > 0.45,
            ),
            _metricRow(
              'AU24 Поджатие губ (стресс/несогласие)',
              '${(snapshot.blendshapes.mouthPressLeft * 100).toInt()}%',
              alert: snapshot.blendshapes.mouthPressLeft > 0.45,
            ),
            _metricRow(
              'AU14 Асимметрия улыбки (ухмылка/сарказм)',
              '${(snapshot.blendshapes.smileAsymmetry * 100).toInt()}%',
              alert: snapshot.blendshapes.smileAsymmetry > 0.35,
            ),
            _metricRow(
              'AU9 Сморщивание носа (отвращение)',
              '${(snapshot.blendshapes.noseSneerLeft * 100).toInt()}%',
              alert: snapshot.blendshapes.noseSneerLeft > 0.40,
            ),
            _metricRow(
              'Замирание мимики (Freezing response)',
              snapshot.blendshapes.get('isFaceFreezing') > 0.5 ? '⚠️ ДА' : 'нет',
              alert: snapshot.blendshapes.get('isFaceFreezing') > 0.5,
            ),
            _metricRow(
              'Положение головы (Pitch / Yaw)',
              '${(snapshot.headPose.pitch * 57.3).toStringAsFixed(0)}° / ${(snapshot.headPose.yaw * 57.3).toStringAsFixed(0)}°',
            ),
          ],
          const SizedBox(height: 10),
          _sectionHeader('АКТИВНЫЕ ПСИХОЛОГИЧЕСКИЕ КЛАСТЕРЫ'),
          if (clusters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Text(
                'Нейтральное состояние (кластеры не зафиксированы)',
                style: TextStyle(fontSize: 10, color: Palette.faint),
              ),
            )
          else
            for (final c in clusters)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Palette.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Palette.amber.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  c.toPromptContext(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Palette.amber,
                    height: 1.3,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Palette.faint,
        ),
      ),
    );
  }

  Widget _metricRow(
    String label,
    String value, {
    String? badge,
    Color? badgeColor,
    bool alert = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Palette.sec)),
          const Spacer(),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? Palette.green).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ?? Palette.green,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: alert ? FontWeight.w700 : FontWeight.w500,
              color: alert ? Palette.amber : Palette.pri,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptTab(String prompt) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palette.border),
      ),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: SelectableText(
          prompt,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            height: 1.35,
            color: Palette.sec,
          ),
        ),
      ),
    );
  }
}
