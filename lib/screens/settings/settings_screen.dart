import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onAutoReadChanged,
    required this.onVibrationChanged,
    required this.onSpeechRateChanged,
  });

  final AppSettings settings;
  final ValueChanged<bool> onAutoReadChanged;
  final ValueChanged<bool> onVibrationChanged;
  final ValueChanged<SpeechRateOption> onSpeechRateChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppConstants.contentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        AppStrings.settingsTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    Container(
                      padding: const EdgeInsets.all(AppConstants.cardPadding),
                      decoration: BoxDecoration(
                        color: AppColors.paleYellow,
                        borderRadius:
                            BorderRadius.circular(AppConstants.cornerRadius),
                      ),
                      child: const Text(
                        AppStrings.settingsMockNotice,
                        style: TextStyle(color: AppColors.navy, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    Card(
                      child: SwitchListTile(
                        key: const Key('auto_read_switch'),
                        title: const Text(AppStrings.autoRead),
                        subtitle: const Text(AppStrings.autoReadDetail),
                        secondary: const Icon(Icons.record_voice_over_outlined),
                        value: settings.autoReadEnabled,
                        onChanged: onAutoReadChanged,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.cardPadding,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    Card(
                      child: SwitchListTile(
                        key: const Key('vibration_switch'),
                        title: const Text(AppStrings.vibration),
                        subtitle: const Text(AppStrings.vibrationDetail),
                        secondary: const Icon(Icons.vibration),
                        value: settings.vibrationEnabled,
                        onChanged: onVibrationChanged,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.cardPadding,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.speechRate,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppConstants.itemGap),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _rateChip(
                                  SpeechRateOption.slow,
                                  AppStrings.slow,
                                ),
                                _rateChip(
                                  SpeechRateOption.normal,
                                  AppStrings.normal,
                                ),
                                _rateChip(
                                  SpeechRateOption.fast,
                                  AppStrings.fast,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rateChip(SpeechRateOption value, String label) {
    return ChoiceChip(
      key: Key('speech_rate_${value.name}'),
      label: Text(label),
      selected: settings.speechRate == value,
      onSelected: (_) => onSpeechRateChanged(value),
      labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      selectedColor: AppColors.yellow,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
