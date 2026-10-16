import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/mobile_page.dart';

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
    return MobilePage(
      backLabel: 'Về Menu',
      children: [
        Semantics(
          header: true,
          child: Text(
            AppStrings.guideHeading,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 26),
        const _GuideStep(
          number: 1,
          title: 'Đưa tờ tiền',
          detail: 'Đặt một tờ tiền trước camera sau.',
        ),
        const _GuideStep(
          number: 2,
          title: 'Giữ yên điện thoại',
          detail:
              'Bấm Bắt đầu quét, cấp quyền camera rồi giữ yên để ứng dụng nhận diện.',
        ),
        const _GuideStep(
          number: 3,
          title: 'Nghe kết quả',
          detail:
              'Bấm “Đọc lại” khi cần. Chọn “Quét lại” để nhận diện tờ khác, hoặc chờ phiên mới sau 15 giây.',
        ),
        const Spacer(),
        const SizedBox(height: 24),
        AccessibleButton(
          key: const Key('listen_guide_button'),
          label: AppStrings.listenGuide,
          icon: Icons.volume_up_outlined,
          primary: false,
          onPressed: onListen,
        ),
        const SizedBox(height: 14),
        AccessibleButton(
          key: const Key('start_recognition_button'),
          label: 'Bắt đầu nhận diện',
          icon: Icons.photo_camera_outlined,
          onPressed: onStartRecognition,
        ),
      ],
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
          padding: const EdgeInsets.only(bottom: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        height: 1.5,
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
