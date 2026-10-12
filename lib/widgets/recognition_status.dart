import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../core/models/recognition_ui_state.dart';

class RecognitionStatus extends StatelessWidget {
  const RecognitionStatus({super.key, required this.state});

  final RecognitionUiState state;

  @override
  Widget build(BuildContext context) {
    final title = switch (state.status) {
      RecognitionUiStatus.ready => AppStrings.readyTitle,
      RecognitionUiStatus.scanning => AppStrings.scanningTitle,
      RecognitionUiStatus.recognized => AppStrings.recognizedTitle,
      RecognitionUiStatus.unclear => AppStrings.unclearTitle,
      RecognitionUiStatus.error => AppStrings.errorTitle,
    };
    final defaultMessage = switch (state.status) {
      RecognitionUiStatus.ready => AppStrings.readyMessage,
      RecognitionUiStatus.scanning => state.isMock
          ? AppStrings.scanningMessage
          : AppStrings.scanningRealMessage,
      RecognitionUiStatus.recognized => state.isMock
          ? AppStrings.recognizedMessage
          : AppStrings.recognizedRealMessage,
      RecognitionUiStatus.unclear => AppStrings.unclearMessage,
      RecognitionUiStatus.error =>
        state.isMock ? AppStrings.errorMessage : AppStrings.errorRealMessage,
    };
    final message = state.guidance ?? defaultMessage;
    final icon = switch (state.status) {
      RecognitionUiStatus.ready => Icons.check_circle_outline,
      RecognitionUiStatus.scanning => Icons.center_focus_strong,
      RecognitionUiStatus.recognized => Icons.verified_outlined,
      RecognitionUiStatus.unclear => Icons.warning_amber_rounded,
      RecognitionUiStatus.error => Icons.error_outline,
    };
    final background = switch (state.status) {
      RecognitionUiStatus.ready => AppColors.paleBlue,
      RecognitionUiStatus.scanning => AppColors.paleBlue,
      RecognitionUiStatus.recognized => AppColors.paleGreen,
      RecognitionUiStatus.unclear => AppColors.paleYellow,
      RecognitionUiStatus.error => AppColors.paleRed,
    };
    final foreground = switch (state.status) {
      RecognitionUiStatus.ready => AppColors.navy,
      RecognitionUiStatus.scanning => AppColors.navy,
      RecognitionUiStatus.recognized => AppColors.success,
      RecognitionUiStatus.unclear => AppColors.warning,
      RecognitionUiStatus.error => AppColors.error,
    };

    return Semantics(
      container: true,
      label: 'Trạng thái: $title. $message',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
