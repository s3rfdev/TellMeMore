import 'micro_events.dart';

/// Типы психологических кластеров невербального поведения
enum ClusterType {
  skepticism,          // Скепсис и скрытое несогласие
  suppressedStress,     // Подавленный стресс / напряжение
  falseAgreement,       // Неконгруэнтное (ложное) согласие
  cognitiveSearch,      // Когнитивный поиск / формулирование легенды
  genuineInterest,      // Искренняя вовлечённость и доверие
  dominancePress,       // Попытка нажима / доминирование
  defensiveness,        // Огораживание / защитная реакция
}

/// Поведенческий кластер — совокупность 2+ невербальных реакций в окне 0.5-2.5с
class BehavioralCluster {
  final String id;
  final ClusterType type;
  final DateTime timestamp;
  final double confidence;
  final List<MicroEvent> supportingEvents;
  final String titleRu;
  final String summaryRu;
  final String tacticalAdviceRu;

  const BehavioralCluster({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.confidence,
    required this.supportingEvents,
    required this.titleRu,
    required this.summaryRu,
    required this.tacticalAdviceRu,
  });

  /// Форматирование кластера для включения в промпт для LLM
  String toPromptContext() {
    final eventsStr = supportingEvents.map((e) => e.labelRu).join(' + ');
    return '⚠️ [ПОВЕДЕНЧЕСКИЙ КЛАСТЕР: $titleRu]\n'
           '  • Комплекс реакций: $eventsStr\n'
           '  • Оценка состояния: $summaryRu\n'
           '  • Тактическая рекомендация: $tacticalAdviceRu';
  }
}
