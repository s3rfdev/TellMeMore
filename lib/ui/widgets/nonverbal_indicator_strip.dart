import 'package:flutter/material.dart';
import '../../session.dart';
import '../theme.dart';

/// Компактная полоса невербальных индикаторов в стиле минимализма (иконки, чипы, статус стресса)
class NonverbalIndicatorStrip extends StatelessWidget {
  const NonverbalIndicatorStrip({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TemporalAnalysisResult>(
      stream: session.nonverbal.analysisStream,
      initialData: TemporalAnalysisResult(
        snapshot: FaceFrameSnapshot.empty(),
        eyeDynamics: session.nonverbal.latestEyeDynamics,
        newEvents: const [],
        activeClusters: session.nonverbal.activeClusters,
      ),
      builder: (context, snapshot) {
        final eye = snapshot.data?.eyeDynamics ?? session.nonverbal.latestEyeDynamics;
        final clusters = session.nonverbal.activeClusters;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Palette.card.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Palette.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Индикатор режима зрения (Vision Mode)
              _buildVisionModeIcon(session.visionMode),
              const SizedBox(width: 8),

              // 2. Индикатор частоты моргания (Blink BPM)
              _buildBlinkBpmChip(eye),
              const SizedBox(width: 6),

              // 3. Индикатор направления взгляда
              _buildGazeChip(eye),
              const SizedBox(width: 6),

              // 4. Активные поведенческие кластеры
              if (clusters.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: clusters.map((c) => _buildClusterBadge(c)).toList(),
                    ),
                  ),
                )
              else
                const Text(
                  'Фон нейтральный',
                  style: TextStyle(fontSize: 11, color: Palette.faint),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisionModeIcon(VisionMode mode) {
    final IconData icon;
    final Color color;
    final String tooltip;

    switch (mode) {
      case VisionMode.off:
        icon = Icons.videocam_off_outlined;
        color = Palette.faint;
        tooltip = 'Анализ мимики отключён';
        break;
      case VisionMode.screenCrop:
        icon = Icons.crop_free;
        color = Palette.them;
        tooltip = 'Анализ лица в окне звонка (Screen Crop)';
        break;
      case VisionMode.simulator:
        icon = Icons.camera_front;
        color = Palette.green;
        tooltip = 'Режим тренажёра (Веб-камера)';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 15, color: color),
    );
  }

  Widget _buildBlinkBpmChip(EyeDynamics eye) {
    final isStress = eye.isStressArousal;
    final bpm = eye.blinkBpm.toInt();
    final color = isStress ? Palette.red : (bpm < 8 ? Palette.amber : Palette.green);

    return Tooltip(
      message: 'Частота моргания: $bpm в мин\n'
          '${eye.isEyeBlocking ? "⚠️ Зафиксировано затяжное закрытие глаз (>350мс)" : ""}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              eye.isEyeBlocking ? Icons.visibility_off : Icons.remove_red_eye_outlined,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$bpm bpm',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGazeChip(EyeDynamics eye) {
    return Tooltip(
      message: eye.gazeInterpretationRu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Palette.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              eye.isAverted ? Icons.turn_right : Icons.center_focus_strong,
              size: 10,
              color: eye.isAverted ? Palette.amber : Palette.sec,
            ),
            const SizedBox(width: 3),
            Text(
              eye.currentGaze.direction.name,
              style: const TextStyle(fontSize: 9, color: Palette.sec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterBadge(BehavioralCluster cluster) {
    final isNegative = cluster.type == ClusterType.skepticism ||
        cluster.type == ClusterType.suppressedStress ||
        cluster.type == ClusterType.falseAgreement;

    final color = isNegative ? Palette.amber : Palette.them;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: '${cluster.titleRu}\n${cluster.summaryRu}\n👉 ${cluster.tacticalAdviceRu}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                cluster.titleRu,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
