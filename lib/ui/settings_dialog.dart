import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/config_store.dart';
import '../services/llm_service.dart';
import '../session.dart';
import 'theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.session});

  final Session session;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  /// Снимок на момент открытия — «Отмена» откатывает всё.
  late final AppConfig _orig = widget.session.config.clone();

  late final TextEditingController _deepgram =
      TextEditingController(text: widget.session.config.deepgramToken);
  late final TextEditingController _key = TextEditingController(
      text: widget.session.config.keyFor(widget.session.config.provider));
  final TextEditingController _customModel = TextEditingController();
  late final TextEditingController _myProfile =
      TextEditingController(text: widget.session.config.myProfile);
  late final TextEditingController _interviewerProfile =
      TextEditingController(text: widget.session.config.interviewerProfile);
  late final TextEditingController _goals =
      TextEditingController(text: widget.session.config.goals);

  bool _addingCustom = false;

  AppConfig get c => widget.session.config;

  void _touch() {
    widget.session.changed();
    setState(() {});
  }

  void _switchProvider(LlmProvider p) {
    if (p == c.provider) return;
    c.provider = p;
    _key.text = c.keyFor(p);
    _addingCustom = false;
    _touch();
  }

  void _addCustomModel() {
    final id = _customModel.text.trim();
    if (id.isEmpty) return;
    c.addCustomModel(c.provider, id);
    c.setModelFor(c.provider, id);
    _customModel.clear();
    _addingCustom = false;
    _touch();
  }

  void _deleteCustomModel() {
    final m = c.modelFor(c.provider);
    c.removeCustomModel(c.provider, m);
    c.setModelFor(c.provider, c.modelsFor(c.provider).first);
    _touch();
  }

  Future<void> _loadFromFile(TextEditingController controller) async {
    const groups = [XTypeGroup(label: 'Text', extensions: ['txt', 'md'])];
    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) return;
    try {
      final text = await file.readAsString();
      setState(() => controller.text = text.trim());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(S.t('loadFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      title: Text(S.t('settingsTitle'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 480,
        height: math.min(520, MediaQuery.sizeOf(context).height * 0.74),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                indicatorColor: Palette.green,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Palette.border,
                labelColor: Palette.pri,
                unselectedLabelColor: Palette.sec,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                    height: 36,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_outline, size: 14),
                      const SizedBox(width: 6),
                      Text(S.t('tabContext')),
                    ]),
                  ),
                  const Tab(
                    height: 36,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.memory, size: 14),
                      SizedBox(width: 6),
                      Text('LLM'),
                    ]),
                  ),
                  Tab(
                    height: 36,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.palette_outlined, size: 14),
                      const SizedBox(width: 6),
                      Text(S.t('tabUi')),
                    ]),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _contextTab(),
                    _llmTab(),
                    _uiTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.session.applyConfig(_orig);
            Navigator.of(context).pop();
          },
          child: Text(S.t('cancel')),
        ),
        GradientButton(
          icon: Icons.check_rounded,
          label: S.t('save'),
          height: 34,
          fontSize: 12,
          onTap: () async {
            c.deepgramToken = _deepgram.text.trim();
            c.setKeyFor(c.provider, _key.text.trim());
            c.myProfile = _myProfile.text.trim();
            c.interviewerProfile = _interviewerProfile.text.trim();
            c.goals = _goals.text.trim();
            await widget.session.saveConfig();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // ---------- Вкладка «Контекст»: текстовые блоки ----------

  Widget _contextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldWithLoad(_myProfile, S.t('myProfile'),
              hint: S.t('myProfileHint')),
          const SizedBox(height: 12),
          _fieldWithLoad(_interviewerProfile, S.t('interviewerProfile'),
              hint: S.t('interviewerHint')),
          const SizedBox(height: 12),
          _field(_goals, S.t('goals'), minLines: 4, maxLines: 8),
        ],
      ),
    );
  }

  // ---------- Вкладка «LLM»: провайдер, ключ, модель, аудио ----------

  Widget _llmTab() {
    final p = c.provider;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dropdownRow(),
          const SizedBox(height: 12),
          _field(_key, _providerKeyLabel(p), obscure: true),
          const SizedBox(height: 12),
          _modelRow(p),
          if (_addingCustom) ...[
            const SizedBox(height: 8),
            _customModelRow(),
          ],
          const SizedBox(height: 14),
          _section(S.t('sectionAudio')),
          _field(_deepgram, S.t('deepgramToken'), obscure: true),
        ],
      ),
    );
  }

  // ---------- Вкладка «UI»: прозрачность, шрифты, цвета ----------

  Widget _uiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _opacityRow(),
          const SizedBox(height: 4),
          _switchRow(S.t('titlebarTransparent'), c.titlebarTransparent,
              (v) {
            c.titlebarTransparent = v;
            widget.session.applyTitlebar();
            _touch();
          }),
          const SizedBox(height: 10),
          _section(S.t('sectionText')),
          _fontSizeRow(),
          _switchRow(S.t('boldText'), c.boldText, (v) {
            c.boldText = v;
            _touch();
          }),
          const SizedBox(height: 6),
          _colorSwatchesRow(),
        ],
      ),
    );
  }

  String _providerKeyLabel(LlmProvider p) => switch (p) {
        LlmProvider.gemini => S.t('geminiKey'),
        LlmProvider.zai => S.t('zaiKey'),
        LlmProvider.openai => S.t('openaiKey'),
        LlmProvider.anthropic => S.t('anthropicKey'),
      };

  Widget _dropdownRow() {
    return Row(
      children: [
        Text(S.t('provider'),
            style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const Spacer(),
        DropdownButton<LlmProvider>(
          value: c.provider,
          underline: const SizedBox.shrink(),
          dropdownColor: const Color(0xFF22262C),
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(fontSize: 13, color: Palette.pri),
          items: [
            for (final p in LlmProvider.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (p) {
            if (p != null) _switchProvider(p);
          },
        ),
      ],
    );
  }

  Widget _modelRow(LlmProvider p) {
    final models = c.modelsFor(p);
    final current = c.modelFor(p);
    const sentinel = '__custom__';
    final items = <DropdownMenuItem<String>>[
      for (final m in models)
        DropdownMenuItem(
            value: m, child: Text(m, style: const TextStyle(fontSize: 13))),
      if (!models.contains(current))
        DropdownMenuItem(
            value: current,
            child: Text(current, style: const TextStyle(fontSize: 13))),
      DropdownMenuItem(
        value: sentinel,
        child: Text(S.t('customModel'),
            style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.green)),
      ),
    ];

    return Row(
      children: [
        Text(S.t('model'),
            style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const Spacer(),
        if (c.isCustomModel(p, current) && !_addingCustom)
          Tooltip(
            message: S.t('deleteModel'),
            child: InkWell(
              onTap: _deleteCustomModel,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Icons.delete_outline, size: 15, color: Palette.faint),
              ),
            ),
          ),
        DropdownButton<String>(
          value: _addingCustom ? sentinel : current,
          underline: const SizedBox.shrink(),
          dropdownColor: const Color(0xFF22262C),
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(fontSize: 13, color: Palette.pri),
          items: items,
          onChanged: (v) {
            if (v == null) return;
            if (v == sentinel) {
              setState(() => _addingCustom = true);
            } else {
              c.setModelFor(p, v);
              _touch();
            }
          },
        ),
      ],
    );
  }

  Widget _customModelRow() {
    return Row(
      children: [
        Expanded(
          child:
              _input(_customModel, hint: S.t('modelIdHint'), autofocus: true),
        ),
        const SizedBox(width: 8),
        GradientButton(
          icon: Icons.add,
          label: S.t('addModel'),
          height: 30,
          fontSize: 12,
          onTap: _addCustomModel,
        ),
      ],
    );
  }

  /// Тонкий минималистичный слайдер прозрачности: 0–100%, применяется мгновенно.
  Widget _opacityRow() {
    final pct = (c.windowOpacity * 100).round();
    return Row(
      children: [
        Text(S.t('bgOpacity'),
            style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: _sliderTheme(context),
            child: Slider(
              value: c.windowOpacity.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              onChanged: (v) {
                setState(() => c.windowOpacity = v);
                widget.session.changed();
              },
              onChangeEnd: (_) => widget.session.saveConfig(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text('$pct%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: Palette.sec)),
        ),
      ],
    );
  }

  Widget _fontSizeRow() {
    return Row(
      children: [
        Text(S.t('fontSize'),
            style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: _sliderTheme(context),
            child: Slider(
              value: c.fontSize.clamp(12.0, 20.0),
              min: 12.0,
              max: 20.0,
              onChanged: (v) {
                setState(() => c.fontSize = v);
                widget.session.changed();
              },
              onChangeEnd: (_) => widget.session.saveConfig(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text('${c.fontSize.round()}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: Palette.sec)),
        ),
      ],
    );
  }

  SliderThemeData _sliderTheme(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      activeTrackColor: Palette.green,
      inactiveTrackColor: Palette.border,
      thumbColor: Palette.pri,
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const Spacer(),
          Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            activeColor: Palette.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Минималистичный выбор цвета: 8 свотчей, выбранный обведён.
  Widget _colorSwatchesRow() {
    const swatches = <int>[
      0xFFE8EAED,
      0xFFFFFFFF,
      0xFF2FBF71,
      0xFF5B9DFF,
      0xFF56C8D8,
      0xFFF5A524,
      0xFFE5484D,
      0xFFB58CFF,
    ];
    return Row(
      children: [
        Text(S.t('textColor'),
            style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              for (final argb in swatches)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      c.hintColor = argb;
                      _touch();
                      widget.session.saveConfig();
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(argb),
                        border: Border.all(
                          color: c.hintColor == argb
                              ? Palette.pri
                              : Palette.border,
                          width: c.hintColor == argb ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Palette.faint)),
    );
  }

  Widget _fieldWithLoad(TextEditingController controller, String label,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Palette.sec)),
            const Spacer(),
            SizedBox(
              height: 22,
              child: TextButton.icon(
                onPressed: () => _loadFromFile(controller),
                icon: const Icon(Icons.file_open_outlined, size: 13),
                label:
                    Text(S.t('load'), style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Palette.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _input(controller, hint: hint, minLines: 3, maxLines: 6),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool obscure = false,
      int minLines = 1,
      int maxLines = 1,
      String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(height: 5),
        _input(controller,
            hint: hint,
            obscure: obscure,
            minLines: minLines,
            maxLines: maxLines),
      ],
    );
  }

  Widget _input(TextEditingController controller,
      {bool obscure = false,
      int minLines = 1,
      int maxLines = 1,
      String? hint,
      bool autofocus = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      style: const TextStyle(fontSize: 13, color: Palette.pri),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Palette.faint),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Palette.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Palette.green),
        ),
      ),
    );
  }
}

Future<void> showSettingsDialog(BuildContext context, Session session) {
  return showDialog(
    context: context,
    builder: (_) => SettingsDialog(session: session),
  );
}
