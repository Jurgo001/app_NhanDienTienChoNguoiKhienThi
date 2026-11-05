import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/recognition_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/money_counting_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/haptic_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';

class _Speech extends SpeechService {
  final spoken = <String>[];
  @override
  Future<void> speak(String text,
      {SpeechRateOption rate = SpeechRateOption.normal,
      SpeechPriority priority = SpeechPriority.instruction}) async {
    spoken.add(text);
  }
}

class _Haptic extends HapticService {
  @override
  Future<void> vibrateSuccess() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Giữ một tờ trong khung nhiều frame không cộng trùng', () {
    final counter = MoneyCountingController();
    final speech = _Speech();
    var time = DateTime(2026, 1, 1);
    final recognizer = RecognitionController(
      speechService: speech,
      hapticService: _Haptic(),
      getSettings: () => const AppSettings(),
      clock: () => time,
      isMoneyCounting: () => true,
      onStableDenomination: counter.recordStableRecognition,
    );
    DetectionResult note() => DetectionResult(
          status: DetectionStatus.detected,
          denomination: Denomination.vnd100000,
          confidence: .95,
          isMock: true,
        );
    recognizer.startScanning();
    for (var i = 0; i < 10; i++) recognizer.processDetection(note());
    expect(counter.noteCount, 1);
    expect(counter.totalVnd, 100000);
    for (var i = 0; i < 4; i++) {
      recognizer.processDetection(DetectionResult.empty(isMock: true));
      time = time.add(const Duration(milliseconds: 300));
    }
    // 4 frame trống nhưng mới 900 ms: chưa cho lượt mới.
    expect(recognizer.state.status, RecognitionUiStatus.lockedAnnounced);
    time = time.add(const Duration(milliseconds: 300));
    recognizer.processDetection(DetectionResult.empty(isMock: true));
    expect(recognizer.state.status, RecognitionUiStatus.scanning);
    for (var i = 0; i < 3; i++) recognizer.processDetection(note());
    expect(counter.noteCount, 2);
    expect(counter.totalVnd, 200000);
    recognizer.dispose();
    counter.dispose();
  });

  test('Khi mới chuyển chế độ phải đợi camera trống rồi mới đếm', () {
    final counter = MoneyCountingController();
    var time = DateTime(2026, 1, 1);
    final recognizer = RecognitionController(
      speechService: _Speech(),
      hapticService: _Haptic(),
      getSettings: () => const AppSettings(),
      clock: () => time,
      isMoneyCounting: () => true,
      onStableDenomination: counter.recordStableRecognition,
    );
    DetectionResult note() => DetectionResult(
          status: DetectionStatus.detected,
          denomination: Denomination.vnd50000,
          confidence: .95,
          isMock: true,
        );
    recognizer.startScanning(requireClearBeforeAccept: true);
    for (var i = 0; i < 10; i++) recognizer.processDetection(note());
    expect(counter.noteCount, 0);
    for (var i = 0; i < 5; i++) {
      recognizer.processDetection(DetectionResult.empty(isMock: true));
      time = time.add(const Duration(milliseconds: 300));
    }
    for (var i = 0; i < 3; i++) recognizer.processDetection(note());
    expect(counter.noteCount, 1);
    recognizer.dispose();
    counter.dispose();
  });
}
