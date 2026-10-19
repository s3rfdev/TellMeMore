/// Типы дискретных микро-событий (FACS & Eye & Gestures)
enum MicroEventType {
  browFurrow,         // AU4: Нахмуривание бровей (сомнение / концентрация / несогласие)
  browInnerRaise,     // AU1: Подъем внутренних уголков бровей (беспокойство / удивление)
  unilateralSmirk,    // AU14 / asym AU12: Односторонняя ухмылка (скепсис / презрение)
  lipPress,           // AU24: Сжатие губ в полоску (подавление реплики / несогласие)
  jawClench,          // Напряжение челюсти / желваки (подавленный стресс / гнев)
  blinkBurst,         // Резкий всплеск морганий (вегетативный стресс)
  eyeBlocking,        // Затяжное смыкание век >350 мс (отгораживание / отказ воспринимать)
  gazeAversion,       // Внезапный увод взгляда в момент ключевого тезиса
  eyeSquint,          // AU6+AU7: Прищуривание (подозрение / критическая оценка)
  microNod,           // Микрокивок (<300 мс)
  microHeadShake,     // Микропокачивание головой «нет» во время согласия (неконгруэнтность)
}

/// Дискретное микро-событие во времени
class MicroEvent {
  final String id;
  final MicroEventType type;
  final DateTime timestamp;
  final int durationMs;      // Длительность всплеска (80-500 мс)
  final double intensity;    // 0.0 .. 1.0
  final double confidence;   // Достоверность детекции
  final String labelRu;      // Краткое русское название
  final String descriptionRu;// Описание для отображения в HUD

  const MicroEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.durationMs,
    required this.intensity,
    required this.confidence,
    required this.labelRu,
    required this.descriptionRu,
  });

  String toPromptTag() {
    return '[$labelRu (длительность: $durationMs мс, интенсивность: ${(intensity * 100).toInt()}%, $descriptionRu)]';
  }
}
