// lib/ui/settings/llm_tab_mixin.dart
//
// "LLM" tab: provider selector, API key, model picker, Deepgram token,
// audio device dropdowns, context turns slider, auto-compress section.
// Mixed into _SettingsDialogState.

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../l10n.dart';
import '../../services/audio_controller.dart';
import '../../services/llm_service.dart';
import '../../session.dart';
import '../theme.dart';
import 'shared_widgets_mixin.dart';

/// Builds the second settings tab (LLM configuration).
mixin LlmTabMixin on SharedWidgetsMixin {
  Session get session;
  TextEditingController get keyCtrl;
  TextEditingController get deepgramCtrl;
  TextEditingController get customModelCtrl;
  bool get obscureKey;
  bool get obscureDeepgram;
  bool get addingCustom;
  bool get checking;
  List<InputDevice> get themDevices;

  void onSwitchProvider(LlmProvider p);
  void onAddCustomModel();
  void onDeleteCustomModel();
  void onToggleObscureKey();
  void onToggleObscureDeepgram();
  void onSetAddingCustom(bool v);
  void onSetChecking(bool v);

  // ── Tab root ───────────────────────────────────────────────────────────────

  Widget buildLlmTab() {
    final p = c.provider;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _providerDropdownRow(),
          const SizedBox(height: 12),
          _keyFieldWithCheck(p),
          const SizedBox(height: 12),
          _modelRow(p),
          if (addingCustom) ...[const SizedBox(height: 8), _customModelRow()],
          const SizedBox(height: 14),
          _contextTurnsRow(),
          const SizedBox(height: 14),
          _autoCompressSection(),
          const SizedBox(height: 14),
          sectionHeader(S.t('sectionAudio')),
          _deepgramField(),
          const SizedBox(height: 12),
          _mySourceRow(),
          const SizedBox(height: 12),
          _themSourceRow(),
        ],
      ),
    );
  }

  // ── Provider dropdown ──────────────────────────────────────────────────────

  Widget _providerDropdownRow() {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(S.t('provider'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<LlmProvider>(
            value: c.provider,
            isExpanded: true,
            isDense: true,
            alignment: AlignmentDirectional.centerEnd,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF22262C),
            borderRadius: BorderRadius.circular(10),
            style: const TextStyle(fontSize: 13, color: Palette.pri),
            items: [
              for (final p in LlmProvider.values)
                DropdownMenuItem(
                  value: p,
                  child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (p) {
              if (p != null) onSwitchProvider(p);
            },
          ),
        ),
      ],
    );
  }

  // ── API Key field ──────────────────────────────────────────────────────────

  String _providerKeyLabel(LlmProvider p) => switch (p) {
    LlmProvider.gemini => S.t('geminiKey'),
    LlmProvider.zai => S.t('zaiKey'),
    LlmProvider.openai => S.t('openaiKey'),
    LlmProvider.anthropic => S.t('anthropicKey'),
  };

  Widget _keyFieldWithCheck(LlmProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _providerKeyLabel(p),
              style: const TextStyle(fontSize: 12, color: Palette.sec),
            ),
            const Spacer(),
            SizedBox(
              height: 22,
              child: checking ? _checkingBadge() : _checkButton(),
            ),
          ],
        ),
        const SizedBox(height: 5),
        settingsInput(
          keyCtrl,
          obscure: obscureKey,
          suffixIcon: eyeButton(
            obscured: obscureKey,
            onToggle: onToggleObscureKey,
            showLabel: S.t('showKey'),
            hideLabel: S.t('hideKey'),
          ),
        ),
      ],
    );
  }

  Widget _checkingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Palette.green.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Palette.green),
          ),
          const SizedBox(width: 6),
          Text(
            S.t('checkRunning'),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Palette.green),
          ),
        ],
      ),
    );
  }

  Widget _checkButton() {
    return Tooltip(
      message: S.t('checkModel'),
      child: InkWell(
        onTap: _checkModel,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Palette.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Palette.green.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 13, color: Palette.green),
              const SizedBox(width: 4),
              Text(
                S.t('checkAction'),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Palette.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkModel() async {
    if (checking) return;
    onSetChecking(true);
    String? error;
    try {
      final reply = await LlmService.ask(
        provider: c.provider,
        apiKey: keyCtrl.text.trim(),
        model: c.modelFor(c.provider),
        prompt: 'Ответь ровно одним словом: OK',
      );
      if (reply.trim().isEmpty) error = 'Пустой ответ';
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    onSetChecking(false);
    _showCheckResult(error);
  }

  void _showCheckResult(String? error) {
    final isSuccess = error == null;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Palette.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSuccess
                ? Palette.green.withValues(alpha: 0.4)
                : Palette.red.withValues(alpha: 0.4),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isSuccess ? Palette.green : Palette.red).withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                        size: 16,
                        color: isSuccess ? Palette.green : Palette.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSuccess ? S.t('checkSuccessTitle') : S.t('checkErrorTitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Palette.pri,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16, color: Palette.sec),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isSuccess ? Palette.green : Palette.red).withValues(alpha: 0.2),
                    ),
                  ),
                  child: SelectableText(
                    error ?? S.t('checkSuccessDesc'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: isSuccess ? Palette.pri : const Color(0xFFFF8A80),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: GradientButton(
                    icon: Icons.check_rounded,
                    label: S.t('closeDialog'),
                    height: 30,
                    fontSize: 12,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Model row ──────────────────────────────────────────────────────────────

  Widget _modelRow(LlmProvider p) {
    final models = c.modelsFor(p);
    final current = c.modelFor(p);
    const sentinel = '__custom__';
    final items = <DropdownMenuItem<String>>[
      for (final m in models)
        DropdownMenuItem(
          value: m,
          child: Text(m, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
      if (!models.contains(current))
        DropdownMenuItem(
          value: current,
          child: Text(current, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
      DropdownMenuItem(
        value: sentinel,
        child: Text(
          S.t('customModel'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Palette.green),
        ),
      ),
    ];

    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(S.t('model'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
        ),
        const SizedBox(width: 8),
        if (c.isCustomModel(p, current) && !addingCustom)
          Tooltip(
            message: S.t('deleteModel'),
            child: InkWell(
              onTap: onDeleteCustomModel,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 15, color: Palette.faint),
              ),
            ),
          ),
        Expanded(
          child: DropdownButton<String>(
            value: addingCustom ? sentinel : current,
            isExpanded: true,
            isDense: true,
            alignment: AlignmentDirectional.centerEnd,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF22262C),
            borderRadius: BorderRadius.circular(10),
            style: const TextStyle(fontSize: 13, color: Palette.pri),
            items: items,
            onChanged: (v) {
              if (v == null) return;
              if (v == sentinel) {
                onSetAddingCustom(true);
              } else {
                c.setModelFor(p, v);
                onTouch();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _customModelRow() {
    return Row(
      children: [
        Expanded(
          child: settingsInput(customModelCtrl, hint: S.t('modelIdHint'), autofocus: true),
        ),
        const SizedBox(width: 8),
        GradientButton(
          icon: Icons.add,
          label: S.t('addModel'),
          height: 30,
          fontSize: 12,
          onTap: onAddCustomModel,
        ),
      ],
    );
  }

  // ── Context turns slider ───────────────────────────────────────────────────

  Widget _contextTurnsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.t('llmContextTurns'),
                style: const TextStyle(fontSize: 12, color: Palette.sec),
              ),
            ),
            Text(
              '${c.llmContextTurns}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.pri),
            ),
          ],
        ),
        SliderTheme(
          data: sliderTheme(context),
          child: Slider(
            value: c.llmContextTurns.toDouble().clamp(4, 50),
            min: 4,
            max: 50,
            divisions: 23,
            onChanged: (v) {
              c.llmContextTurns = v.round();
              c.compressKeepRecentTurns = c.llmContextTurns;
              onTouch();
            },
          ),
        ),
        Text(S.t('llmContextTurnsHint'), style: const TextStyle(fontSize: 11, color: Palette.sec)),
      ],
    );
  }

  // ── Auto-compress section ──────────────────────────────────────────────────

  Widget _autoCompressSection() {
    final s = session;
    final hasSummary = s.conversationSummary.trim().isNotEmpty;
    final unsummarized = s.unsummarizedChars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switchRow(
          S.t('autoCompressContext'),
          c.autoCompressContext,
          (v) {
            c.autoCompressContext = v;
            onTouch();
          },
          subtitle: S.t('autoCompressContextSub'),
        ),
        if (c.autoCompressContext) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  S.t('compressThreshold', '${c.compressThresholdChars}'),
                  style: const TextStyle(fontSize: 12, color: Palette.sec),
                ),
              ),
              Text(
                '${c.compressThresholdChars}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.pri),
              ),
            ],
          ),
          SliderTheme(
            data: sliderTheme(context),
            child: Slider(
              value: c.compressThresholdChars.toDouble().clamp(1000, 15000),
              min: 1000,
              max: 15000,
              divisions: 28,
              onChanged: (v) {
                c.compressThresholdChars = (v / 500).round() * 500;
                onTouch();
              },
            ),
          ),
          Text(
            S.t('compressThresholdHint'),
            style: const TextStyle(fontSize: 10, color: Palette.sec),
          ),
          const SizedBox(height: 10),
          _compressStatusCard(s, hasSummary, unsummarized),
        ],
      ],
    );
  }

  Widget _compressStatusCard(Session s, bool hasSummary, int unsummarized) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSummary ? Icons.auto_awesome : Icons.info_outline,
                size: 13,
                color: hasSummary ? Palette.green : Palette.sec,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasSummary
                      ? S.t('activeSummary', '${s.conversationSummary.length}')
                      : S.t('noSummaryYet'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasSummary ? FontWeight.w600 : FontWeight.normal,
                    color: hasSummary ? Palette.pri : Palette.sec,
                  ),
                ),
              ),
              if (s.isCompressing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Palette.pri),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            S.t('unsummarizedVolume', '$unsummarized').replaceFirst('{1}', '${c.compressThresholdChars}'),
            style: const TextStyle(fontSize: 10, color: Palette.sec),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: BorderSide(color: Palette.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: s.isCompressing
                    ? null
                    : () async {
                        await s.compressHistoryNow(force: true);
                        if (context.mounted) setState(() {});
                      },
                child: Text(
                  s.isCompressing ? S.t('compressing') : S.t('compressNow'),
                  style: const TextStyle(fontSize: 11, color: Palette.pri),
                ),
              ),
              if (hasSummary) ...[
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    s.resetSummary();
                    setState(() {});
                  },
                  child: Text(
                    S.t('resetSummary'),
                    style: const TextStyle(fontSize: 11, color: Palette.red),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Deepgram token ─────────────────────────────────────────────────────────

  Widget _deepgramField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.t('deepgramToken'), style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(height: 5),
        settingsInput(
          deepgramCtrl,
          obscure: obscureDeepgram,
          suffixIcon: eyeButton(
            obscured: obscureDeepgram,
            onToggle: onToggleObscureDeepgram,
            showLabel: S.t('showKey'),
            hideLabel: S.t('hideKey'),
          ),
        ),
      ],
    );
  }

  // ── Audio device dropdowns ─────────────────────────────────────────────────

  Widget _mySourceRow() {
    final myDevices = themDevices
        .where((d) =>
            !d.label.toLowerCase().contains('blackhole') &&
            d.id != kRemoteMacDeviceId)
        .toList();
    final rawItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(
          S.t('deviceDefault'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      for (final d in myDevices)
        DropdownMenuItem(
          value: d.id,
          child: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
      if (c.myDeviceId.isNotEmpty && !myDevices.any((d) => d.id == c.myDeviceId))
        DropdownMenuItem(
          value: c.myDeviceId,
          child: Text(
            '${c.myDeviceId} — нет в системе',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Palette.sec),
          ),
        ),
    ];

    return _deviceDropdownRow(S.t('mySource'), rawItems, c.myDeviceId, (v) {
      c.myDeviceId = v ?? '';
      onTouch();
    });
  }

  Widget _themSourceRow() {
    final availableThem = themDevices
        .where((d) => d.id != kRemoteMacMicDeviceId)
        .toList();
    final rawItems = <DropdownMenuItem<String>>[
      for (final d in availableThem)
        DropdownMenuItem(
          value: d.id,
          child: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
      DropdownMenuItem(
        value: '',
        child: Text(
          S.t('deviceNone'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Palette.sec),
        ),
      ),
      if (c.themDeviceId.isNotEmpty && !availableThem.any((d) => d.id == c.themDeviceId))
        DropdownMenuItem(
          value: c.themDeviceId,
          child: Text(
            '${c.themDeviceId} — нет в системе',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Palette.sec),
          ),
        ),
    ];

    return _deviceDropdownRow(S.t('themSource'), rawItems, c.themDeviceId, (v) {
      if (v == null) return;
      c.themDeviceId = v;
      onTouch();
    });
  }

  Widget _deviceDropdownRow(
    String label,
    List<DropdownMenuItem<String>> rawItems,
    String selectedId,
    ValueChanged<String?> onChanged,
  ) {
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    for (final item in rawItems) {
      final val = item.value ?? '';
      if (seen.add(val)) items.add(item);
    }
    final selectedVal = seen.contains(selectedId) ? selectedId : '';

    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Palette.sec)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
            value: selectedVal,
            isExpanded: true,
            isDense: true,
            alignment: AlignmentDirectional.centerEnd,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF22262C),
            borderRadius: BorderRadius.circular(10),
            style: const TextStyle(fontSize: 13, color: Palette.pri),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
