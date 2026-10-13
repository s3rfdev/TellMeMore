import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/deepgram_stream.dart';
import '../services/llm_service.dart';
import '../session.dart';
import 'theme.dart';

class TranscriptPanel extends StatefulWidget {
  const TranscriptPanel({super.key, required this.session});

  final Session session;

  @override
  State<TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<TranscriptPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _autoScroll();
    final s = widget.session;
    return Column(
      children: [_header(s), Expanded(child: _list(s)), _footer(s)],
    );
  }

  Widget _header(Session s) {
    final hasContent = s.turns.isNotEmpty ||
        s.interimMe.trim().isNotEmpty ||
        s.interimThem.trim().isNotEmpty;
    final (dotColor, statusText) = switch (s.status) {
      SessionStatus.idle => (Palette.faint, S.t('statusIdle')),
      SessionStatus.connecting => (Palette.amber, S.t('statusConnecting')),
      SessionStatus.listening => (Palette.green, S.t('statusListening')),
      SessionStatus.error => (
        Palette.red,
        s.statusMessage ?? S.t('statusIdle'),
      ),
    };

    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.t('transcriptTitle'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Palette.sec,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Tooltip(
                    message: statusText,
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            s.status == SessionStatus.error
                                ? Palette.red
                                : Palette.sec,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasContent)
            Center(
              child: _micToggle(s, size: 26, iconSize: 14),
            ),
        ],
      ),
    );
  }

  /// Круглая кнопка микрофона: серая — неактивна, зелёная — пишет.
  Widget _micToggle(
    Session s, {
    required double size,
    required double iconSize,
  }) {
    final streaming = s.isStreaming;
    return Tooltip(
      message: streaming ? S.t('stopTooltip') : S.t('startTooltip'),
      child: InkWell(
        onTap: streaming ? s.stopStream : s.startStream,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                streaming
                    ? Palette.green.withValues(alpha: 0.15)
                    : Colors.transparent,
            border: Border.all(
              color: streaming ? Palette.green : const Color(0xFF3A4048),
              width: 1.4,
            ),
          ),
          child: Icon(
            streaming ? Icons.mic : Icons.mic_none,
            size: iconSize,
            color: streaming ? Palette.green : Palette.sec,
          ),
        ),
      ),
    );
  }

  Widget _list(Session s) {
    final hasInterim =
        s.interimMe.trim().isNotEmpty || s.interimThem.trim().isNotEmpty;
    if (s.turns.isEmpty && !hasInterim) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _micToggle(s, size: 64, iconSize: 26),
            const SizedBox(height: 14),
            Text(
              S.t('emptyTranscript'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Palette.sec,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[
      for (final t in s.turns) _turnRow(t.speaker, t.text, finalText: true),
      if (s.interimMe.trim().isNotEmpty)
        _turnRow(Speaker.me, s.interimMe.trim(), finalText: false),
      if (s.interimThem.trim().isNotEmpty)
        _turnRow(Speaker.them, s.interimThem.trim(), finalText: false),
    ];

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _turnRow(Speaker speaker, String text, {required bool finalText}) {
    final c = widget.session.config;
    final isMe = speaker == Speaker.me;
    final color = isMe ? Palette.green : Palette.them;
    final label = isMe ? S.t('you') : S.t('interviewer');
    final alpha = finalText ? 1.0 : 0.55;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              finalText ? label : '$label…',
              style: TextStyle(
                fontSize: c.fontSize - 2,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: alpha),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: c.fontSize,
                height: 1.45,
                fontStyle: finalText ? FontStyle.normal : FontStyle.italic,
                fontWeight: c.boldText ? FontWeight.w700 : FontWeight.w400,
                color: Color(c.hintColor).withValues(alpha: alpha),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(Session s) {
    final String themLabel;
    if (s.themActive) {
      themLabel = 'Собеседник: устройство';
    } else if (s.config.themDeviceId.isEmpty) {
      themLabel =
          s.isStreaming ? 'Собеседник: авто (по голосам)' : 'Собеседник: авто';
    } else {
      themLabel = 'Собеседник: выкл';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  s.themActive
                      ? Palette.them
                      : (s.themError != null ? Palette.red : Palette.faint),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            themLabel,
            style: TextStyle(
              fontSize: 11,
              color: s.themError != null ? Palette.red : Palette.faint,
            ),
          ),
          if (s.themError != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.themError!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Palette.red),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              'Deepgram · ${s.config.deepgramModel} · ${s.config.provider.shortLabel} · ${s.config.modelFor(s.config.provider)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Palette.faint),
            ),
          ),
        ],
      ),
    );
  }
}
