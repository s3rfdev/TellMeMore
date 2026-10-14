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

    test('llmContextTurns default, clamping and serialization', () {
      final cfg = AppConfig();
      expect(cfg.llmContextTurns, equals(30));

      final json = cfg.toJson();
      expect(json['llmContextTurns'], equals(30));

      final parsed = AppConfig.fromJson({
        'llmContextTurns': 150,
      });
      expect(parsed.llmContextTurns, equals(100));

      final parsedLow = AppConfig.fromJson({
        'llmContextTurns': 1,
      });
      expect(parsedLow.llmContextTurns, equals(5));

      final cloned = cfg.clone();
      cloned.llmContextTurns = 45;
      expect(cloned.llmContextTurns, equals(45));
      expect(cfg.llmContextTurns, equals(30));
    });

    test('clone preserves turnSpacing, hideFromScreenShare and alwaysOnTop', () {
      final cfg = AppConfig(
        turnSpacing: 12.0,
        llmContextTurns: 50,
        hideFromScreenShare: true,
        alwaysOnTop: true,
      );
      final cloned = cfg.clone();
      expect(cloned.turnSpacing, equals(12.0));
      expect(cloned.llmContextTurns, equals(50));
      expect(cloned.hideFromScreenShare, isTrue);
      expect(cloned.alwaysOnTop, isTrue);

      final json = cloned.toJson();
      expect(json['llmContextTurns'], equals(50));
      expect(json['hideFromScreenShare'], isTrue);
      expect(json['alwaysOnTop'], isTrue);

      final restored = AppConfig.fromJson(json);
      expect(restored.llmContextTurns, equals(50));
      expect(restored.hideFromScreenShare, isTrue);
      expect(restored.alwaysOnTop, isTrue);
    });
  });

  group('Session turn chronology and truncation tests', () {
    test('onTurnEvent preserves strict chronological order based on timestamp', () {
      final session = Session();
      final t0 = DateTime(2026, 10, 14, 12, 0, 0);
      final t1 = DateTime(2026, 10, 14, 12, 0, 5);
      final t2 = DateTime(2026, 10, 14, 12, 0, 10);

      // Event 1 arrives first
      session.onTurnEvent(DeepgramTurnEvent(
        source: Speaker.them,
        phase: TurnPhase.end,
        turnIndex: 0,
        transcript: 'First question',
        timestamp: t0,
      ));

      // Event 3 arrives second (e.g. quick candidate response)
      session.onTurnEvent(DeepgramTurnEvent(
        source: Speaker.me,
        phase: TurnPhase.end,
        turnIndex: 0,
        transcript: 'My second response',
        timestamp: t2,
      ));

      // Event 2 arrives third with timestamp t1 (between t0 and t2)
      session.onTurnEvent(DeepgramTurnEvent(
        source: Speaker.them,
        phase: TurnPhase.end,
        turnIndex: 0,
        transcript: 'Follow up question',
        timestamp: t1,
      ));

      expect(session.turns.length, equals(3));
      expect(session.turns[0].text, equals('First question'));
      expect(session.turns[1].text, equals('Follow up question'));
      expect(session.turns[2].text, equals('My second response'));
    });

    test('Chat history truncates oldest turns when exceeding maxTranscriptTurns (200)', () {
      final session = Session();
      final base = DateTime(2026, 10, 14, 10, 0, 0);

      for (var i = 0; i < 210; i++) {
        session.onTurnEvent(DeepgramTurnEvent(
          source: i.isEven ? Speaker.them : Speaker.me,
          phase: TurnPhase.end,
          turnIndex: 0,
          transcript: 'Message #$i',
          timestamp: base.add(Duration(seconds: i)),
        ));
      }

      expect(session.turns.length, equals(Session.maxTranscriptTurns));
      expect(session.turns.first.text, equals('Message #10'));
      expect(session.turns.last.text, equals('Message #209'));
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

    test('Prompt limits turns to llmContextTurns while preserving profiles and goals', () {
      final session = Session();
      session.config.myProfile = 'Profile 123';
      session.config.interviewerProfile = 'Interviewer 456';
      session.config.goals = 'Goal 789';
      session.config.llmContextTurns = 5;

      for (var i = 0; i < 20; i++) {
        session.turns.add(TranscriptTurn(
          speaker: i.isEven ? Speaker.them : Speaker.me,
          text: 'Turn $i',
        ));
      }

      final prompt = session.buildPrompt();

      // Profiles are fully preserved
      expect(prompt, contains('Profile 123'));
      expect(prompt, contains('Interviewer 456'));
      expect(prompt, contains('Goal 789'));

      // Only the last 5 turns (Turn 15..19) are present
      expect(prompt, contains('Turn 15'));
      expect(prompt, contains('Turn 19'));
      expect(prompt, isNot(contains('Turn 14')));
      expect(prompt, isNot(contains('Turn 0')));
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

    test('Prompt includes screen_context and technical code instructions when withScreenshot is true', () {
      final session = Session();
      session.config.myProfile = 'Fullstack Engineer';
      session.turns.add(TranscriptTurn(
        speaker: Speaker.them,
        text: 'Can you solve this algorithm on the screen?',
      ));

      final prompt = session.buildPrompt(withScreenshot: true);
      expect(prompt, contains('<screen_context>'));
      expect(prompt, contains('ЭТО ВОПРОС ТЕХНИЧЕСКОГО ХАРАКТЕРА!'));
      expect(prompt, contains('ВНИМАТЕЛЬНО ИЗУЧИ ПРИКРЕПЛЁННЫЙ СКРИНШОТ ЭКРАНА!'));
      expect(prompt, contains('ДАЙ ГОТОВЫЙ РАБОЧИЙ КОД И ЧЁТКОЕ РЕШЕНИЕ'));
    });

    test('TranscriptTurn serialization toJson and fromJson roundtrip', () {
      final now = DateTime.now();
      final turn = TranscriptTurn(
        speaker: Speaker.them,
        text: 'Hello from interviewer',
        timestamp: now,
      );

      final json = turn.toJson();
      expect(json['speaker'], 'them');
      expect(json['text'], 'Hello from interviewer');
      expect(json['timestamp'], now.toIso8601String());

      final restored = TranscriptTurn.fromJson(json);
      expect(restored.speaker, Speaker.them);
      expect(restored.text, 'Hello from interviewer');
      expect(restored.timestamp.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('Chat export and import roundtrip preserves dialogue and ordering', () {
      final session = Session();
      session.turns.addAll([
        TranscriptTurn(speaker: Speaker.them, text: 'Question 1', timestamp: DateTime(2026, 1, 1, 10, 0, 0)),
        TranscriptTurn(speaker: Speaker.me, text: 'Answer 1', timestamp: DateTime(2026, 1, 1, 10, 0, 30)),
      ]);

      final exportedJson = session.exportChatJson();
      expect(exportedJson, contains('tellmemore_dialogue_v1'));
      expect(exportedJson, contains('Question 1'));
      expect(exportedJson, contains('Answer 1'));

      final parsedTurns = Session.parseImportedChat(exportedJson);
      expect(parsedTurns.length, 2);
      expect(parsedTurns[0].speaker, Speaker.them);
      expect(parsedTurns[0].text, 'Question 1');
      expect(parsedTurns[1].speaker, Speaker.me);
      expect(parsedTurns[1].text, 'Answer 1');

      final session2 = Session();
      session2.importChat(parsedTurns);
      expect(session2.turns.length, 2);
      expect(session2.turns[0].text, 'Question 1');

      session2.clearChat();
      expect(session2.turns, isEmpty);
    });

    test('Chat import falls back to plain text transcript', () {
      final plainText = '''
[10:00:00] [Interviewer]: Tell me about yourself.
[10:00:30] [Candidate]: I am a Flutter engineer.
[10:01:00] [Other]: Sounds good.
''';

      final parsed = Session.parseImportedChat(plainText);
      expect(parsed.length, 3);
      expect(parsed[0].speaker, Speaker.them);
      expect(parsed[0].text, 'Tell me about yourself.');
      expect(parsed[1].speaker, Speaker.me);
      expect(parsed[1].text, 'I am a Flutter engineer.');
      expect(parsed[2].speaker, Speaker.them);
      expect(parsed[2].text, 'Sounds good.');
    });
  });
}

