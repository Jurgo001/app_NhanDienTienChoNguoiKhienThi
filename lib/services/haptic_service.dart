import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  /// Rung khi nhận diện thành công.
  Future<void> vibrateSuccess() async {
    if (kIsWeb) return;
    final hasVibrator = await Vibration.hasVibrator();

    if (!hasVibrator) return;

    await Vibration.vibrate(duration: 150);
  }

  /// Rung khi nhận diện thất bại.
  Future<void> vibrateError() async {
    final hasVibrator = await Vibration.hasVibrator();

    if (!hasVibrator) return;

    await Vibration.vibrate(
      pattern: [0, 100, 100, 100],
    );
  }

  /// Dừng rung.
  Future<void> stop() async {
    if (!kIsWeb) await Vibration.cancel();
  }
}
