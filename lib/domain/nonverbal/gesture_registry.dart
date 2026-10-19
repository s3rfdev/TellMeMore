import 'micro_events.dart';
import 'behavioral_cluster.dart';

/// Определение правила формирования поведенческого кластера
class ClusterDefinition {
  final ClusterType type;
  final String titleRu;
  final List<MicroEventType> requiredEvents;
  final int minEventCount;
  final Duration observationWindow;
  final String summaryRu;
  final String tacticalAdviceRu;

  const ClusterDefinition({
    required this.type,
    required this.titleRu,
    required this.requiredEvents,
    required this.minEventCount,
    required this.observationWindow,
    required this.summaryRu,
    required this.tacticalAdviceRu,
  });
}

/// Расширяемый реестр определений жестов и кластеров
class GestureRegistry {
  static final List<ClusterDefinition> defaultDefinitions = [
    ClusterDefinition(
      type: ClusterType.skepticism,
      titleRu: 'Скепсис и скрытое несогласие',
      requiredEvents: [
        MicroEventType.browFurrow,
        MicroEventType.unilateralSmirk,
        MicroEventType.eyeSquint,
      ],
      minEventCount: 2,
      observationWindow: const Duration(milliseconds: 2000),
      summaryRu: 'Оппонент критически оценивает слова и сомневается в обоснованности, сдерживая возражение.',
      tacticalAdviceRu: 'Не вступайте в прямое доказывание; запросите обратную связь: «Чувствую, у вас есть встречные мысли по этому пункту — что вызывает сомнения?»',
    ),
    ClusterDefinition(
      type: ClusterType.suppressedStress,
      titleRu: 'Скрытый стресс и дискомфорт',
      requiredEvents: [
        MicroEventType.blinkBurst,
        MicroEventType.lipPress,
        MicroEventType.jawClench,
      ],
      minEventCount: 2,
      observationWindow: const Duration(milliseconds: 2200),
      summaryRu: 'Обсуждаемая тема вызывает вегетативное напряжение; позиция оппонента уязвима или вызывает сильную тревогу.',
      tacticalAdviceRu: 'Сделайте паузу, дайте оппоненту заговорить первым. Не снижайте планку требований — оппонент близок к уступке.',
    ),
    ClusterDefinition(
      type: ClusterType.falseAgreement,
      titleRu: 'Неконгруэнтное (ложное) согласие',
      requiredEvents: [
        MicroEventType.microHeadShake,
        MicroEventType.eyeBlocking,
        MicroEventType.lipPress,
      ],
      minEventCount: 2,
      observationWindow: const Duration(milliseconds: 2500),
      summaryRu: 'Слова согласия сопровождаются бессознательными сигналами отрицания и отгораживания. Договоренность под угрозой срыва.',
      tacticalAdviceRu: 'Сразу же переведите разговор в конкретику: «Давайте прямо сейчас зафиксируем зоны ответственности и дедлайн, чтобы ничто не сорвалось».',
    ),
    ClusterDefinition(
      type: ClusterType.cognitiveSearch,
      titleRu: 'Когнитивное замешательство / подбор формулировки',
      requiredEvents: [
        MicroEventType.gazeAversion,
        MicroEventType.browInnerRaise,
        MicroEventType.browFurrow,
      ],
      minEventCount: 2,
      observationWindow: const Duration(milliseconds: 1800),
      summaryRu: 'Оппонент не имеет готового ответа, конструирует аргумент на ходу или ищет спасительную формулировку.',
      tacticalAdviceRu: 'Дайте ему завершить мысль без перебивания, после чего задайте уточняющий фактологический вопрос по деталям.',
    ),
    ClusterDefinition(
      type: ClusterType.defensiveness,
      titleRu: 'Защитная позиция / отгораживание',
      requiredEvents: [
        MicroEventType.eyeBlocking,
        MicroEventType.gazeAversion,
        MicroEventType.lipPress,
      ],
      minEventCount: 2,
      observationWindow: const Duration(milliseconds: 2400),
      summaryRu: 'Оппонент закрывается от диалога, дистанцируется от предложения и воспринимает контакт негативно.',
      tacticalAdviceRu: 'Смените тональность на эмпатическую; снизьте градус напора и спросите о приоритетах самого оппонента.',
    ),
  ];
}
