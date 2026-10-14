import 'dart:convert';
import 'dart:io';

import '../session.dart';

class HistoryData {
  const HistoryData({
    required this.turns,
    this.conversationSummary = '',
    this.summarizedUpToTurn = 0,
  });

  final List<TranscriptTurn> turns;
  final String conversationSummary;
  final int summarizedUpToTurn;
}

/// Хранилище постоянной истории чата на диске (~/.tellmemore_history.json).
/// Гарантирует, что диалог сохраняется между перезапусками приложения
/// и стартами сессий.
class HistoryStore {
  static File get _file {
    final home = Platform.environment['HOME'] ?? '.';
    return File('$home/.tellmemore_history.json');
  }

  /// Загрузка структурированных данных истории (реплики + сводка компрессии)
  static Future<HistoryData> loadData() async {
    try {
      if (!await _file.exists()) return const HistoryData(turns: []);
      final raw = await _file.readAsString();
      if (raw.trim().isEmpty) return const HistoryData(turns: []);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        final turns = (decoded['turns'] is List)
            ? (decoded['turns'] as List)
                .whereType<Map<String, dynamic>>()
                .map(TranscriptTurn.fromJson)
                .toList()
            : <TranscriptTurn>[];
        final summary = (decoded['conversationSummary'] as String?) ?? '';
        final upTo = (decoded['summarizedUpToTurn'] as num?)?.toInt() ?? 0;
        return HistoryData(
          turns: turns,
          conversationSummary: summary,
          summarizedUpToTurn: upTo.clamp(0, turns.length),
        );
      } else if (decoded is List) {
        final turns = decoded
            .whereType<Map<String, dynamic>>()
            .map(TranscriptTurn.fromJson)
            .toList();
        return HistoryData(turns: turns);
      }
      return const HistoryData(turns: []);
    } catch (_) {
      return const HistoryData(turns: []);
    }
  }

  /// Загрузка сохранённого списка реплик
  static Future<List<TranscriptTurn>> load() async {
    final d = await loadData();
    return d.turns;
  }

  /// Сохранение структурированных данных истории на диск
  static Future<void> saveData({
    required List<TranscriptTurn> turns,
    String conversationSummary = '',
    int summarizedUpToTurn = 0,
  }) async {
    try {
      final jsonList = turns.map((t) => t.toJson()).toList();
      final data = {
        'version': 2,
        'updatedAt': DateTime.now().toIso8601String(),
        'conversationSummary': conversationSummary,
        'summarizedUpToTurn': summarizedUpToTurn.clamp(0, turns.length),
        'turns': jsonList,
      };
      await _file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    } catch (_) {}
  }

  /// Сохранение истории на диск (для обратной совместимости)
  static Future<void> save(List<TranscriptTurn> turns) async {
    await saveData(turns: turns);
  }

  /// Очистка истории с диска
  static Future<void> clear() async {
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } catch (_) {}
  }
}
