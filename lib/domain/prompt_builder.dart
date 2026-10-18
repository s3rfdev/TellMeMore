import '../services/config_store.dart';
import '../services/deepgram_stream.dart';
import 'transcript_turn.dart';

/// Чистый доменный построитель системных промптов для LLM.
/// Не зависит от UI, Flutter-виджетов и платформенных плагинов.
class PromptBuilder {
  PromptBuilder._();

  /// Формирует фрагмент XML с историей реплик с учетом лимитов и сжатия.
  static String buildTranscript({
    required AppConfig config,
    required List<TranscriptTurn> turns,
    String conversationSummary = '',
    int summarizedUpToTurn = 0,
    String interimMe = '',
  }) {
    final buf = StringBuffer();
    List<TranscriptTurn> recent;
    if (config.autoCompressContext && conversationSummary.trim().isNotEmpty) {
      final start = summarizedUpToTurn.clamp(0, turns.length);
      final remaining = turns.sublist(start);
      final limit = config.llmContextTurns.clamp(5, 100);
      recent = remaining.length > limit
          ? remaining.sublist(remaining.length - limit)
          : remaining;
    } else {
      final limit = config.llmContextTurns.clamp(5, 100);
      recent =
          turns.length > limit ? turns.sublist(turns.length - limit) : turns;
    }
    for (final t in recent) {
      final speakerTag = t.speaker == Speaker.me ? 'candidate' : 'interviewer';
      buf.writeln('  <turn speaker="$speakerTag">${t.text}</turn>');
    }
    final live = interimMe.trim();
    if (live.isNotEmpty) {
      buf.writeln(
        '  <turn speaker="candidate" status="speaking_now">$live</turn>',
      );
    }
    return buf.toString().trimRight();
  }

  /// Собирает полный контекстно-зависимый XML-промпт для суфлёра.
  static String build({
    required AppConfig config,
    required List<TranscriptTurn> turns,
    Speaker? lastSpeaker,
    String conversationSummary = '',
    int summarizedUpToTurn = 0,
    String interimMe = '',
    int followUpRound = 1,
    bool isFollowUp = false,
    bool withScreenshot = false,
    int screenshotCount = 0,
  }) {
    final situation = switch (lastSpeaker) {
      Speaker.me =>
        'Последнюю реплику говорил я. Помоги мне развить мысль, закончить формулировку или дополнить ответ сильными аргументами.',
      Speaker.them =>
        'Последним говорил оппонент (задал вопрос или сделал реплику). Подскажи мне точный, сильный и выигрышный ответ от моего лица.',
      null =>
        'Разговор только начинается. Помоги уверенно начать диалог.',
    };

    final my = config.myProfile.trim();
    final them = config.interviewerProfile.trim();
    final goals = config.goals.trim();
    final hasSummary =
        config.autoCompressContext && conversationSummary.trim().isNotEmpty;

    final languageInstruction = switch (config.answerLang) {
      'ru' => 'Отвечай строго на русском языке.',
      'en' => 'Answer strictly in English.',
      _ =>
        config.uiLang == 'en'
            ? 'Answer in the same language as the conversation (English if in English, Russian if in Russian).'
            : 'Отвечай на том же языке, на котором говорит собеседник в диалоге (если собеседник говорит по-русски — отвечай по-русски, если по-английски — по-английски).',
    };

    final transcriptXml = buildTranscript(
      config: config,
      turns: turns,
      conversationSummary: conversationSummary,
      summarizedUpToTurn: summarizedUpToTurn,
      interimMe: interimMe,
    );

    return '''
<system_role>
Ты — интеллектуальный ко-пилот и персональный суфлёр в реальном времени (для переговоров, собеседований и деловых встреч). Твоя задача — мгновенно вооружать пользователя чёткими, уверенными и профессиональными ответами прямо во время разговора.
</system_role>

<candidate_profile>
${my.isNotEmpty ? my : 'Профиль пользователя не указан (опирайся на контекст диалога).'}
</candidate_profile>

<interviewer_profile>
${them.isNotEmpty ? them : 'Профиль оппонента не указан.'}
</interviewer_profile>

<interview_goals>
${goals.isNotEmpty ? goals : 'Провести переговоры / собеседование успешно, отвечать уверенно, точно и структурированно.'}
</interview_goals>
${hasSummary ? '''

<conversation_summary>
${conversationSummary.trim()}
</conversation_summary>
''' : ''}
<live_transcript>
$transcriptXml
</live_transcript>

<current_situation>
$situation
</current_situation>
${isFollowUp ? '''

<follow_up_context>
ЭТО УТОЧНЕНИЕ ПРЕДЫДУЩЕГО ОТВЕТА (РАУНД $followUpRound)!
Кандидат и интервьюер продолжают обсуждать ту же задачу/код.
Внимательно сопоставь предыдущее обсуждение, свои предыдущие ответы и новые реплики из <live_transcript>.
Если интервьюер или кандидат просят исправить ошибку, оптимизировать сложность алгоритма (например, сделать за O(1) памяти), обработать краевые случаи или объяснить подробнее — дай чёткое исправленное решение/код с учётом всех требований.
</follow_up_context>
''' : ''}
${withScreenshot ? '''

<screen_context>
${screenshotCount > 1 ? '''К этому запросу прикреплено $screenshotCount скриншотов экрана кандидата (пролистанный код, условие задачи или несколько окон/файлов).
ЭТО ВОПРОС ТЕХНИЧЕСКОГО ХАРАКТЕРА! На изображениях находится условие задачи, код, архитектурная схема, ошибка или технический вопрос, который решает кандидат.
Все прикреплённые изображения относятся к одной задаче/контексту в хронологическом порядке просмотра. Сопоставь их вместе.''' : '''К этому запросу прикреплён актуальный скриншот экрана (IDE, окно терминала, веб-платформа с заданием, условие задачи или кодовая база).
ЭТО ВОПРОС ТЕХНИЧЕСКОГО ХАРАКТЕРА! На изображении находится условие задачи, код, архитектурная схема, ошибка или технический вопрос, который решает пользователь прямо сейчас.'''}
</screen_context>
''' : ''}
<instructions>
1. Отвечай от первого лица ("я"), моим голосом — так, чтобы я мог сразу вслух произнести твою подсказку.
2. Строго опирайся на навыки и опыт из <candidate_profile>, если он указан. Не противоречь опыту и не выдумывай несуществующие факты.
3. Учитывай цели из <interview_goals> и особенности оппонента из <interviewer_profile>.
${hasSummary ? '4. Опирайся на контекст из <conversation_summary> (сохранённое резюме предыдущей части собеседования) и актуальные реплики из <live_transcript>.\n' : ''}${withScreenshot ? '''
${screenshotCount > 1 ? '4. ВНИМАТЕЛЬНО ИЗУЧИ ВСЕ ПРИКРЕПЛЁННЫЕ СКРИНШОТЫ ЭКРАНА! Распознай код, сигнатуры функций, контекст IDE, условие задачи или ошибку, объединив информацию со всех кадров.' : '4. ВНИМАТЕЛЬНО ИЗУЧИ ПРИКРЕПЛЁННЫЙ СКРИНШОТ ЭКРАНА! Распознай код, сигнатуры функций, контекст IDE, условие задачи или ошибку.'}
5. Если кандидат решает задачу по программированию / алгоритмам / архитектуре / SQL — ДАЙ ГОТОВЫЙ РАБОЧИЙ КОД И ЧЁТКОЕ РЕШЕНИЕ с лаконичным объяснением (почему именно так).
6. Если на экране видна ошибка или упавший тест — объясни причину в одном предложении и дай готовый исправленный код / команду.
7. Кандидат может вслух произнести лишь короткую фразу (например: "вот у меня тут код" или "как это решить?"), поэтому всё необходимое для полного решения бери прямо со скриншота!
''' : '''
4. Формат подсказки: предельно ёмко, 1–3 предложения (или 2–3 коротких ключевых тезиса с готовой речевой фразой).
5. Никаких преамбул, мета-комментариев и вступлений (ЗАПРЕЩЕНО писать: "Вот что вам сказать:", "Вы можете ответить:"). Сразу давай готовую реплику / суть ответа!
'''}
8. $languageInstruction
</instructions>
'''.trim();
  }

  /// Формирует промпт для смысловой компрессии истории диалога.
  static String buildCompressionPrompt({
    required String previousSummary,
    required List<TranscriptTurn> slice,
  }) {
    final dialogueSliceBuf = StringBuffer();
    for (final t in slice) {
      final label = t.speaker == Speaker.me ? 'Кандидат' : 'Интервьюер';
      dialogueSliceBuf.writeln('[$label]: ${t.text}');
    }

    return '''
Ты — интеллектуальный ассистент, выполняющий смысловую компрессию (сжатие) истории живого технического/делового собеседования.
Твоя задача — составить или обновить связное, ёмкое резюме диалога, сохранив ключевую суть:
1. Темы, вопросы и задачи, озвученные интервьюером;
2. Навыки, опыт, архитектурные/технические решения, код и аргументы кандидата;
3. Замечания, требования и текущий статус обсуждения.

Формат резюме:
- Краткие маркированные пункты (тезисно, без «воды»);
- Сохраняй ключевые факты, стек, технологии, формулировки и цифры;
- Не искажай смысл и не добавляй вымышленных деталей;
- Язык резюме: тот же язык, на котором шёл диалог (русский или английский).

<previous_summary>
${previousSummary.trim().isNotEmpty ? previousSummary.trim() : 'Нет предыдущего резюме (это начало диалога)'}
</previous_summary>

<new_dialogue_turns_to_compress>
${dialogueSliceBuf.toString().trim()}
</new_dialogue_turns_to_compress>

Верни ТОЛЬКО обновлённое структурированное резюме диалога без вступительных слов и комментариев.
'''.trim();
  }
}
