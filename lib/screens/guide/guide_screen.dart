import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/mobile_page.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({
    super.key,
    required this.onAutoRead,
    required this.onReadCompleted,
    this.screenReaderActive = false,
    this.onBack,
  });
  final Future<void> Function() onAutoRead;
  final VoidCallback onReadCompleted;
  final bool screenReaderActive;
  final VoidCallback? onBack;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  bool _userInteracted = false;
  String? _speechError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_readGuide());
    });
  }

  Future<void> _readGuide() async {
    try {
      await widget.onAutoRead();
      if (!mounted || _userInteracted) return;
      // Screen reader users need to control their own navigation.
      if (widget.screenReaderActive ||
          MediaQuery.of(context).accessibleNavigation) return;
      widget.onReadCompleted();
    } catch (error) {
      if (mounted) {
        setState(() => _speechError =
            'Không thể phát hướng dẫn. Kiểm tra giọng tiếng Việt và âm lượng.');
      }
      debugPrint('Guide TTS: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _userInteracted = true,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification ||
              notification is UserScrollNotification) {
            _userInteracted = true;
          }
          return false;
        },
        child: MobilePage(
          backLabel: 'Quay lại',
          onBack: widget.onBack,
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
                  'Ứng dụng tự mở camera và nhận diện khi camera cùng giọng nói đã sẵn sàng.',
            ),
            const _GuideStep(
              number: 3,
              title: 'Nghe kết quả',
              detail:
                  'Ứng dụng tự động đọc mệnh giá. Đưa tờ tiền ra khỏi camera để quét tờ tiếp theo (hoặc đưa vào lại nếu chưa nghe rõ).',
            ),
            const SizedBox(height: 8),
            const Divider(height: 32, color: AppColors.border),
            Semantics(
              header: true,
              child: Text(
                'Điều khiển chế độ và âm lượng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 20),
            const _GuideStep(
              number: 4,
              title: 'Chuyển chế độ',
              detail:
                  'Chọn nút Chuyển sang đếm tiền hoặc Chuyển sang nhận diện tiền trên màn hình camera. Tổng đã đếm luôn được giữ lại khi đổi chế độ.',
            ),
            const _GuideStep(
              number: 5,
              title: 'Tạo phiên đếm mới',
              detail:
                  'Trong chế độ Đếm tiền, chọn Bắt đầu phiên đếm mới rồi xác nhận. Nếu muốn giữ tổng hiện tại, chọn Hủy.',
            ),
            const _GuideStep(
              number: 6,
              title: 'Phím âm lượng',
              detail:
                  'Mặc định, nhấn hoặc giữ phím cộng và trừ để chỉnh âm lượng bình thường. Trong Tùy chọn có thể bật phím tắt giữ ba giây, nhưng khi bật sẽ không giữ phím để chỉnh âm lượng liên tục. Nếu muốn nghe lại mệnh giá, đưa tờ tiền ra khỏi camera, rồi đưa vào lại.',
            ),
            if (_speechError != null)
              Semantics(
                liveRegion: true,
                child: Text(_speechError!,
                    style: const TextStyle(color: AppColors.navy)),
              ),
            const SizedBox(height: 40),
          ],
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
