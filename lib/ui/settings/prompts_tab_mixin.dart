// lib/ui/settings/prompts_tab_mixin.dart
//
// "Промпты" tab: System Role, Instructions, Video / Face Frame Prompt.
// Mixed into _SettingsDialogState.

import 'package:flutter/material.dart';
import '../../services/config_store.dart';
import '../theme.dart';
import 'shared_widgets_mixin.dart';

mixin PromptsTabMixin on SharedWidgetsMixin {
  TextEditingController get systemRoleCtrl;
  TextEditingController get instructionsCtrl;
  TextEditingController get videoPromptCtrl;

  Widget buildPromptsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldWithReset(
            controller: systemRoleCtrl,
            label: 'Системная роль нейросети (System Role)',
            defaultText: AppConfig.defaultSystemRole,
            hint: 'Определяет роль, личность и миссию модели',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 14),
          _fieldWithReset(
            controller: instructionsCtrl,
            label: 'Правила формирования подсказок (Instructions)',
            defaultText: AppConfig.defaultInstructions,
            hint: 'Инструкции: первое лицо, краткость, реакция на невербалику',
            minLines: 4,
            maxLines: 8,
          ),
          const SizedBox(height: 14),
          _fieldWithReset(
            controller: videoPromptCtrl,
            label: 'Инструкция для видео-кадра лица (Face Crop Frame)',
            defaultText: AppConfig.defaultVideoPrompt,
            hint: 'Как мультимодальной модели анализировать мимику и взгляд на фото',
            minLines: 4,
            maxLines: 8,
          ),
        ],
      ),
    );
  }

  Widget _fieldWithReset({
    required TextEditingController controller,
    required String label,
    required String defaultText,
    required String hint,
    required int minLines,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.pri),
              ),
            ),
            SizedBox(
              height: 22,
              child: TextButton.icon(
                onPressed: () {
                  controller.text = defaultText;
                  onTouch();
                },
                icon: const Icon(Icons.restart_alt, size: 12),
                label: const Text('Сброс к дефолту', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Palette.amber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        settingsInput(
          controller,
          hint: hint,
          minLines: minLines,
          maxLines: maxLines,
        ),
      ],
    );
  }
}
