import 'package:flutter_test/flutter_test.dart';
import 'package:sobes123/services/config_store.dart';
import 'package:sobes123/services/deepgram_stream.dart';
import 'package:sobes123/session.dart';

void main() {
  group('AppConfig tests', () {
    test('Default values and clamping', () {
      final cfg = AppConfig();
      expect(cfg.turnSpacing, equals(5.0));
      expect(cfg.fontSize, equals(14.0));

      final json = cfg.toJson();
      expect(json['turnSpacing'], equals(5.0));

      // Test clamping in fromJson: turnSpacing (0..20), fontSize (6..24)
      final parsed = AppConfig.fromJson({
        'turnSpacing': 50.0,
        'fontSize': 2.0,
      });
      expect(parsed.turnSpacing, equals(20.0));
      expect(parsed.fontSize, equals(6.0));
    });

    test('clone preserves turnSpacing, hideFromScreenShare and alwaysOnTop', () {
      final cfg = AppConfig(
        turnSpacing: 12.0,
        hideFromScreenShare: true,
        alwaysOnTop: true,
      );
      final cloned = cfg.clone();
      expect(cloned.turnSpacing, equals(12.0));
      expect(cloned.hideFromScreenShare, isTrue);
      expect(cloned.alwaysOnTop, isTrue);

      final json = cloned.toJson();
      expect(json['hideFromScreenShare'], isTrue);
      expect(json['alwaysOnTop'], isTrue);

      final restored = AppConfig.fromJson(json);
      expect(restored.hideFromScreenShare, isTrue);
      expect(restored.alwaysOnTop, isTrue);
    });
  });

  group('Session XML prompt formatting tests', () {
    test('Prompt contains XML tags, candidate profile, interviewer profile and goals', () {
      final session = Session();
      session.config.myProfile = 'Senior Flutter Developer with 6 years experience';
      session.config.interviewerProfile = 'Tech Lead at FinTech';
      session.config.goals = 'Highlight architecture knowledge and state management';
      session.config.answerLang = 'ru';

      session.turns.add(TranscriptTurn(
        speaker: Speaker.them,
        text: 'How do you handle background state isolation?',
      ));

      final prompt = session.buildPrompt();

      expect(prompt, contains('<system_role>'));
      expect(prompt, contains('</system_role>'));
      expect(prompt, contains('<candidate_profile>'));
      expect(prompt, contains('Senior Flutter Developer with 6 years experience'));
      expect(prompt, contains('</candidate_profile>'));
      expect(prompt, contains('<interviewer_profile>'));
      expect(prompt, contains('Tech Lead at FinTech'));
      expect(prompt, contains('</interviewer_profile>'));
      expect(prompt, contains('<interview_goals>'));
      expect(prompt, contains('Highlight architecture knowledge and state management'));
      expect(prompt, contains('</interview_goals>'));
      expect(prompt, contains('<live_transcript>'));
      expect(prompt, contains('<turn speaker="interviewer">How do you handle background state isolation?</turn>'));
      expect(prompt, contains('</live_transcript>'));
      expect(prompt, contains('<current_situation>'));
      expect(prompt, contains('Последним говорил собеседник / интервьюер'));
      expect(prompt, contains('</current_situation>'));
      expect(prompt, contains('<instructions>'));
      expect(prompt, contains('Отвечай строго на русском языке.'));
      expect(prompt, contains('</instructions>'));
    });

    test('Prompt respects English answer language', () {
      final session = Session();
      session.config.answerLang = 'en';
      session.turns.add(TranscriptTurn(
        speaker: Speaker.me,
        text: 'I worked on high load streaming applications.',
      ));

      final prompt = session.buildPrompt();
      expect(prompt, contains('Answer strictly in English.'));
      expect(prompt, contains('<turn speaker="candidate">I worked on high load streaming applications.</turn>'));
      expect(prompt, contains('Последнюю реплику говорил я (кандидат)'));
    });
  });
}
