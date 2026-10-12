import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/accessible_button.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({
    super.key,
    required this.onListen,
    required this.onStartRecognition,
  });

  final VoidCallback onListen;
  final VoidCallback onStartRecognition;

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
                        AppStrings.guideHeading,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppConstants.sectionGap),
                    const _GuideStep(
                      number: 1,
                      title: AppStrings.guideStep1Title,
                      detail: AppStrings.guideStep1Detail,
                    ),
                    const _GuideStep(
                      number: 2,
                      title: AppStrings.guideStep2Title,
                      detail: AppStrings.guideStep2Detail,
                    ),
                    const _GuideStep(
                      number: 3,
                      title: AppStrings.guideStep3Title,
                      detail: AppStrings.guideStep3Detail,
                    ),
                    const _GuideStep(
                      number: 4,
                      title: AppStrings.guideStep4Title,
                      detail: AppStrings.guideStep4Detail,
                    ),
                    const _GuideStep(
                      number: 5,
                      title: AppStrings.guideStep5Title,
                      detail: AppStrings.guideStep5Detail,
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    AccessibleButton(
                      key: const Key('listen_guide_button'),
                      label: AppStrings.listenGuide,
                      icon: Icons.volume_up_outlined,
                      primary: false,
                      onPressed: onListen,
                    ),
                    const SizedBox(height: AppConstants.itemGap),
                    AccessibleButton(
                      label: AppStrings.returnToRecognition,
                      icon: Icons.center_focus_strong,
                      onPressed: onStartRecognition,
                    ),
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

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final int number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Bước $number. $title. $detail',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.sectionGap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AppColors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodyLarge),
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
