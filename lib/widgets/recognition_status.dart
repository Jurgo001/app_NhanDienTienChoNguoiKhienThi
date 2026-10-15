import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
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
    final message = state.guidance ??
        switch (state.status) {
          RecognitionUiStatus.ready => AppStrings.readyMessage,
          RecognitionUiStatus.scanning => state.isMock
              ? AppStrings.scanningMessage
              : AppStrings.scanningRealMessage,
          RecognitionUiStatus.recognized => state.isMock
              ? AppStrings.recognizedMessage
              : AppStrings.recognizedRealMessage,
          RecognitionUiStatus.unclear => AppStrings.unclearMessage,
          RecognitionUiStatus.error => state.isMock
              ? AppStrings.errorMessage
              : AppStrings.errorRealMessage,
        };
    final warning = state.status == RecognitionUiStatus.unclear ||
        state.status == RecognitionUiStatus.error;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Trạng thái: $title. $message',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: warning ? AppColors.yellow : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (warning) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
