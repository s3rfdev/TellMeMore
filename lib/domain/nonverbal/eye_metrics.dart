import 'raw_signals.dart';

/// Метрики динамики глаз и взгляда
class EyeDynamics {
  final double blinkBpm;               // Оценка морганий в минуту (норма: 12-22, стресс: >45)
  final int lastBlinkDurationMs;       // Длительность последнего смыкания век (мс)
  final bool isEyeBlocking;            // Глазное блокирование (>350 мс закрытия)
  final bool isSquinting;              // Прищуривание (AU6+AU7 - оценка/скепсис)
  final bool isAverted;                // Увод взгляда от собеседника
  final int gazeFixationMs;            // Непрерывное удержание текущего направления (мс)
  final GazeVector currentGaze;        // Текущий вектор взгляда
  final String gazeInterpretationRu;   // Краткая психологическая трактовка

  const EyeDynamics({
    required this.blinkBpm,
    required this.lastBlinkDurationMs,
    required this.isEyeBlocking,
    required this.isSquinting,
    required this.isAverted,
    required this.gazeFixationMs,
    required this.currentGaze,
    required this.gazeInterpretationRu,
  });

  factory EyeDynamics.baseline() => EyeDynamics(
        blinkBpm: 16.0,
        lastBlinkDurationMs: 140,
        isEyeBlocking: false,
        isSquinting: false,
        isAverted: false,
        gazeFixationMs: 1200,
        currentGaze: GazeVector.center(),
        gazeInterpretationRu: 'Прямой зрительный контакт',
      );

  bool get isStressArousal => blinkBpm > 42.0;
  bool get isHyperFocused => blinkBpm < 8.0 && gazeFixationMs > 4000;
}
