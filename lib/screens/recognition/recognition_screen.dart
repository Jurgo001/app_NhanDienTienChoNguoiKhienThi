import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/recognition_ui_state.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/camera_frame.dart';
import '../../widgets/denomination_card.dart';
import '../../widgets/mobile_page.dart';
import '../../widgets/recognition_status.dart';

class RecognitionScreen extends StatelessWidget {
  const RecognitionScreen({
    super.key,
    required this.state,
    required this.onStartScanning,
    required this.onReplayResult,
    required this.onResetScan,
    required this.onOpenSettings,
    required this.onOpenGuide,
    required this.onOpenPermission,
    this.cameraPreview,
    this.isMockBackend = true,
    this.isStarting = false,
    this.serviceNotice,
    this.onRetryServices,
    this.debugControls,
  });

  final RecognitionUiState state;
  final VoidCallback onStartScanning;
  final VoidCallback onReplayResult;
  final VoidCallback onResetScan;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenPermission;
  final Widget? cameraPreview;
  final bool isMockBackend, isStarting;
  final String? serviceNotice;
  final VoidCallback? onRetryServices;
  final Widget? debugControls;

  @override
  Widget build(BuildContext context) {
    final isReady = state.status == RecognitionUiStatus.ready;
    final emptyMessage = state.status == RecognitionUiStatus.scanning
        ? (state.isMock
            ? AppStrings.scanningNoResult
            : AppStrings.scanningNoResultReal)
        : AppStrings.noResult;
    final cameraHeight =
        (MediaQuery.sizeOf(context).height * .40).clamp(230.0, 360.0);

    return MobilePage(
      background: AppColors.navySoft,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: RecognitionStatus(state: state)),
            const SizedBox(width: 12),
            Expanded(
              child: AccessibleButton(
                label: AppStrings.settingsTitle,
                primary: false,
                onPressed: onOpenSettings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (isMockBackend)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('CHẾ ĐỘ MÔ PHỎNG • Không nhận diện tiền thật',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.yellow)),
          ),
        if (serviceNotice != null) ...[
          Text(serviceNotice!, style: const TextStyle(color: AppColors.yellow)),
          TextButton(
              onPressed: onRetryServices,
              child: const Text('Thử lại âm thanh / cài đặt',
                  style: TextStyle(color: Colors.white))),
        ],
        SizedBox(
          height: cameraHeight,
          child: cameraPreview == null
              ? CameraFrame(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          height: 112,
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7EFEB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF557166),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TỜ TIỀN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isMockBackend
                            ? AppStrings.cameraPlaceholder
                            : 'Camera chưa mở',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    cameraPreview!,
                    const IgnorePointer(
                      child: CameraFrame(child: SizedBox.expand()),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        DenominationCard(
          denomination: state.hasResult ? state.denomination : null,
          isMock: state.isMock,
          spokenDenomination: state.spokenDenomination,
          emptyMessage: emptyMessage,
        ),
        const SizedBox(height: 14),
        if (state.guidance != null &&
            state.status == RecognitionUiStatus.scanning)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.guidance!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18))),
        if (state.hasResult) ...[
          AccessibleButton(
            key: const Key('replay_button'),
            label: AppStrings.replay,
            icon: Icons.volume_up_outlined,
            onPressed: onReplayResult,
          ),
          TextButton(
            key: const Key('scan_button'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: onResetScan,
            child: const Text(AppStrings.scanAgain),
          ),
        ] else ...[
          AccessibleButton(
            key: const Key('scan_button'),
            label: isStarting
                ? 'Đang mở camera / mô hình…'
                : isReady
                    ? AppStrings.startScan
                    : AppStrings.scanAgain,
            icon: Icons.photo_camera_outlined,
            onPressed: isStarting
                ? null
                : isReady
                    ? onStartScanning
                    : onResetScan,
          ),
          const SizedBox(height: 10),
          AccessibleButton(
            key: const Key('replay_button'),
            label: AppStrings.replay,
            icon: Icons.volume_up_outlined,
            primary: false,
            onPressed: null,
          ),
        ],
        const Spacer(),
        if (state.hasResult)
          const Text('Phiên mới sau 15 giây',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onOpenPermission,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text(AppStrings.cameraPermissionTitle),
            ),
            TextButton.icon(
              onPressed: onOpenGuide,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text(AppStrings.guideTitle),
            ),
          ],
        ),
        if (debugControls != null)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('demo_expander'),
              tilePadding: EdgeInsets.zero,
              iconColor: Colors.white70,
              collapsedIconColor: Colors.white70,
              title: const Text(
                'Thử trạng thái mô phỏng',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              children: [debugControls!],
            ),
          ),
      ],
    );
  }
}
