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
    this.onHardwareShortcutsChanged,
    required this.onOpenGuide,
    this.onBack,
  });

  final AppSettings settings;
  final ValueChanged<bool> onVibrationChanged;
  final ValueChanged<SpeechRateOption> onSpeechRateChanged;
  final ValueChanged<bool>? onHardwareShortcutsChanged;
  final VoidCallback onOpenGuide;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Android system Back must use the same wait-then-navigate flow.
    return PopScope(
      canPop: onBack == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack?.call();
      },
      child: MobilePage(
        backLabel: 'Quay lại camera',
        onBack: onBack,
        background: AppColors.navySoft,
        children: [
          Semantics(
            header: true,
            child: Text(
              AppStrings.settingsTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 30),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: AccessibleButton(
              key: const Key('open_guide_button'),
              label: 'Hướng dẫn sử dụng',
              icon: Icons.menu_book_outlined,
              primary: false,
              onPressed: onOpenGuide,
            ),
          ),
          const SizedBox(height: 32),
          Text(AppStrings.vibration,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 10),
          _switch(
            key: const Key('vibration_switch'),
            label: AppStrings.vibration,
            value: settings.vibrationEnabled,
            onChanged: onVibrationChanged,
          ),
          const SizedBox(height: 30),
          Text(AppStrings.speechRate,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white)),
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
          const SizedBox(height: 30),
          const SizedBox(height: 28),
          Text('Phím tắt âm lượng (tùy chọn)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 10),
          _switch(
            key: const Key('hardware_shortcuts_switch'),
            label: 'Phím tắt âm lượng',
            value: settings.hardwareShortcutsEnabled,
            onChanged: onHardwareShortcutsChanged,
          ),
          const SizedBox(height: 8),
          const Text(
            'Mặc định tắt để giữ phím + và − chỉnh âm lượng liên tục. '
            'Khi bật và không dùng TalkBack: giữ + ba giây để đổi chế độ; '
            'giữ − ba giây lần một để nghe cảnh báo; giữ lại lần hai trong 15 giây để xác nhận xóa phiên. '
            'Khi bật, giữ phím sẽ không còn điều chỉnh âm lượng liên tục. '
            'Phím tắt tự tạm ngừng khi chế độ rà trợ năng hoạt động.',
            style: TextStyle(color: AppColors.paleBlue, height: 1.5),
          ),
          const Text(
            'Thay đổi được lưu tự động và giữ lại khi mở ứng dụng.',
            style: TextStyle(color: AppColors.paleBlue, height: 1.5),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _switch({
    required Key key,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
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
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => onChanged.call(!value),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged.call(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
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
                          color: AppColors.navy,
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
              constraints: const BoxConstraints(minHeight: 80),
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
