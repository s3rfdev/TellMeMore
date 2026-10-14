import 'dart:convert';
import 'dart:io';

import '../session.dart';

/// Хранилище постоянной истории чата на диске (~/.tellmemore_history.json).
/// Гарантирует, что диалог сохраняется между перезапусками приложения
/// и стартами сессий.
class HistoryStore {
  static File get _file {
    final home = Platform.environment['HOME'] ?? '.';
    return File('$home/.tellmemore_history.json');
  }

  /// Загрузка сохранённого списка реплик
  static Future<List<TranscriptTurn>> load() async {
    try {
      if (!await _file.exists()) return [];
      final raw = await _file.readAsString();
      if (raw.trim().isEmpty) return [];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map && decoded['turns'] is List) {
        return (decoded['turns'] as List)
            .whereType<Map<String, dynamic>>()
            .map(TranscriptTurn.fromJson)
            .toList();
      } else if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(TranscriptTurn.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Сохранение истории на диск
  static Future<void> save(List<TranscriptTurn> turns) async {
    try {
      final jsonList = turns.map((t) => t.toJson()).toList();
      final data = {
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'turns': jsonList,
      };
      await _file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    } catch (_) {}
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
