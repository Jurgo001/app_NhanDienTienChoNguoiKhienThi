import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/accessible_button.dart';

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
                        AppStrings.cameraPermissionTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.photo_camera_outlined,
                              color: AppColors.navy,
                              size: 42,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.permissionHeading,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.permissionDescription,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.permissionSteps,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    Container(
                      padding: const EdgeInsets.all(AppConstants.cardPadding),
                      decoration: BoxDecoration(
                        color: AppColors.paleYellow,
                        borderRadius:
                            BorderRadius.circular(AppConstants.cornerRadius),
                      ),
                      child: const Text(
                        AppStrings.permissionSimulation,
                        style: TextStyle(color: AppColors.navy, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    AccessibleButton(
                      key: const Key('grant_camera_button'),
                      label: AppStrings.grantCamera,
                      icon: Icons.check_circle_outline,
                      onPressed: onApproveMock,
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    AccessibleButton(
                      key: const Key('deny_camera_button'),
                      label: AppStrings.denyCamera,
                      primary: false,
                      onPressed: onDenyMock,
                    ),
                    if (decision == MockPermissionDecision.denied) ...[
                      const SizedBox(height: AppConstants.sectionGap),
                      Container(
                        padding: const EdgeInsets.all(AppConstants.cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.paleYellow,
                          borderRadius:
                              BorderRadius.circular(AppConstants.cornerRadius),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.permissionDeniedTitle,
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              AppStrings.permissionDeniedMessage,
                              style: TextStyle(
                                  color: AppColors.navy, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.itemGap),
                      AccessibleButton(
                        key: const Key('continue_without_camera_button'),
                        label: AppStrings.continueWithoutCamera,
                        onPressed: onContinueMock,
                      ),
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
