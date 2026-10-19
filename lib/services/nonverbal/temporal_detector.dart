import 'dart:math';
import '../../domain/nonverbal/raw_signals.dart';
import '../../domain/nonverbal/eye_metrics.dart';
import '../../domain/nonverbal/micro_events.dart';
import '../../domain/nonverbal/behavioral_cluster.dart';
import '../../domain/nonverbal/gesture_registry.dart';

/// Детектор временных паттернов, микромимики и поведенческих кластеров.
/// Работает со скользящим окном кадров (30–60 FPS) и отслеживает индивидуальную базовую линию (Baseline).
class TemporalDetector {
  // Скользящее окно недавних кадров (до 90 кадров / ~3 секунды)
  final List<FaceFrameSnapshot> _history = [];
  static const int _maxHistory = 90;

  // Динамическая базовая линия (спокойное состояние лица)
  double _baseBrowDown = 0.05;
  double _baseMouthPress = 0.05;
  double _baseSmileAsym = 0.03;

  // Анализ моргания
  final List<DateTime> _blinkTimestamps = [];
  DateTime? _blinkStartTime;
  int _lastBlinkDurationMs = 140;

  // Анализ взгляда
  GazeVector _lastGaze = GazeVector.center();
  DateTime _lastGazeChange = DateTime.now();

  // История наклонов и поворотов головы (до 1.2 с) для детекции кивков и покачиваний
  final List<({DateTime time, double yaw, double pitch})> _poseHistory = [];

  // Недавние микро-события (хранятся до 5 секунд для сопоставления кластеров)
  final List<MicroEvent> _recentEvents = [];

  // Кулдаун для предотвращения спама одинаковыми событиями
  final Map<MicroEventType, DateTime> _eventCooldowns = {};

  /// Обработка нового кадра лица
  TemporalAnalysisResult processFrame(FaceFrameSnapshot frame) {
    if (!frame.hasFace) {
      return TemporalAnalysisResult.empty();
    }

    final now = frame.timestamp;
    _history.add(frame);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    // Буфер динамики головы
    _poseHistory.add((time: now, yaw: frame.headPose.yaw, pitch: frame.headPose.pitch));
    _poseHistory.removeWhere((p) => now.difference(p.time).inMilliseconds > 1200);

    _updateBaseline(frame);
    _processEyeBlinks(frame, now);
    _processGaze(frame, now);

    final newEvents = <MicroEvent>[];
    _detectMicroExpressions(frame, now, newEvents);
    _detectEyeEvents(frame, now, newEvents);
    _detectHeadMotions(frame, now, newEvents);

    _cleanOldEvents(now);
    _recentEvents.addAll(newEvents);

    final activeClusters = _evaluateClusters(now);
    final eyeDynamics = _buildEyeDynamics(frame, now);

    return TemporalAnalysisResult(
      snapshot: frame,
      eyeDynamics: eyeDynamics,
      newEvents: newEvents,
      activeClusters: activeClusters,
    );
  }

  /// Обновление плавной базовой линии (нейтрального выражения)
  void _updateBaseline(FaceFrameSnapshot f) {
    const alpha = 0.01; // Очень медленная адаптация
    _baseBrowDown = (1 - alpha) * _baseBrowDown + alpha * f.blendshapes.browDownAvg;
    _baseMouthPress = (1 - alpha) * _baseMouthPress + alpha * f.blendshapes.mouthPressAvg;
    _baseSmileAsym = (1 - alpha) * _baseSmileAsym + alpha * f.blendshapes.smileAsymmetry;
  }

  /// Обработка морганий и расчет длительности
  void _processEyeBlinks(FaceFrameSnapshot f, DateTime now) {
    final blinkAvg = f.blendshapes.eyeBlinkAvg;
    final isClosed = blinkAvg > 0.60;

    if (isClosed) {
      _blinkStartTime ??= now;
    } else {
      if (_blinkStartTime != null) {
        final durationMs = now.difference(_blinkStartTime!).inMilliseconds;
        if (durationMs >= 60 && durationMs <= 1500) {
          _lastBlinkDurationMs = durationMs;
          _blinkTimestamps.add(now);
        }
        _blinkStartTime = null;
      }
    }

    // Удаляем моргания старше 60 секунд
    _blinkTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);
  }

  /// Анализ вектора взгляда
  void _processGaze(FaceFrameSnapshot f, DateTime now) {
    final gaze = f.gaze;
    final delta = (gaze.yaw - _lastGaze.yaw).abs() + (gaze.pitch - _lastGaze.pitch).abs();
    if (delta > 0.35) {
      _lastGaze = gaze;
      _lastGazeChange = now;
    }
  }

  /// Детекция микромимики по FACS Action Units
  void _detectMicroExpressions(FaceFrameSnapshot f, DateTime now, List<MicroEvent> out) {
    final bs = f.blendshapes;

    // 1. Нахмуривание бровей (AU4) — всплеск выше базовой линии
    final browSpike = bs.browDownAvg - _baseBrowDown;
    if (browSpike > 0.28 && _canTrigger(MicroEventType.browFurrow, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_brow',
        type: MicroEventType.browFurrow,
        timestamp: now,
        durationMs: 180,
        intensity: (browSpike * 2.0).clamp(0.0, 1.0),
        confidence: 0.85,
        labelRu: 'Микро-нахмуривание (AU4)',
        descriptionRu: 'Сомнение, скрытое несогласие или резкая концентрация',
      ));
      _setCooldown(MicroEventType.browFurrow, now, 800);
    }

    // 2. Односторонняя ухмылка (AU14 / AU12 асимметрия)
    final smirkDelta = bs.smileAsymmetry - _baseSmileAsym;
    if (smirkDelta > 0.18 && _canTrigger(MicroEventType.unilateralSmirk, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_smirk',
        type: MicroEventType.unilateralSmirk,
        timestamp: now,
        durationMs: 220,
        intensity: (smirkDelta * 2.5).clamp(0.0, 1.0),
        confidence: 0.88,
        labelRu: 'Асимметричная ухмылка (AU14)',
        descriptionRu: 'Скепсис, ирония, скрытое превосходство или презрение',
      ));
      _setCooldown(MicroEventType.unilateralSmirk, now, 1200);
    }

    // 3. Сжатие губ в полоску (AU24)
    final pressSpike = bs.mouthPressAvg - _baseMouthPress;
    if (pressSpike > 0.30 && _canTrigger(MicroEventType.lipPress, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_lippress',
        type: MicroEventType.lipPress,
        timestamp: now,
        durationMs: 250,
        intensity: (pressSpike * 2.0).clamp(0.0, 1.0),
        confidence: 0.82,
        labelRu: 'Сжатие губ (AU24)',
        descriptionRu: 'Сдерживание несогласия, подавление слов, внутреннее напряжение',
      ));
      _setCooldown(MicroEventType.lipPress, now, 900);
    }

    // 4. Напряжение челюсти (AU29/31)
    if (bs.jawOpen < 0.05 && pressSpike > 0.20 && _canTrigger(MicroEventType.jawClench, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_jaw',
        type: MicroEventType.jawClench,
        timestamp: now,
        durationMs: 350,
        intensity: 0.75,
        confidence: 0.78,
        labelRu: 'Напряжение челюсти',
        descriptionRu: 'Подавленная фрустрация или агрессия',
      ));
      _setCooldown(MicroEventType.jawClench, now, 1500);
    }
  }

  /// Детекция событий глаз и моргания
  void _detectEyeEvents(FaceFrameSnapshot f, DateTime now, List<MicroEvent> out) {
    // 1. Всплеск частоты моргания (>45 bpm)
    final currentBpm = _calculateBpm();
    if (currentBpm > 44.0 && _canTrigger(MicroEventType.blinkBurst, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_blinkburst',
        type: MicroEventType.blinkBurst,
        timestamp: now,
        durationMs: 1200,
        intensity: ((currentBpm - 30) / 40).clamp(0.0, 1.0),
        confidence: 0.90,
        labelRu: 'Всплеск моргания ($currentBpm/мин)',
        descriptionRu: 'Сильный вегетативный стресс или резкая когнитивная нагрузка',
      ));
      _setCooldown(MicroEventType.blinkBurst, now, 3000);
    }

    // 2. Глазное блокирование (смыкание век >350 мс)
    if (_lastBlinkDurationMs > 350 && _canTrigger(MicroEventType.eyeBlocking, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_eyeblock',
        type: MicroEventType.eyeBlocking,
        timestamp: now,
        durationMs: _lastBlinkDurationMs,
        intensity: (_lastBlinkDurationMs / 600.0).clamp(0.0, 1.0),
        confidence: 0.86,
        labelRu: 'Глазное блокирование ($_lastBlinkDurationMs мс)',
        descriptionRu: 'Подсознательное отгораживание, демонстрация несогласия или превосходства',
      ));
      _setCooldown(MicroEventType.eyeBlocking, now, 1800);
    }

    // 3. Резкий увод взгляда
    if (f.gaze.direction == GazeDirectionType.averted && _canTrigger(MicroEventType.gazeAversion, now)) {
      out.add(MicroEvent(
        id: 'ev_${now.millisecondsSinceEpoch}_gazeavert',
        type: MicroEventType.gazeAversion,
        timestamp: now,
        durationMs: 400,
        intensity: 0.70,
        confidence: 0.80,
        labelRu: 'Увод взгляда',
        descriptionRu: 'Дискомфорт от прямого зрительного контакта или уклонение от ответа',
      ));
      _setCooldown(MicroEventType.gazeAversion, now, 1500);
    }
  }

  /// Детекция микродвижений головы: кивок «да» и покачивание «нет» (Head Nod / Head Shake)
  void _detectHeadMotions(FaceFrameSnapshot f, DateTime now, List<MicroEvent> out) {
    if (_poseHistory.length < 5) return;

    // 1. Покачивание головой «нет» (Head Shake):
    final recentCutoff = now.subtract(const Duration(milliseconds: 850));
    final window = _poseHistory.where((p) => p.time.isAfter(recentCutoff)).toList();
    if (window.length >= 5) {
      double minYaw = window.first.yaw;
      double maxYaw = window.first.yaw;
      int directionChanges = 0;
      double lastDiff = 0.0;

      for (int i = 1; i < window.length; i++) {
        final currentYaw = window[i].yaw;
        if (currentYaw < minYaw) minYaw = currentYaw;
        if (currentYaw > maxYaw) maxYaw = currentYaw;

        final diff = currentYaw - window[i - 1].yaw;
        if (diff.abs() > 0.02) {
          if (lastDiff != 0.0 && (diff > 0) != (lastDiff > 0)) {
            directionChanges++;
          }
          lastDiff = diff;
        }
      }

      final yawSpan = maxYaw - minYaw;
      // Амплитуда колебаний >= 0.07 rad (~4°) и смена направления хотя бы 2 раза
      if (yawSpan >= 0.07 && directionChanges >= 2 && _canTrigger(MicroEventType.microHeadShake, now)) {
        out.add(MicroEvent(
          id: 'ev_${now.millisecondsSinceEpoch}_headshake',
          type: MicroEventType.microHeadShake,
          timestamp: now,
          durationMs: 450,
          intensity: (yawSpan / 0.20).clamp(0.0, 1.0),
          confidence: 0.84,
          labelRu: 'Покачивание головой «нет»',
          descriptionRu: 'Невербальное отрицание, несогласие или сопротивление',
        ));
        _setCooldown(MicroEventType.microHeadShake, now, 1600);
      }

      // 2. Кивок головой «да» (Head Nod):
      double minPitch = window.first.pitch;
      double maxPitch = window.first.pitch;
      for (final p in window) {
        if (p.pitch < minPitch) minPitch = p.pitch;
        if (p.pitch > maxPitch) maxPitch = p.pitch;
      }
      final pitchSpan = maxPitch - minPitch;
      if (pitchSpan >= 0.08 && _canTrigger(MicroEventType.microNod, now)) {
        out.add(MicroEvent(
          id: 'ev_${now.millisecondsSinceEpoch}_headnod',
          type: MicroEventType.microNod,
          timestamp: now,
          durationMs: 380,
          intensity: (pitchSpan / 0.18).clamp(0.0, 1.0),
          confidence: 0.82,
          labelRu: 'Кивок головой «да»',
          descriptionRu: 'Невербальное подтверждение или искреннее согласие',
        ));
        _setCooldown(MicroEventType.microNod, now, 1400);
      }
    }
  }

  /// Проверка совпадения поведенческих кластеров (совокупность 2+ сигналов)
  List<BehavioralCluster> _evaluateClusters(DateTime now) {
    final active = <BehavioralCluster>[];

    for (final def in GestureRegistry.defaultDefinitions) {
      final windowStart = now.subtract(def.observationWindow);
      final matchingEvents = _recentEvents
          .where((e) => e.timestamp.isAfter(windowStart) && def.requiredEvents.contains(e.type))
          .toList();

      // Уникальные типы событий
      final distinctTypes = matchingEvents.map((e) => e.type).toSet();
      if (distinctTypes.length >= def.minEventCount) {
        active.add(BehavioralCluster(
          id: 'cluster_${now.millisecondsSinceEpoch}_${def.type.name}',
          type: def.type,
          timestamp: now,
          confidence: min(0.95, 0.65 + distinctTypes.length * 0.12),
          supportingEvents: matchingEvents,
          titleRu: def.titleRu,
          summaryRu: def.summaryRu,
          tacticalAdviceRu: def.tacticalAdviceRu,
        ));
      }
    }

    return active;
  }

  EyeDynamics _buildEyeDynamics(FaceFrameSnapshot f, DateTime now) {
    final bpm = _calculateBpm();
    final fixationMs = now.difference(_lastGazeChange).inMilliseconds;
    final isSquint = f.blendshapes.eyeSquintAvg > 0.40;

    String interpretation;
    switch (f.gaze.direction) {
      case GazeDirectionType.upLeft:
        interpretation = 'Взгляд вверх-влево (зрительная память/факты)';
        break;
      case GazeDirectionType.upRight:
        interpretation = 'Взгляд вверх-вправо (конструирование образа/версии)';
        break;
      case GazeDirectionType.downLeft:
      case GazeDirectionType.downRight:
        interpretation = 'Взгляд вниз (внутренний диалог / эмоциональный поиск)';
        break;
      case GazeDirectionType.averted:
        interpretation = 'Увод взгляда (дискомфорт / закрытость)';
        break;
      case GazeDirectionType.center:
      default:
        interpretation = fixationMs > 3500
            ? 'Фиксированный пристальный взгляд'
            : 'Прямой контакт';
        break;
    }

    return EyeDynamics(
      blinkBpm: bpm,
      lastBlinkDurationMs: _lastBlinkDurationMs,
      isEyeBlocking: _lastBlinkDurationMs > 350,
      isSquinting: isSquint,
      isAverted: f.gaze.direction == GazeDirectionType.averted,
      gazeFixationMs: fixationMs,
      currentGaze: f.gaze,
      gazeInterpretationRu: interpretation,
    );
  }

  double _calculateBpm() {
    if (_blinkTimestamps.isEmpty) return 16.0;
    // Оцениваем частоту за последнюю минуту
    return (_blinkTimestamps.length * (60.0 / 60.0)).clamp(4.0, 90.0);
  }

  void _cleanOldEvents(DateTime now) {
    _recentEvents.removeWhere((e) => now.difference(e.timestamp).inSeconds > 5);
  }

  bool _canTrigger(MicroEventType type, DateTime now) {
    final last = _eventCooldowns[type];
    if (last == null) return true;
    return now.difference(last).inMilliseconds > 0;
  }

  void _setCooldown(MicroEventType type, DateTime now, int ms) {
    _eventCooldowns[type] = now.add(Duration(milliseconds: ms));
  }
}

/// Результат одного шага темпорального анализа
class TemporalAnalysisResult {
  final FaceFrameSnapshot snapshot;
  final EyeDynamics eyeDynamics;
  final List<MicroEvent> newEvents;
  final List<BehavioralCluster> activeClusters;

  const TemporalAnalysisResult({
    required this.snapshot,
    required this.eyeDynamics,
    required this.newEvents,
    required this.activeClusters,
  });

  factory TemporalAnalysisResult.empty() => TemporalAnalysisResult(
        snapshot: FaceFrameSnapshot.empty(),
        eyeDynamics: EyeDynamics.baseline(),
        newEvents: const [],
        activeClusters: const [],
      );
}
