// lib/ui/settings_dialog.dart
//
// Settings dialog orchestrator: owns state, wires up 3 tab mixins.
// All tab-specific UI lives in lib/ui/settings/*.dart.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:record/record.dart';

import '../l10n.dart';
import '../services/config_store.dart';
import '../services/llm_service.dart';
import '../session.dart';
import 'settings/context_tab_mixin.dart';
import 'settings/llm_tab_mixin.dart';
import 'settings/shared_widgets_mixin.dart';
import 'settings/ui_tab_mixin.dart';
import 'theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.session});

  final Session session;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SharedWidgetsMixin, ContextTabMixin, LlmTabMixin, UiTabMixin {
  // ── Snapshot for cancel/rollback ───────────────────────────────────────────
  late final AppConfig _orig = widget.session.config.clone();

  // ── Text controllers ───────────────────────────────────────────────────────
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

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _obscureKey = true;
  bool _obscureDeepgram = true;
  bool _addingCustom = false;
  bool _checking = false;
  List<InputDevice> _themDevices = [];

  // ── SharedWidgetsMixin requirement ─────────────────────────────────────────
  @override
  AppConfig get c => widget.session.config;

  // ── Session shortcut ───────────────────────────────────────────────────────
  @override
  Session get session => widget.session;

  // ── ContextTabMixin requirements ───────────────────────────────────────────
  @override
  TextEditingController get myProfileCtrl => _myProfile;
  @override
  TextEditingController get interviewerProfileCtrl => _interviewerProfile;
  @override
  TextEditingController get goalsCtrl => _goals;

  // ── LlmTabMixin requirements ───────────────────────────────────────────────
  @override
  TextEditingController get keyCtrl => _key;
  @override
  TextEditingController get deepgramCtrl => _deepgram;
  @override
  TextEditingController get customModelCtrl => _customModel;
  @override
  bool get obscureKey => _obscureKey;
  @override
  bool get obscureDeepgram => _obscureDeepgram;
  @override
  bool get addingCustom => _addingCustom;
  @override
  bool get checking => _checking;
  @override
  List<InputDevice> get themDevices => _themDevices;

  // ── Shared callbacks (consumed by multiple mixins) ─────────────────────────
  @override
  void onTouch() {
    widget.session.changed();
    setState(() {});
  }

  @override
  void onSwitchProvider(LlmProvider p) {
    if (p == c.provider) return;
    c.setKeyFor(c.provider, _key.text.trim());
    c.provider = p;
    _key.text = c.keyFor(p);
    _addingCustom = false;
    onTouch();
  }

  @override
  void onAddCustomModel() {
    final id = _customModel.text.trim();
    if (id.isEmpty) return;
    c.addCustomModel(c.provider, id);
    c.setModelFor(c.provider, id);
    _customModel.clear();
    _addingCustom = false;
    onTouch();
  }

  @override
  void onDeleteCustomModel() {
    final m = c.modelFor(c.provider);
    c.removeCustomModel(c.provider, m);
    c.setModelFor(c.provider, c.modelsFor(c.provider).first);
    onTouch();
  }

  @override
  void onToggleObscureKey() => setState(() => _obscureKey = !_obscureKey);

  @override
  void onToggleObscureDeepgram() => setState(() => _obscureDeepgram = !_obscureDeepgram);

  @override
  void onSetAddingCustom(bool v) => setState(() => _addingCustom = v);

  @override
  void onSetChecking(bool v) => setState(() => _checking = v);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
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

  @override
  void dispose() {
    _deepgram.dispose();
    _key.dispose();
    _customModel.dispose();
    _myProfile.dispose();
    _interviewerProfile.dispose();
    _goals.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                  children: [
                    buildContextTab(),
                    buildLlmTab(),
                    buildUiTab(),
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
            final nav = Navigator.of(context, rootNavigator: true);
            if (nav.canPop()) {
              nav.pop();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(S.t('cancel')),
        ),
        GradientButton(
          icon: Icons.check_rounded,
          label: S.t('save'),
          height: 34,
          fontSize: 12,
          onTap: () async {
            final nav = Navigator.of(context, rootNavigator: true);
            c.deepgramToken = _deepgram.text.trim();
            c.setKeyFor(c.provider, _key.text.trim());
            c.myProfile = _myProfile.text.trim();
            c.interviewerProfile = _interviewerProfile.text.trim();
            c.goals = _goals.text.trim();
            try {
              await widget.session.saveConfig();
            } catch (e) {
              debugPrint('[SETTINGS] save error: $e');
            } finally {
              if (nav.canPop()) {
                nav.pop();
              } else if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      ],
    );
  }
}

Future<void> showSettingsDialog(BuildContext context, Session session) {
  return showDialog(
    context: context,
    builder: (_) => SettingsDialog(session: session),
  );
}
