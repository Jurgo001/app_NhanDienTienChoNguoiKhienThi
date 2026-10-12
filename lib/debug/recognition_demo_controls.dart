import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

class RecognitionDemoControls extends StatelessWidget {
  const RecognitionDemoControls({
    super.key,
    required this.onRecognized,
    required this.onUnclear,
    required this.onError,
  });

  final VoidCallback onRecognized;
  final VoidCallback onUnclear;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.navy,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      minimumSize: const Size(
        AppConstants.touchTargetMinSize,
        AppConstants.touchTargetMinSize,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.paleBlue,
        borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.demoTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.demoDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppConstants.itemGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('demo_recognized_button'),
                style: buttonStyle,
                onPressed: onRecognized,
                child: const Text(AppStrings.demoRecognized),
              ),
              OutlinedButton(
                key: const Key('demo_unclear_button'),
                style: buttonStyle,
                onPressed: onUnclear,
                child: const Text(AppStrings.demoUnclear),
              ),
              OutlinedButton(
                key: const Key('demo_error_button'),
                style: buttonStyle,
                onPressed: onError,
                child: const Text(AppStrings.demoError),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
