// lib/domain/chat_serializer.dart
//
// Pure domain serialization and deserialization for interview transcripts.
// Supports both structured JSON (tellmemore_dialogue_v1) and plain text fallback.

import 'dart:convert';

import '../services/deepgram_stream.dart';
import 'transcript_turn.dart';

/// Parsed result of an imported chat transcript.
class ImportedChatResult {
  const ImportedChatResult({
    required this.turns,
    this.conversationSummary = '',
    this.summarizedUpToTurn = 0,
  });

  final List<TranscriptTurn> turns;
  final String conversationSummary;
  final int summarizedUpToTurn;
}

/// Serialization and parsing utilities for dialogue transcripts.
abstract final class ChatSerializer {
  /// Exports transcript turns and optional conversation summary to formatted JSON.
  static String exportJson({
    required List<TranscriptTurn> turns,
    String conversationSummary = '',
    int summarizedUpToTurn = 0,
  }) {
    final turnsJson = turns.map((t) => {
      'speaker': t.speaker == Speaker.me ? 'candidate' : 'interviewer',
      'speakerRole': t.speaker.name,
      'timestamp': t.timestamp.toIso8601String(),
      'text': t.text,
    }).toList();

    final plainTextBuffer = StringBuffer();
    for (final t in turns) {
      final h = t.timestamp.hour.toString().padLeft(2, '0');
      final m = t.timestamp.minute.toString().padLeft(2, '0');
      final s = t.timestamp.second.toString().padLeft(2, '0');
      final speakerLabel =
          t.speaker == Speaker.me ? 'Вы (Кандидат)' : 'Собеседник';
      plainTextBuffer.writeln('[$h:$m:$s] $speakerLabel: ${t.text}');
    }

    final exportData = {
      'format': 'tellmemore_dialogue_v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'TellMeMore',
      'turnsCount': turns.length,
      'conversationSummary': conversationSummary,
      'summarizedUpToTurn': summarizedUpToTurn,
      'plainTranscript': plainTextBuffer.toString(),
      'turns': turnsJson,
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Parses an imported chat file (JSON or raw text) with full metadata.
  static ImportedChatResult parseFull(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const ImportedChatResult(turns: []);
    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['turns'] is List) {
        final turns = (decoded['turns'] as List).map((e) {
          final m = e as Map<String, dynamic>;
          final s = (m['speaker'] == 'them' ||
                  m['speakerRole'] == 'them' ||
                  m['speaker'] == 'interviewer')
              ? Speaker.them
              : Speaker.me;
          final text = (m['text'] as String?) ?? '';
          final time = DateTime.tryParse((m['timestamp'] as String?) ?? '') ??
              DateTime.now();
          return TranscriptTurn(speaker: s, text: text, timestamp: time);
        }).where((t) => t.text.trim().isNotEmpty).toList();

        final summary = (decoded['conversationSummary'] as String?) ?? '';
        final upTo = (decoded['summarizedUpToTurn'] as num?)?.toInt() ?? 0;
        return ImportedChatResult(
          turns: turns,
          conversationSummary: summary,
          summarizedUpToTurn: upTo.clamp(0, turns.length),
        );
      } else if (decoded is List) {
        final turns = decoded
            .whereType<Map<String, dynamic>>()
            .map(TranscriptTurn.fromJson)
            .where((t) => t.text.trim().isNotEmpty)
            .toList();
        return ImportedChatResult(turns: turns);
      }
    } catch (_) {}

    // Fallback: line-by-line plain text parsing
    final lines = trimmed.split('\n');
    final result = <TranscriptTurn>[];
    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      var speaker = Speaker.them;
      var text = l;
      final matchMe = RegExp(
        r'(?:^|\]\s*|:\s*)\[?(?:вы(?:\s*\(кандидат\))?|candidate|me)\]?\s*:\s*(.*)',
        caseSensitive: false,
      ).firstMatch(l);
      final matchThem = RegExp(
        r'(?:^|\]\s*|:\s*)\[?(?:собеседник|interviewer|them|other)\]?\s*:\s*(.*)',
        caseSensitive: false,
      ).firstMatch(l);
      if (matchMe != null) {
        speaker = Speaker.me;
        text = matchMe.group(1)?.trim() ?? '';
      } else if (matchThem != null) {
        speaker = Speaker.them;
        text = matchThem.group(1)?.trim() ?? '';
      }
      if (text.isNotEmpty) {
        result.add(TranscriptTurn(speaker: speaker, text: text));
      }
    }
    return ImportedChatResult(turns: result);
  }

  /// Convenience helper returning only the list of turns.
  static List<TranscriptTurn> parse(String raw) => parseFull(raw).turns;
}
