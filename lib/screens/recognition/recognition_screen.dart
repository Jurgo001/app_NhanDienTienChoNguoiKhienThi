import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/recognition_ui_state.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/camera_frame.dart';
import '../../widgets/denomination_card.dart';
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
  final Widget? debugControls;

  @override
  Widget build(BuildContext context) {
    final isReady = state.status == RecognitionUiStatus.ready;
    final emptyMessage = state.status == RecognitionUiStatus.scanning
        ? (state.isMock
            ? AppStrings.scanningNoResult
            : AppStrings.scanningNoResultReal)
        : AppStrings.noResult;

    return Scaffold(
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
                        AppStrings.appTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    if (state.isMock) ...[
                      Container(
                        padding: const EdgeInsets.all(AppConstants.cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.paleYellow,
                          borderRadius:
                              BorderRadius.circular(AppConstants.cornerRadius),
                        ),
                        child: const Text(
                          AppStrings.simulationBanner,
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.sectionGap),
                    ],
                    RecognitionStatus(state: state),
                    const SizedBox(height: AppConstants.itemGap),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppConstants.cornerRadius),
                      child: Container(
                        width: double.infinity,
                        color: AppColors.navySoft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppConstants.cameraMinHeight,
                          ),
                          child: cameraPreview == null
                              ? const CameraFrame(child: _CameraPlaceholder())
                              : Stack(
                                  children: [
                                    Positioned.fill(child: cameraPreview!),
                                    const CameraFrame(
                                      child: SizedBox(
                                        height: AppConstants.cameraMinHeight,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    DenominationCard(
                      denomination: state.hasResult ? state.denomination : null,
                      isMock: state.isMock,
                      emptyMessage: emptyMessage,
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    if (state.hasResult) ...[
                      AccessibleButton(
                        key: const Key('replay_button'),
                        label: AppStrings.replay,
                        icon: Icons.volume_up_outlined,
                        onPressed: onReplayResult,
                      ),
                      const SizedBox(height: AppConstants.itemGap),
                      AccessibleButton(
                        key: const Key('scan_button'),
                        label: AppStrings.scanAgain,
                        icon: Icons.center_focus_strong,
                        primary: false,
                        onPressed: onResetScan,
                      ),
                    ] else ...[
                      AccessibleButton(
                        key: const Key('scan_button'),
                        label: isReady
                            ? AppStrings.startScan
                            : AppStrings.scanAgain,
                        icon: Icons.center_focus_strong,
                        onPressed: isReady ? onStartScanning : onResetScan,
                      ),
                      const SizedBox(height: AppConstants.itemGap),
                      AccessibleButton(
                        key: const Key('replay_button'),
                        label: AppStrings.replay,
                        icon: Icons.volume_up_outlined,
                        primary: false,
                        onPressed: null,
                      ),
                    ],
                    const SizedBox(height: AppConstants.sectionGap),
                    AccessibleButton(
                      label: AppStrings.cameraPermissionTitle,
                      icon: Icons.videocam_outlined,
                      primary: false,
                      onPressed: onOpenPermission,
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    AccessibleButton(
                      label: AppStrings.settingsTitle,
                      icon: Icons.settings_outlined,
                      primary: false,
                      onPressed: onOpenSettings,
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    AccessibleButton(
                      label: AppStrings.guideTitle,
                      icon: Icons.menu_book_outlined,
                      primary: false,
                      onPressed: onOpenGuide,
                    ),
                    if (debugControls != null) ...[
                      const SizedBox(height: AppConstants.sectionGap),
                      debugControls!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.photo_camera_outlined, color: AppColors.surface, size: 34),
        SizedBox(height: 12),
        Text(
          AppStrings.cameraPlaceholder,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.surface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          AppStrings.cameraAlignHelp,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.surface, fontSize: 16),
        ),
      ],
    );
  }
}
