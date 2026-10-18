// lib/ui/settings/context_tab_mixin.dart
//
// "Context" tab: candidate profile, interviewer profile, goals.
// Mixed into _SettingsDialogState.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../theme.dart';
import 'shared_widgets_mixin.dart';

/// Builds the first settings tab (profile/interviewer/goals text fields).
mixin ContextTabMixin on SharedWidgetsMixin {
  TextEditingController get myProfileCtrl;
  TextEditingController get interviewerProfileCtrl;
  TextEditingController get goalsCtrl;

  // ── Tab root ───────────────────────────────────────────────────────────────

  Widget buildContextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldWithLoad(myProfileCtrl, S.t('myProfile'), hint: S.t('myProfileHint')),
          const SizedBox(height: 12),
          _fieldWithLoad(
            interviewerProfileCtrl,
            S.t('interviewerProfile'),
            hint: S.t('interviewerHint'),
          ),
          const SizedBox(height: 12),
          _labeledField(goalsCtrl, S.t('goals'), minLines: 4, maxLines: 8),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Text area with a "Load from file" button in the header.
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
            Text(label, style: const TextStyle(fontSize: 12, color: Palette.sec)),
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
        settingsInput(controller, hint: hint, minLines: 3, maxLines: 6),
      ],
    );
  }

  /// Plain labeled text area without a load button.
  Widget _labeledField(
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
        settingsInput(
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

  Future<void> _loadFromFile(TextEditingController controller) async {
    const groups = [XTypeGroup(label: 'Text', extensions: ['txt', 'md'])];
    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) return;
    try {
      final text = await file.readAsString();
      setState(() => controller.text = text.trim());
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(S.t('loadFailed'))));
      }
    }
  }
}
