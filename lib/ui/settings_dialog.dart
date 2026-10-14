import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:record/record.dart';

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

  late final TextEditingController _deepgram = TextEditingController(
    text: widget.session.config.deepgramToken,
  );
  late final TextEditingController _key = TextEditingController(
    text: widget.session.config.keyFor(widget.session.config.provider),
  );
  final TextEditingController _customModel = TextEditingController();
  late final TextEditingController _myProfile = TextEditingController(
    text: widget.session.config.myProfile,
  );
  late final TextEditingController _interviewerProfile = TextEditingController(
    text: widget.session.config.interviewerProfile,
  );
  late final TextEditingController _goals = TextEditingController(
    text: widget.session.config.goals,
  );

  bool _obscureKey = true;
  bool _obscureDeepgram = true;
  bool _addingCustom = false;
  bool _checking = false;
  List<InputDevice> _themDevices = [];

  AppConfig get c => widget.session.config;

  @override
  void initState() {
    super.initState();
    _themDevices = List.of(widget.session.audioDevices);
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    await widget.session.loadAudioDevices();
    if (mounted) {
      setState(() => _themDevices = List.of(widget.session.audioDevices));
    }
  }

  void _touch() {
    widget.session.changed();
    setState(() {});
  }

  void _switchProvider(LlmProvider p) {
    if (p == c.provider) return;
    c.setKeyFor(c.provider, _key.text.trim());
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
    const groups = [
      XTypeGroup(label: 'Text', extensions: ['txt', 'md']),
    ];
    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) return;
    try {
      final text = await file.readAsString();
      setState(() => controller.text = text.trim());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(S.t('loadFailed'))));
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
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SvgPicture.asset('assets/logo.svg', width: 20, height: 20),
          ),
          const SizedBox(width: 8),
          Text(
            S.t('settingsTitle'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: math.min(540, MediaQuery.sizeOf(context).height * 0.74),
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
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 14),
                        const SizedBox(width: 6),
                        Text(S.t('tabContext')),
                      ],
                    ),
                  ),
                  const Tab(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.memory, size: 14),
                        SizedBox(width: 6),
                        Text('LLM'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.palette_outlined, size: 14),
                        const SizedBox(width: 6),
                        Text(S.t('tabUi')),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [_contextTab(), _llmTab(), _uiTab()],
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
          _fieldWithLoad(
            _myProfile,
            S.t('myProfile'),
            hint: S.t('myProfileHint'),
          ),
          const SizedBox(height: 12),
          _fieldWithLoad(
            _interviewerProfile,
            S.t('interviewerProfile'),
            hint: S.t('interviewerHint'),
          ),
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
          _keyFieldWithCheck(p),
          const SizedBox(height: 12),
          _modelRow(p),
          if (_addingCustom) ...[const SizedBox(height: 8), _customModelRow()],
          const SizedBox(height: 14),
          _contextTurnsRow(),
          const SizedBox(height: 14),
          _section(S.t('sectionAudio')),
          _field(
            _deepgram,
            S.t('deepgramToken'),
            obscure: _obscureDeepgram,
            suffixIcon: _eyeButton(
              obscured: _obscureDeepgram,
              onToggle: () =>
                  setState(() => _obscureDeepgram = !_obscureDeepgram),
            ),
          ),
          const SizedBox(height: 12),
          _mySourceRow(),
          const SizedBox(height: 12),
          _themSourceRow(),
        ],
      ),
    );
  }

  /// Регулировка количества последних реплик для отправки в LLM.
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Palette.pri,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: _sliderTheme(context),
          child: Slider(
            value: c.llmContextTurns.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            onChanged: (v) {
              c.llmContextTurns = v.round();
              _touch();
            },
          ),
        ),
        Text(
          S.t('llmContextTurnsHint'),
          style: const TextStyle(fontSize: 11, color: Palette.sec),
        ),
      ],
    );
  }

  /// Источник своего микрофона (напр. Встроенный микрофон или гарнитура).
  Widget _mySourceRow() {
    final myDevices =
        _themDevices
            .where((d) => !d.label.toLowerCase().contains('blackhole'))
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
          child: Text(
            d.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      if (c.myDeviceId.isNotEmpty &&
          !myDevices.any((d) => d.id == c.myDeviceId))
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

    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    for (final item in rawItems) {
      final val = item.value ?? '';
      if (seen.add(val)) {
        items.add(item);
      }
    }
    final selectedVal = seen.contains(c.myDeviceId) ? c.myDeviceId : '';

    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            S.t('mySource'),
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
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
            onChanged: (v) {
              c.myDeviceId = v ?? '';
              _touch();
            },
          ),
        ),
      ],
    );
  }

  /// Источник голоса собеседника: входное аудиоустройство (напр. BlackHole).
  Widget _themSourceRow() {
    final rawItems = <DropdownMenuItem<String>>[
      for (final d in _themDevices)
        DropdownMenuItem(
          value: d.id,
          child: Text(
            d.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
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
      if (c.themDeviceId.isNotEmpty &&
          !_themDevices.any((d) => d.id == c.themDeviceId))
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

    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    for (final item in rawItems) {
      final val = item.value ?? '';
      if (seen.add(val)) {
        items.add(item);
      }
    }
    final selectedVal = seen.contains(c.themDeviceId) ? c.themDeviceId : '';

    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            S.t('themSource'),
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
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
            onChanged: (v) {
              if (v == null) return;
              c.themDeviceId = v;
              _touch();
            },
          ),
        ),
      ],
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
          const SizedBox(height: 10),
          _miniChoiceRow(
            S.t('titlebarMode'),
            c.titlebarMode,
            [
              ('transparent', Icons.blur_on, S.t('tbTransparent')),
              ('opaque', Icons.dock, S.t('tbOpaque')),
              ('hidden', Icons.visibility_off, S.t('tbHidden')),
            ],
            (v) {
              c.titlebarMode = v;
              widget.session.applyTitlebar();
              _touch();
            },
          ),
          const SizedBox(height: 10),
          _switchRow(
            S.t('hideFromScreenShare'),
            c.hideFromScreenShare,
            (v) {
              c.hideFromScreenShare = v;
              widget.session.applyWindowSettings();
              _touch();
            },
            subtitle: S.t('hideFromScreenShareSub'),
          ),
          const SizedBox(height: 4),
          _switchRow(
            S.t('alwaysOnTop'),
            c.alwaysOnTop,
            (v) {
              c.alwaysOnTop = v;
              widget.session.applyWindowSettings();
              _touch();
            },
            subtitle: S.t('alwaysOnTopSub'),
          ),
          const SizedBox(height: 12),
          _section(S.t('sectionHotkeys')),
          _hotkeyRow(
            '⌥ 1',
            S.t('hotkeyGetAnswer'),
            S.t('hotkeyGetAnswerDesc'),
          ),
          const SizedBox(height: 6),
          _hotkeyRow(
            '⌥ 2',
            S.t('hotkeyScreenshot'),
            S.t('hotkeyScreenshotDesc'),
          ),
          const SizedBox(height: 12),
          _section(S.t('sectionText')),
          _fontSizeRow(),
          const SizedBox(height: 8),
          _turnSpacingRow(),
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

  Widget _eyeButton({required bool obscured, required VoidCallback onToggle}) {
    return Tooltip(
      message: obscured ? S.t('showKey') : S.t('hideKey'),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 16,
            color: obscured ? Palette.sec : Palette.green,
          ),
        ),
      ),
    );
  }

  /// Поле ключа с микро-кнопкой проверки «ключ + модель».
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
              child:
                  _checking
                      ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Palette.green.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Palette.green,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              S.t('checkRunning'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Palette.green,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Tooltip(
                        message: S.t('checkModel'),
                        child: InkWell(
                          onTap: _checkModel,
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Palette.green.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: Palette.green.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 13,
                                  color: Palette.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  S.t('checkAction'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Palette.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _input(
          _key,
          obscure: _obscureKey,
          suffixIcon: _eyeButton(
            obscured: _obscureKey,
            onToggle: () => setState(() => _obscureKey = !_obscureKey),
          ),
        ),
      ],
    );
  }

  /// Живой мини-запрос к выбранному провайдеру: ключ и модель рабочие?
  Future<void> _checkModel() async {
    if (_checking) return;
    setState(() => _checking = true);
    String? error;
    try {
      final reply = await LlmService.ask(
        provider: c.provider,
        apiKey: _key.text.trim(),
        model: c.modelFor(c.provider),
        prompt: 'Ответь ровно одним словом: OK',
      );
      if (reply.trim().isEmpty) error = 'Пустой ответ';
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() => _checking = false);
    _showCheckResult(error);
  }

  void _showCheckResult(String? error) {
    final isSuccess = error == null;
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Palette.dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color:
                    isSuccess
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
                    // Заголовок со статусом и мини-кнопкой закрытия [x]
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isSuccess ? Palette.green : Palette.red)
                                .withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            isSuccess
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            size: 16,
                            color: isSuccess ? Palette.green : Palette.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isSuccess
                                ? S.t('checkSuccessTitle')
                                : S.t('checkErrorTitle'),
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
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Palette.sec,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Тело сообщения в карточке
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isSuccess ? Palette.green : Palette.red)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        error ?? S.t('checkSuccessDesc'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color:
                              isSuccess ? Palette.pri : const Color(0xFFFF8A80),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Нижняя кнопка закрытия
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

  Widget _dropdownRow() {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            S.t('provider'),
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
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
                  child: Text(
                    p.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (p) {
              if (p != null) _switchProvider(p);
            },
          ),
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
          value: m,
          child: Text(
            m,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      if (!models.contains(current))
        DropdownMenuItem(
          value: current,
          child: Text(
            current,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      DropdownMenuItem(
        value: sentinel,
        child: Text(
          S.t('customModel'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Palette.green,
          ),
        ),
      ),
    ];

    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            S.t('model'),
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
        ),
        const SizedBox(width: 8),
        if (c.isCustomModel(p, current) && !_addingCustom)
          Tooltip(
            message: S.t('deleteModel'),
            child: InkWell(
              onTap: _deleteCustomModel,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.delete_outline,
                  size: 15,
                  color: Palette.faint,
                ),
              ),
            ),
          ),
        Expanded(
          child: DropdownButton<String>(
            value: _addingCustom ? sentinel : current,
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
                setState(() => _addingCustom = true);
              } else {
                c.setModelFor(p, v);
                _touch();
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
          child: _input(
            _customModel,
            hint: S.t('modelIdHint'),
            autofocus: true,
          ),
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
        Text(
          S.t('bgOpacity'),
          style: const TextStyle(fontSize: 12, color: Palette.sec),
        ),
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
          child: Text(
            '$pct%',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
        ),
      ],
    );
  }

  Widget _fontSizeRow() {
    return Row(
      children: [
        Text(
          S.t('fontSize'),
          style: const TextStyle(fontSize: 12, color: Palette.sec),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: _sliderTheme(context),
            child: Slider(
              value: c.fontSize.clamp(6.0, 24.0),
              min: 6.0,
              max: 24.0,
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
          child: Text(
            '${c.fontSize.round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
        ),
      ],
    );
  }

  Widget _turnSpacingRow() {
    return Row(
      children: [
        Text(
          S.t('turnSpacing'),
          style: const TextStyle(fontSize: 12, color: Palette.sec),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: _sliderTheme(context),
            child: Slider(
              value: c.turnSpacing.clamp(0.0, 20.0),
              min: 0.0,
              max: 20.0,
              onChanged: (v) {
                setState(() => c.turnSpacing = v);
                widget.session.changed();
              },
              onChangeEnd: (_) => widget.session.saveConfig(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            '${c.turnSpacing.round()} px',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Palette.sec),
          ),
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

  Widget _switchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment:
            subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Palette.pri),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Palette.sec,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeThumbColor: Palette.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
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
        Text(
          S.t('textColor'),
          style: const TextStyle(fontSize: 12, color: Palette.sec),
        ),
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
                          color:
                              c.hintColor == argb
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

  /// Микро-переключатель: серые иконки+текст, активный подсвечен зелёным.
  Widget _miniChoiceRow(
    String label,
    String value,
    List<(String, IconData, String)> options,
    ValueChanged<String> onSelected,
  ) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                InkWell(
                  onTap: () => onSelected(options[i].$1),
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color:
                          value == options[i].$1
                              ? Palette.green.withValues(alpha: 0.14)
                              : Colors.transparent,
                      border:
                          value == options[i].$1
                              ? Border.all(
                                color: Palette.green.withValues(alpha: 0.55),
                              )
                              : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          options[i].$2,
                          size: 11,
                          color:
                              value == options[i].$1
                                  ? Palette.green
                                  : Palette.sec,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          options[i].$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                value == options[i].$1
                                    ? Palette.green
                                    : Palette.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < options.length - 1) const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _hotkeyRow(String keyCombo, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Palette.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Palette.border),
            ),
            child: Text(
              keyCombo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Palette.green,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Palette.pri,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Palette.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Palette.faint,
        ),
      ),
    );
  }

  Widget _fieldWithLoad(
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Palette.sec),
            ),
            const Spacer(),
            SizedBox(
              height: 22,
              child: TextButton.icon(
                onPressed: () => _loadFromFile(controller),
                icon: const Icon(Icons.file_open_outlined, size: 13),
                label: Text(S.t('load'), style: const TextStyle(fontSize: 11)),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.sec)),
        const SizedBox(height: 5),
        _input(
          controller,
          hint: hint,
          obscure: obscure,
          minLines: minLines,
          maxLines: maxLines,
          suffixIcon: suffixIcon,
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController controller, {
    bool obscure = false,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
    bool autofocus = false,
    Widget? suffixIcon,
  }) {
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        suffixIcon: suffixIcon,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
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
