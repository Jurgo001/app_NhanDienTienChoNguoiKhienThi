import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
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
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              if (hasResult && isMock) ...[
                const Text(
                  AppStrings.mockResultLabel,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                hasResult ? denomination! : emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasResult ? AppColors.yellow : Colors.white,
                  fontSize: hasResult ? 38 : 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (hasResult && denomination == AppStrings.mockDenomination) ...[
                const SizedBox(height: 6),
                const Text(
                  'Một trăm nghìn đồng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
