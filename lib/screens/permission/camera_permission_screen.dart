import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/mobile_page.dart';

enum MockPermissionDecision { undecided, approved, denied }

class CameraPermissionScreen extends StatelessWidget {
  const CameraPermissionScreen({
    super.key,
    required this.decision,
    required this.onApproveMock,
    required this.onDenyMock,
    required this.onContinueMock,
  });
  final MockPermissionDecision decision;
  final VoidCallback onApproveMock;
  final VoidCallback onDenyMock;
  final VoidCallback onContinueMock;

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      background: const Color(0xFFE1E7ED),
      backLabel: 'Về nhận diện',
      children: [
        Semantics(
          header: true,
          child: Text(
            'Nhận diện tiền',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Camera chưa được bật.',
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
        const Spacer(),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.photo_camera_outlined,
                  color: AppColors.navy, size: 32),
              const SizedBox(height: 16),
              const Text(
                'Cho phép Nhận diện tiền\nsử dụng camera?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              AccessibleButton(
                key: const Key('grant_camera_button'),
                label: 'Trong khi dùng ứng dụng',
                primary: false,
                onPressed: onApproveMock,
              ),
              const SizedBox(height: 10),
              AccessibleButton(
                key: const Key('grant_camera_once_button'),
                label: 'Chỉ lần này',
                primary: false,
                onPressed: onApproveMock,
              ),
              const SizedBox(height: 10),
              AccessibleButton(
                key: const Key('deny_camera_button'),
                label: 'Không cho phép',
                primary: false,
                onPressed: onDenyMock,
              ),
              if (decision == MockPermissionDecision.denied) ...[
                const SizedBox(height: 20),
                const Text(
                  AppStrings.permissionDeniedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                AccessibleButton(
                  key: const Key('continue_without_camera_button'),
                  label: AppStrings.continueWithoutCamera,
                  onPressed: onContinueMock,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Chọn một quyền để tiếp tục.\nBản mô phỏng • chưa xin quyền hệ thống.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 24),
        const Spacer(),
      ],
    );
  }
}
