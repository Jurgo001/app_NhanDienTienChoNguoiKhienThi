import 'package:flutter_test/flutter_test.dart';

import 'package:app_ho_tro_nguoi_khiem_thi/controllers/recognition_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/haptic_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';

class FakeSpeechService extends SpeechService {
  int speakCount = 0;
  int stopCount = 0;
  String? lastSpokenText;

  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
  }) async {
    speakCount++;
    lastSpokenText = text;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class FakeHapticService extends HapticService {
  int successCount = 0;
  int errorCount = 0;

  @override
  Future<void> vibrateSuccess() async {
    successCount++;
  }

  @override
  Future<void> vibrateError() async {
    errorCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecognitionController controller;
  late FakeSpeechService speech;
  late FakeHapticService haptic;

  AppSettings settings = const AppSettings();

  DetectionResult result({
    Denomination denomination = Denomination.vnd100000,
    double confidence = 0.95,
  }) {
    return DetectionResult(
      status: DetectionStatus.detected,
      denomination: denomination,
      confidence: confidence,
      isMock: true,
    );
  }

  void sendStableFrames() {
    for (var i = 0; i < 3; i++) {
      controller.processDetection(result());
    }
  }

  setUp(() {
    settings = const AppSettings();
    speech = FakeSpeechService();
    haptic = FakeHapticService();

    controller = RecognitionController(
      speechService: speech,
      hapticService: haptic,
      getSettings: () => settings,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('Trạng thái ban đầu là ready', () {
    expect(
      controller.state.status,
      RecognitionUiStatus.ready,
    );
  });

  test('Chưa đủ 3 frame thì chưa xác nhận', () {
    controller.startScanning();

    controller.processDetection(result());
    controller.processDetection(result());

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );

    expect(speech.speakCount, 0);
  });

  test('Đủ 3 frame thì xác nhận mệnh giá', () {
    controller.startScanning();
    sendStableFrames();

    expect(
      controller.state.status,
      RecognitionUiStatus.recognized,
    );
    expect(
      controller.state.denomination,
      '100.000 VNĐ',
    );
    expect(
      speech.speakCount,
      1,
    );
    expect(
      haptic.successCount,
      1,
    );
  });

  test('Không tự đọc lặp trong cùng một phiên', () {
    controller.startScanning();
    sendStableFrames();

    for (var i = 0; i < 5; i++) {
      controller.processDetection(result());
    }

    expect(speech.speakCount, 1);
    expect(haptic.successCount, 1);
  });

  test('Confidence thấp không được xác nhận', () {
    controller.startScanning();

    for (var i = 0; i < 5; i++) {
      controller.processDetection(
        result(confidence: 0.4),
      );
    }

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );
    expect(speech.lastSpokenText, 'Xin giữ yên tay');
  });

  test('Đổi mệnh giá giữa các frame sẽ reset bộ đếm', () {
    controller.startScanning();

    controller.processDetection(result());
    controller.processDetection(
      result(denomination: Denomination.vnd200000),
    );
    controller.processDetection(result());

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );

    controller.processDetection(result());
    controller.processDetection(result());

    expect(
      controller.state.status,
      RecognitionUiStatus.recognized,
    );
  });

  test('Đọc lại chỉ đọc kết quả hiện tại', () async {
    controller.startScanning();
    sendStableFrames();

    await controller.replayResult();

    expect(speech.speakCount, 2);
    expect(
      speech.lastSpokenText,
      'Kết quả mô phỏng. Một trăm nghìn đồng',
    );
  });

  test('Quét lại xóa kết quả và cho phép nhận diện mới', () async {
    controller.startScanning();
    sendStableFrames();

    await controller.resetScan();

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );
    expect(controller.state.hasResult, false);
    expect(speech.stopCount, 1);

    sendStableFrames();

    expect(speech.speakCount, 2);
  });

  test('Tắt tự động đọc thì không phát TTS', () {
    settings = const AppSettings(
      autoReadEnabled: false,
    );

    controller.startScanning();
    sendStableFrames();

    expect(speech.speakCount, 0);
    expect(haptic.successCount, 1);
  });

  test('Tắt rung thì không rung', () {
    settings = const AppSettings(
      vibrationEnabled: false,
    );

    controller.startScanning();
    sendStableFrames();

    expect(haptic.successCount, 0);
    expect(speech.speakCount, 1);
  });

  test('Lỗi model chuyển sang trạng thái error', () {
    controller.startScanning();

    controller.processDetection(
      DetectionResult.error(
        'Không thể tải model',
        isMock: true,
      ),
    );

    expect(
      controller.state.status,
      RecognitionUiStatus.error,
    );
    expect(haptic.errorCount, 1);
  });

  test('Không có kết quả thì không đọc lại', () async {
    await controller.replayResult();

    expect(speech.speakCount, 0);
  });
}
