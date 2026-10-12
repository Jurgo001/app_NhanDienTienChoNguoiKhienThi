import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

class DenominationCard extends StatelessWidget {
  const DenominationCard({
    super.key,
    required this.denomination,
    required this.isMock,
    this.emptyMessage = AppStrings.noResult,
  });

  final String? denomination;
  final bool isMock;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final hasResult = denomination != null && denomination!.isNotEmpty;
    final label = hasResult
        ? '${isMock ? '${AppStrings.mockResultLabel}: ' : '${AppStrings.resultTitle}: '}$denomination'
        : emptyMessage;

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasResult && isMock
                    ? AppStrings.mockResultLabel
                    : AppStrings.resultTitle,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasResult ? denomination! : emptyMessage,
                style: TextStyle(
                  color: hasResult ? AppColors.yellow : AppColors.surface,
                  fontSize: hasResult ? 42 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
