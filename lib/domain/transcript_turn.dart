import '../services/deepgram_stream.dart';

/// Модель реплики диалога в транскрипте.
class TranscriptTurn {
  TranscriptTurn({
    required this.speaker,
    required this.text,
    DateTime? timestamp,
    List<String>? nonverbalTags,
  })  : timestamp = timestamp ?? DateTime.now(),
        nonverbalTags = nonverbalTags ?? const [];

  final Speaker speaker;
  final String text;
  final DateTime timestamp;
  final List<String> nonverbalTags;

  Map<String, dynamic> toJson() => {
    'speaker': speaker.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'nonverbalTags': nonverbalTags,
  };

  factory TranscriptTurn.fromJson(Map<String, dynamic> json) {
    final s = json['speaker'];
    final speaker =
        (s == 'them' || s == 'interviewer') ? Speaker.them : Speaker.me;
    final text = (json['text'] as String?) ?? '';
    final timeStr = (json['timestamp'] as String?) ?? '';
    final timestamp = DateTime.tryParse(timeStr) ?? DateTime.now();
    final rawTags = json['nonverbalTags'] as List<dynamic>?;
    final tags = rawTags?.map((e) => e.toString()).toList() ?? const [];
    return TranscriptTurn(
      speaker: speaker,
      text: text,
      timestamp: timestamp,
      nonverbalTags: tags,
    );
  }
}
