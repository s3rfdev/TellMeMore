import '../services/deepgram_stream.dart';

/// Модель реплики диалога в транскрипте.
class TranscriptTurn {
  TranscriptTurn({
    required this.speaker,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final Speaker speaker;
  final String text;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'speaker': speaker.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranscriptTurn.fromJson(Map<String, dynamic> json) {
    final s = json['speaker'];
    final speaker =
        (s == 'them' || s == 'interviewer') ? Speaker.them : Speaker.me;
    final text = (json['text'] as String?) ?? '';
    final timeStr = (json['timestamp'] as String?) ?? '';
    final timestamp = DateTime.tryParse(timeStr) ?? DateTime.now();
    return TranscriptTurn(speaker: speaker, text: text, timestamp: timestamp);
  }
}
