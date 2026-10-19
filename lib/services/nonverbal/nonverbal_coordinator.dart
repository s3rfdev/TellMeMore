import 'dart:async';
import '../../domain/nonverbal/raw_signals.dart';
import '../../domain/nonverbal/eye_metrics.dart';
import '../../domain/nonverbal/micro_events.dart';
import '../../domain/nonverbal/behavioral_cluster.dart';
import 'temporal_detector.dart';

/// Координатор невербального анализа MIMIC.
/// Центральный хаб, объединяющий сырые метрики компьютерного зрения,
/// темпоральный детектор, глазные метрики и выдающий готовую аналитику в UI и LLM.
class NonverbalCoordinator {
  final TemporalDetector _detector = TemporalDetector();

  EyeDynamics _latestEyeDynamics = EyeDynamics.baseline();
  EyeDynamics get latestEyeDynamics => _latestEyeDynamics;

  FaceFrameSnapshot? _latestSnapshot;
  FaceFrameSnapshot? get latestSnapshot => _latestSnapshot;

  final List<MicroEvent> _recentEvents = [];
  List<MicroEvent> get recentEvents => List.unmodifiable(_recentEvents);

  final List<BehavioralCluster> _activeClusters = [];
  List<BehavioralCluster> get activeClusters => List.unmodifiable(_activeClusters);

  final _analysisStreamController = StreamController<TemporalAnalysisResult>.broadcast();
  Stream<TemporalAnalysisResult> get analysisStream => _analysisStreamController.stream;

  /// Обработка очередного фрейма (от камеры тренажера или кропа экрана)
  void processFrame(FaceFrameSnapshot frame) {
    _latestSnapshot = frame;
    final result = _detector.processFrame(frame);
    _latestEyeDynamics = result.eyeDynamics;

    if (result.newEvents.isNotEmpty) {
      _recentEvents.addAll(result.newEvents);
      if (_recentEvents.length > 50) {
        _recentEvents.removeRange(0, _recentEvents.length - 50);
      }
    }

    _activeClusters.clear();
    _activeClusters.addAll(result.activeClusters);

    _analysisStreamController.add(result);
  }

  /// Получить сводку невербальных сигналов для инъекции в промпт LLM
  String getPromptContextForLlm() {
    final buf = StringBuffer();

    // 1. Глазные метрики
    buf.writeln('<eye_dynamics>');
    buf.writeln('  Частота моргания: ${_latestEyeDynamics.blinkBpm.toInt()} в минуту (норма: 12-22)');
    if (_latestEyeDynamics.isStressArousal) {
      buf.writeln('  ⚠️ Зафиксирован всплеск стресса/возбуждения (учащенное моргание)');
    }
    if (_latestEyeDynamics.isEyeBlocking) {
      buf.writeln('  ⚠️ Зафиксировано глазное блокирование (затяжное смыкание век)');
    }
    buf.writeln('  Вектор взгляда: ${_latestEyeDynamics.gazeInterpretationRu}');
    buf.writeln('</eye_dynamics>');

    // 2. Активные кластеры реакций
    if (_activeClusters.isNotEmpty) {
      buf.writeln('<behavioral_clusters>');
      for (final cluster in _activeClusters) {
        buf.writeln(cluster.toPromptContext());
      }
      buf.writeln('</behavioral_clusters>');
    }

    // 3. Недавние дискретные микро-события (за последние 5 секунд)
    final recentCutoff = DateTime.now().subtract(const Duration(seconds: 5));
    final liveEvents = _recentEvents.where((e) => e.timestamp.isAfter(recentCutoff)).toList();
    if (liveEvents.isNotEmpty) {
      buf.writeln('<recent_micro_events>');
      for (final ev in liveEvents) {
        buf.writeln('  • ${ev.toPromptTag()}');
      }
      buf.writeln('</recent_micro_events>');
    }

    return buf.toString().trim();
  }

  /// Возвращает компактный список невербальных тегов для текущей реплики диалога
  List<String> getCurrentTurnTags() {
    final tags = <String>[];
    if (_latestEyeDynamics.isEyeBlocking) {
      tags.add('Глазное блокирование (>350ms)');
    }
    if (_latestEyeDynamics.isStressArousal) {
      tags.add('Стресс (моргание ${_latestEyeDynamics.blinkBpm.toInt()} bpm)');
    } else if (_latestEyeDynamics.blinkBpm > 28) {
      tags.add('Учащённое моргание (${_latestEyeDynamics.blinkBpm.toInt()} bpm)');
    }
    if (_latestEyeDynamics.gazeInterpretationRu != 'Прямой зрительный контакт' &&
        _latestEyeDynamics.gazeInterpretationRu.isNotEmpty) {
      tags.add('Взгляд: ${_latestEyeDynamics.gazeInterpretationRu}');
    }

    for (final c in _activeClusters) {
      tags.add(c.titleRu);
    }

    final recentCutoff = DateTime.now().subtract(const Duration(seconds: 4));
    for (final ev in _recentEvents.where((e) => e.timestamp.isAfter(recentCutoff))) {
      final tag = ev.labelRu;
      if (!tags.contains(tag)) tags.add(tag);
    }
    return tags;
  }

  void dispose() {
    _analysisStreamController.close();
  }
}
