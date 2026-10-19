import 'package:flutter/material.dart';
import '../../session.dart';
import '../theme.dart';
import 'crop_selector_dialog.dart';

/// Интерактивная панель управления видеопотоком (Кроп окна и Тренажёр)
class VisionModePanel extends StatelessWidget {
  const VisionModePanel({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    if (session.visionMode == VisionMode.off) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: session.visionMode == VisionMode.screenCrop
              ? Palette.them.withValues(alpha: 0.5)
              : Palette.green.withValues(alpha: 0.5),
        ),
      ),
      child: session.visionMode == VisionMode.screenCrop
          ? _buildScreenCropControls(context)
          : _buildSimulatorControls(context),
    );
  }

  /// Элементы управления режимом «Кроп окна»
  Widget _buildScreenCropControls(BuildContext context) {
    final hasRect = session.cropRect != null;
    final isRunning = session.isCropAnalyzing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.crop_free, size: 15, color: Palette.them),
            const SizedBox(width: 6),
            const Text(
              'Режим: Кроп окна (Анализ оппонента в звонке / YouTube)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Palette.pri,
              ),
            ),
            const Spacer(),
            if (isRunning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Palette.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: Palette.green),
                    SizedBox(width: 4),
                    Text('Захват активен (20 FPS)', style: TextStyle(fontSize: 10, color: Palette.green)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Кнопка открытия интерактивной рамки выбора
            ElevatedButton.icon(
              onPressed: () => CropSelectorDialog.show(context, session),
              icon: const Icon(Icons.aspect_ratio, size: 14),
              label: Text(
                hasRect ? 'Изменить область кропа' : 'Выбрать область на экране',
                style: const TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.them,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),

            // Кнопка включения/паузы анализа
            if (hasRect)
              OutlinedButton.icon(
                onPressed: () => session.toggleCropAnalysis(),
                icon: Icon(isRunning ? Icons.pause : Icons.play_arrow, size: 14),
                label: Text(isRunning ? 'Пауза' : 'Старт анализа', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isRunning ? Palette.amber : Palette.green,
                  side: BorderSide(color: isRunning ? Palette.amber : Palette.green),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            const SizedBox(width: 8),

            // Координаты области
            Text(
              hasRect
                  ? 'Зона: ${session.cropRect!.width.toInt()}x${session.cropRect!.height.toInt()} px'
                  : 'Область не выбрана. Нажмите «Выбрать область на экране».',
              style: const TextStyle(fontSize: 11, color: Palette.faint),
            ),
          ],
        ),
      ],
    );
  }

  /// Элементы управления режимом «Тренажёр / Симулятор»
  Widget _buildSimulatorControls(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.camera_front, size: 15, color: Palette.green),
            SizedBox(width: 6),
            Text(
              'Режим: Тренажёр & Демо-пульт психологических реакций',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Palette.pri,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Кликните сценарий ниже, чтобы мгновенно подать микрожест в систему и нажать ⌥1 для проверки подсказки LLM:',
          style: TextStyle(fontSize: 11, color: Palette.sec),
        ),
        const SizedBox(height: 8),

        // Кнопки быстрой симуляции реакций
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildScenarioButton(
              label: '🎭 Скепсис оппонента (AU4 + AU14)',
              scenario: 'skepticism',
              color: Palette.amber,
              tooltip: 'Имитация нахмуривания бровей, ухмылки и прищуривания',
            ),
            _buildScenarioButton(
              label: '⚡ Скрытый стресс (58 bpm + зажим)',
              scenario: 'stress',
              color: Palette.red,
              tooltip: 'Имитация всплеска морганий, сжатия губ и увода взгляда',
            ),
            _buildScenarioButton(
              label: '🤝 Ложное согласие (отрицание)',
              scenario: 'false_agreement',
              color: Palette.blue,
              tooltip: 'Имитация затяжного смыкания век и поджатых губ при словах согласия',
            ),
            _buildScenarioButton(
              label: '🔄 Сброс в норму',
              scenario: 'reset',
              color: Palette.faint,
              tooltip: 'Вернуть лицо в спокойное нейтральное состояние',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScenarioButton({
    required String label,
    required String scenario,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => session.simulateScenario(scenario),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
