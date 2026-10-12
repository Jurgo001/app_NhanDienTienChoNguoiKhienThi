import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Vẽ bốn góc căn chỉnh; không đọc hay xử lý khung hình camera.
class CameraFrame extends StatelessWidget {
  const CameraFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CornerFramePainter(),
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Center(child: child),
      ),
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  const _CornerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 16.0;
    const length = 30.0;
    final left = inset;
    final right = size.width - inset;
    final top = inset;
    final bottom = size.height - inset;

    for (final path in [
      Path()
        ..moveTo(left, top + length)
        ..lineTo(left, top)
        ..lineTo(left + length, top),
      Path()
        ..moveTo(right - length, top)
        ..lineTo(right, top)
        ..lineTo(right, top + length),
      Path()
        ..moveTo(left, bottom - length)
        ..lineTo(left, bottom)
        ..lineTo(left + length, bottom),
      Path()
        ..moveTo(right - length, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, bottom - length),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerFramePainter oldDelegate) => false;
}
