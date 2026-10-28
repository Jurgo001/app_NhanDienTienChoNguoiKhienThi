import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/mobile_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onVibrationChanged,
    required this.onSpeechRateChanged,
    required this.onOpenGuide,
  });

  final AppSettings settings;
  final ValueChanged<bool> onVibrationChanged;
  final ValueChanged<SpeechRateOption> onSpeechRateChanged;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      backLabel: 'Về nhận diện',
      children: [
        Semantics(
          header: true,
          child: Text(
            AppStrings.settingsTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 24),
        AccessibleButton(
          label: AppStrings.listenGuide,
          icon: Icons.menu_book_outlined,
          primary: false,
          onPressed: onOpenGuide,
        ),
        const SizedBox(height: 28),
        Text(AppStrings.vibration,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _switch(
          key: const Key('vibration_switch'),
          label: AppStrings.vibration,
          value: settings.vibrationEnabled,
          onChanged: onVibrationChanged,
        ),
        const SizedBox(height: 24),
        Text(AppStrings.speechRate,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            defaultVerticalAlignment:
                TableCellVerticalAlignment.intrinsicHeight,
            children: [
              TableRow(
                children: [
                  _rateSegment(SpeechRateOption.slow, AppStrings.slow),
                  _rateSegment(SpeechRateOption.normal, AppStrings.normal),
                  _rateSegment(SpeechRateOption.fast, AppStrings.fast),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Thay đổi được lưu tự động và giữ lại khi mở ứng dụng.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _switch({
    required Key key,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        key: key,
        label: label,
        toggled: value,
        enabled: true,
        onTap: () => onChanged(!value),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => onChanged(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value ? 'Đang bật' : 'Đang tắt',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: value,
                      onChanged: onChanged,
                      activeTrackColor: AppColors.navy,
                      activeThumbColor: Colors.white,
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

  Widget _rateSegment(SpeechRateOption value, String label) {
    final selected = settings.speechRate == value;
    void select() => onSpeechRateChanged(value);

    return Semantics(
      key: Key('speech_rate_${value.name}'),
      label: '${AppStrings.speechRate}: $label',
      button: true,
      enabled: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: select,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: select,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? AppColors.navy : Colors.white,
              border: Border(
                right: value == SpeechRateOption.fast
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.border),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
