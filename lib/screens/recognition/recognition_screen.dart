import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/recognition_ui_state.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/camera_frame.dart';
import '../../widgets/denomination_card.dart';
import '../../widgets/mobile_page.dart';
import '../../widgets/recognition_status.dart';
import '../../utils/vnd_money_text.dart';

class RecognitionScreen extends StatelessWidget {
  const RecognitionScreen({
    super.key,
    required this.state,
    required this.onOpenSettings,
    this.onSwitchMode,
    this.onNewCountingSession,
    this.onReadCountingTotal,
    this.screenReaderActive = false,
    this.preparingCamera = false,
    this.modeTalkBackAnnouncement,
    this.flashAccessibilityStatus,
    this.onRecoverCamera,
    this.cameraRetryRequired = false,
    this.onRetryCamera,
    this.cameraPermissionMissing = false,
    this.isMoneyCounting = false,
    this.totalVnd = 0,
    this.noteCount = 0,
    this.cameraPreview,
    this.isMockBackend = true,
    this.serviceNotice,
    this.onRetryServices,
    this.debugControls,
  });

  final RecognitionUiState state;
  final VoidCallback onOpenSettings;
  final VoidCallback? onSwitchMode;
  final VoidCallback? onNewCountingSession;
  final VoidCallback? onReadCountingTotal;
  final bool screenReaderActive;
  final bool preparingCamera;
  final String? modeTalkBackAnnouncement;
  final String? flashAccessibilityStatus;
  final VoidCallback? onRecoverCamera;
  final bool cameraRetryRequired;
  final VoidCallback? onRetryCamera;
  final bool cameraPermissionMissing;
  final bool isMoneyCounting;
  final int totalVnd;
  final int noteCount;
  final Widget? cameraPreview;
  final bool isMockBackend;
  final String? serviceNotice;
  final VoidCallback? onRetryServices;
  final Widget? debugControls;

  @override
  Widget build(BuildContext context) {
    final emptyMessage = state.status == RecognitionUiStatus.scanning
        ? (state.isMock
            ? AppStrings.scanningNoResult
            : AppStrings.scanningNoResultReal)
        : AppStrings.noResult;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    // Counting adds a card; use a shorter preview to keep controls visible.
    final cameraHeight = isMoneyCounting
        ? (viewportHeight * .27).clamp(185.0, 255.0)
        : (viewportHeight * .34).clamp(220.0, 325.0);

    return MobilePage(
      background: AppColors.navySoft,
      children: [
        // Stable TalkBack live-region; not a separate FlutterTts voice.
        if (screenReaderActive)
          Semantics(
            key: const Key('mode_talkback_status'),
            container: true,
            liveRegion: modeTalkBackAnnouncement != null,
            label: modeTalkBackAnnouncement ?? 'Thông báo chuyển chế độ',
            child: const SizedBox(width: 1, height: 1),
          ),
        // A stable live region is politely announced by TalkBack when
        // its label changes; no second app TTS voice is started.
        // Keep it out of the camera preview ExcludeSemantics subtree.
        if (screenReaderActive)
          Semantics(
            key: const Key('flash_talkback_status'),
            container: true,
            liveRegion: flashAccessibilityStatus != null,
            label: flashAccessibilityStatus ?? 'Trạng thái đèn flash',
            child: const SizedBox(width: 1, height: 1),
          ),
        ExcludeSemantics(
          // Dynamic camera status is read by the app, not by TalkBack focus.
          // Controls and non-changing UI labels elsewhere stay accessible.
          excluding: screenReaderActive,
          child: RecognitionStatus(
            state: state,
            announceChanges: false,
          ),
        ),
        const SizedBox(height: 12),
        if (isMoneyCounting) ...[
          const SizedBox(height: 12),
          // The total stays readable on demand by TalkBack.
          // This is NOT a liveRegion, so no automatic second voice.
          Semantics(
            container: true,
            label: 'Tổng tiền hiện tại ${VndMoneyText.spoken(totalVnd)}. '
                'Đã đếm $noteCount tờ.',
            child: ExcludeSemantics(
              child: GestureDetector(
                key: const Key('counting_total_card'),
                behavior: HitTestBehavior.opaque,
                onTap: screenReaderActive ? null : onReadCountingTotal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.yellow),
                  ),
                  child: Column(children: [
                    const Text('TỔNG TIỀN ĐÃ ĐẾM',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text('${VndMoneyText.digits(totalVnd)}đ',
                        style: const TextStyle(
                            color: AppColors.yellow,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    Text('Đã đếm $noteCount tờ',
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (isMockBackend)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('CHẾ ĐỘ MÔ PHỎNG • Không nhận diện tiền thật',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.yellow)),
          ),
        if (serviceNotice != null) ...[
          Text(serviceNotice!, style: const TextStyle(color: AppColors.yellow)),
          if (!cameraRetryRequired)
            TextButton(
                onPressed: onRetryServices,
                child: const Text('Thử lại âm thanh / cài đặt',
                    style: TextStyle(color: Colors.white))),
        ],
        if (cameraRetryRequired && !isMockBackend) ...[
          const SizedBox(height: 12),
          AccessibleButton(
            key: const Key('retry_camera_after_timeout_button'),
            label: 'Thử mở lại camera',
            semanticLabel: 'Thử mở lại camera và kiểm tra nhận diện',
            icon: Icons.refresh,
            onPressed: onRetryCamera,
          ),
          const SizedBox(height: 12),
        ],
        ExcludeSemantics(
          // Camera preview and its disappearing placeholder are visual only.
          excluding: screenReaderActive,
          child: SizedBox(
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
                              : preparingCamera
                                  ? 'Đang chuẩn bị camera, vui lòng chờ.'
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
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          // App TTS owns dynamic money results.
          excluding: screenReaderActive,
          child: DenominationCard(
            announceChanges: false, // Spoken by the app TTS, not liveRegion.
            denomination: state.hasResult ? state.denomination : null,
            isMock: state.isMock,
            spokenDenomination: state.spokenDenomination,
            emptyMessage: emptyMessage,
          ),
        ),
        const SizedBox(height: 14),
        if (state.guidance != null &&
            state.status == RecognitionUiStatus.scanning)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ExcludeSemantics(
                  excluding: screenReaderActive,
                  child: Text(state.guidance!,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18)))),
        const Spacer(),
        const SizedBox(height: 20),
        if (cameraPermissionMissing && !isMockBackend) ...[
          SizedBox(
            height: 74,
            child: AccessibleButton(
              key: const Key('recover_camera_permission_button'),
              label: 'Khắc phục quyền camera',
              icon: Icons.lock_open,
              onPressed: onRecoverCamera,
            ),
          ),
          const SizedBox(height: 14),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: AccessibleButton(
            key: const Key('switch_mode_button'),
            label: isMoneyCounting
                ? 'Chuyển sang nhận diện tiền'
                : 'Chuyển sang đếm tiền',
            semanticLabel: 'Chuyển chế độ',
            icon: Icons.swap_horiz,
            onPressed: onSwitchMode,
          ),
        ),
        const SizedBox(height: 12),
        if (isMoneyCounting) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: AccessibleButton(
              key: const Key('new_counting_session_button'),
              label: 'Bắt đầu phiên đếm mới',
              semanticLabel: 'Bắt đầu phiên đếm mới, yêu cầu xác nhận',
              icon: Icons.restart_alt,
              primary: false,
              destructive: true,
              onPressed: onNewCountingSession,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: AccessibleButton(
            key: const Key('open_settings_button'),
            label: AppStrings.settingsTitle,
            semanticLabel: 'Mở tùy chọn và hướng dẫn sử dụng',
            icon: Icons.settings_outlined,
            primary: false,
            onPressed: onOpenSettings,
          ),
        ),
        const SizedBox(height: 28),
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
