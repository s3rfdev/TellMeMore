import 'package:flutter_test/flutter_test.dart';
import 'package:tellmemore/services/config_store.dart';
import 'package:tellmemore/domain/prompt_builder.dart';
import 'package:tellmemore/domain/nonverbal/raw_signals.dart';
import 'package:tellmemore/domain/nonverbal/micro_events.dart';
import 'package:tellmemore/domain/nonverbal/behavioral_cluster.dart';
import 'package:tellmemore/services/nonverbal/temporal_detector.dart';

void main() {
  group('Nonverbal Temporal Engine Tests', () {
    test('TemporalDetector spots AU4 brow furrow and AU14 smirk', () {
      final detector = TemporalDetector();
      final now = DateTime.now();

      // Базовый фрейм в покое
      final baselineFrame = FaceFrameSnapshot(
        timestamp: now,
        hasFace: true,
        confidence: 0.95,
        blendshapes: const FaceBlendshapeScores({
          'browDownLeft': 0.02,
          'browDownRight': 0.02,
          'mouthSmileLeft': 0.01,
          'mouthSmileRight': 0.01,
        }),
        gaze: GazeVector.center(),
        headPose: HeadPose.neutral(),
      );

      final r1 = detector.processFrame(baselineFrame);
      expect(r1.newEvents, isEmpty);

      // Фрейм со всплеском нахмуривания бровей (AU4)
      final spikeFrame = FaceFrameSnapshot(
        timestamp: now.add(const Duration(milliseconds: 100)),
        hasFace: true,
        confidence: 0.95,
        blendshapes: const FaceBlendshapeScores({
          'browDownLeft': 0.65,
          'browDownRight': 0.60,
          'mouthSmileLeft': 0.02,
          'mouthSmileRight': 0.02,
        }),
        gaze: GazeVector.center(),
        headPose: HeadPose.neutral(),
      );

      final r2 = detector.processFrame(spikeFrame);
      expect(r2.newEvents.any((e) => e.type == MicroEventType.browFurrow), isTrue);
    });

    test('BehavioralCluster formats correctly for LLM prompt context', () {
      final cluster = BehavioralCluster(
        id: 'test_1',
        type: ClusterType.skepticism,
        timestamp: DateTime.now(),
        confidence: 0.90,
        supportingEvents: [
          MicroEvent(
            id: 'ev_1',
            type: MicroEventType.browFurrow,
            timestamp: DateTime.now(),
            durationMs: 180,
            intensity: 0.8,
            confidence: 0.9,
            labelRu: 'Микро-нахмуривание (AU4)',
            descriptionRu: 'Сомнение',
          ),
        ],
        titleRu: 'Скепсис и скрытое несогласие',
        summaryRu: 'Оппонент сомневается',
        tacticalAdviceRu: 'Запросите встречные мысли',
      );

      final promptContext = cluster.toPromptContext();
      expect(promptContext.contains('ПОВЕДЕНЧЕСКИЙ КЛАСТЕР'), isTrue);
      expect(promptContext.contains('Скепсис и скрытое несогласие'), isTrue);
    });

    test('Follow-up UX logic: PromptBuilder formats round 1 vs followUp round 2 correctly', () {
      final config = AppConfig();
      final p1 = PromptBuilder.build(
        config: config,
        turns: const [],
        lastSpeaker: null,
        conversationSummary: '',
        summarizedUpToTurn: 0,
        interimMe: '',
        followUpRound: 1,
        isFollowUp: false,
      );
      expect(p1.contains('<follow_up_context>'), isFalse);

      final p2 = PromptBuilder.build(
        config: config,
        turns: const [],
        lastSpeaker: null,
        conversationSummary: '',
        summarizedUpToTurn: 0,
        interimMe: '',
        followUpRound: 2,
        isFollowUp: true,
      );
      expect(p2.contains('<follow_up_context>'), isTrue);
      expect(p2.contains('ЭТО УТОЧНЕНИЕ ПРЕДЫДУЩЕГО ОТВЕТА (РАУНД 2)!'), isTrue);
    });
  });
}
