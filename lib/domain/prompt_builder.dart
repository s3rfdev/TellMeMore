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
      final speakerTag = t.speaker == Speaker.me ? 'user' : 'opponent';
      if (t.nonverbalTags.isNotEmpty) {
        final tagsStr = t.nonverbalTags.join('; ');
        buf.writeln('  <turn speaker="$speakerTag" nonverbal="$tagsStr">${t.text}</turn>');
      } else {
        buf.writeln('  <turn speaker="$speakerTag">${t.text}</turn>');
      }
    }
    final live = interimMe.trim();
    if (live.isNotEmpty) {
      buf.writeln(
        '  <turn speaker="user" status="speaking_now">$live</turn>',
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
    bool isFaceCrop = false,
    String nonverbalContext = '',
    bool includeDossier = false,
  }) {
    final situation = switch (lastSpeaker) {
      Speaker.me =>
        'Последнюю реплику произнёс я (пользователь). Помоги мне развить мысль, усилить аргументы или отреагировать на реакцию собеседника.',
      Speaker.them =>
        'Последним говорил оппонент/спикер. С учётом его слов и контекста подскажи мне точный, психологически выверенный и выигрышный ответ от моего лица.',
      null =>
        'Диалог или монолог в процессе. Дай тактическую оценку и подскажи наилучший ход для включения в разговор.',
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

    final systemRoleText = config.systemRole.trim().isNotEmpty
        ? config.systemRole.trim()
        : AppConfig.defaultSystemRole;

    final instructionsText = config.instructions.trim().isNotEmpty
        ? config.instructions.trim()
        : AppConfig.defaultInstructions;

    final videoPromptText = config.videoPrompt.trim().isNotEmpty
        ? config.videoPrompt.trim()
        : AppConfig.defaultVideoPrompt;

    final transcriptXml = buildTranscript(
      config: config,
      turns: turns,
      conversationSummary: conversationSummary,
      summarizedUpToTurn: summarizedUpToTurn,
      interimMe: interimMe,
    );

    return '''
<system_role>
$systemRoleText
</system_role>

<user_profile>
${my.isNotEmpty ? my : 'Пользователь (собеседник в диалоге/переговорах, опирайся на контекст разговора).'}
</user_profile>

<opponent_profile>
${them.isNotEmpty ? them : 'Собеседник/спикер, чью речь и реакции мы анализируем.'}
</opponent_profile>

<conversation_goals>
${goals.isNotEmpty ? goals : 'Вести продуктивный диалог, отстаивать сильную позицию, тонко считывать скрытые эмоции и сомнения оппонента и давать точные формулировки.'}
</conversation_goals>
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
Внимательно сопоставь предыдущее обсуждение, свои предыдущие ответы и новые реплики из <live_transcript>.
Сформулируй прямое развитие мысли или конкретное исправление с учётом обратной связи.
</follow_up_context>
''' : ''}
${isFaceCrop ? '''

<video_face_frame>
$videoPromptText
</video_face_frame>
''' : (withScreenshot ? '''

<screen_context>
${screenshotCount > 1 ? '''К этому запросу прикреплено $screenshotCount скриншотов экрана пользователя (код, условие задачи или схема).
Сопоставь их вместе для решения вопроса.''' : '''К этому запросу прикреплён актуальный скриншот экрана (IDE, окно программы или веб-страница).
Используй визуальные данные для точного решения.'''}
</screen_context>
''' : '')}
${nonverbalContext.trim().isNotEmpty ? '''

<nonverbal_observations>
$nonverbalContext
</nonverbal_observations>
''' : ''}
<instructions>
$instructionsText
${config.promptMode == 'bullets' ? (includeDossier ? '''• Структура вывода: Твой ответ ВСЕГДА должен состоять строго из двух блоков:
<dossier>
[Краткий психологический рентген оппонента (1–2 ёмких предложения): его скрытый стресс, скепсис, ложь, манипуляция или истинный настрой на основе мимики и последних слов. Особое внимание обращай на асимметрию улыбки (AU14 ухмылка / сарказм / фальшь), рассинхрон головы (покачивание «нет» при словесном согласии = ложное согласие / саботаж), сжатие губ (AU24) и глазное блокирование (>350ms).]
</dossier>
<speech>
🎯 [1 ключевая фраза от первого лица ("я"), чтобы сразу уверенно начать говорить]
⚡ Ключевые тезисы и стек:
• **[Ключевой термин / концепт]**: суть в 2–3 словах
• **[Стек / механизм / алгоритм]**: почему именно так
⚠️ **Подводный камень**: нюанс, узкое место или грабли темы
💡 **Итог**: короткий вердикт или рекомендация
</speech>''' : '''• Формат ответа: СТРОГО ТЕЗИСНАЯ ШПАРГАЛКА (CUE CARD) ДЛЯ ЖИВОЙ РЕЧИ! КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО писать монотонный сплошной текст для чтения под копирку (пользователь говорит сам живым языком).
Выдай структурированные когнитивные якоря с маркерами:
🎯 [1 ключевая фраза от первого лица ("я"), чтобы сразу уверенно начать говорить]
⚡ Ключевые тезисы и стек (3–4 пункта, самое главное выдели **жирным**):
• **[Ключевой термин / концепт]**: суть в 2–3 словах
• **[Стек / механизм / сложность]**: почему именно так
⚠️ **Подводный камень**: нюанс, узкое место или грабли темы
💡 **Итог**: короткий вердикт или рекомендация''') : (includeDossier ? '''• Структура вывода: Твой ответ ВСЕГДА должен состоять строго из двух блоков:
<dossier>
[Краткий психологический рентген оппонента (1–2 ёмких предложения): его скрытый стресс, скепсис, ложь, манипуляция или истинный настрой на основе мимики и последних слов. Особое внимание обращай на асимметрию улыбки (AU14 ухмылка / сарказм / фальшь), рассинхрон головы (покачивание «нет» при словесном согласии = ложное согласие / саботаж), сжатие губ (AU24) и глазное блокирование (>350ms).]
</dossier>
<speech>
[Готовая, психологически выверенная фраза от первого лица ("я"), которую пользователь сразу произносит вслух]
</speech>''' : '''• Формат ответа: Дай готовую, ёмкую и психологически выверенную фразу от первого лица ("я"), которую пользователь сразу произносит вслух (без вступительных слов, преамбул и служебных тегов).''')}
• Язык ответа: $languageInstruction
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
      final label = t.speaker == Speaker.me ? 'Пользователь' : 'Оппонент';
      final nv = t.nonverbalTags.isNotEmpty
          ? ' [Невербалика: ${t.nonverbalTags.join("; ")}]'
          : '';
      dialogueSliceBuf.writeln('[$label]$nv: ${t.text}');
    }

    return '''
Ты — интеллектуальный ассистент, выполняющий смысловую компрессию (сжатие) истории живого диалога / переговоров / собеседования.
Твоя задача — составить или обновить связное, ёмкое резюме диалога, сохранив ключевую суть:
1. Темы, вопросы, аргументы и позиция оппонента;
2. Эмоциональные реакции и невербальные сигналы оппонента (где возникал скрытый стресс, скепсис, уклонение от ответа, ложь или несогласие);
3. Аргументы, ответы и ключевые тезисы пользователя;
4. Текущий статус договоренностей и открытые вопросы.

Формат резюме:
- Краткие маркированные пункты (тезисно, без «воды»);
- Сохраняй ключевые факты, формулировки, психологические маркеры и цифры;
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
