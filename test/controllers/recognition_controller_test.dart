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

  test('Tráº¡ng thÃ¡i ban Ä‘áº§u lÃ  ready', () {
    expect(
      controller.state.status,
      RecognitionUiStatus.ready,
    );
  });

  test('ChÆ°a Ä‘á»§ 3 frame thÃ¬ chÆ°a xÃ¡c nháº­n', () {
    controller.startScanning();

    controller.processDetection(result());
    controller.processDetection(result());

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );

    expect(speech.speakCount, 0);
  });

  test('Äá»§ 3 frame thÃ¬ xÃ¡c nháº­n má»‡nh giÃ¡', () {
    controller.startScanning();
    sendStableFrames();

    expect(
      controller.state.status,
      RecognitionUiStatus.lockedAnnounced,
    );
    expect(
      controller.state.denomination,
      '100.000 VNÄ',
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

  test('KhÃ´ng tá»± Ä‘á»c láº·p trong cÃ¹ng má»™t phiÃªn', () {
    controller.startScanning();
    sendStableFrames();

    for (var i = 0; i < 5; i++) {
      controller.processDetection(result());
    }

    expect(speech.speakCount, 1);
    expect(haptic.successCount, 1);
  });

  test('Confidence tháº¥p khÃ´ng Ä‘Æ°á»£c xÃ¡c nháº­n', () {
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
    expect(speech.lastSpokenText, 'Xin giá»¯ yÃªn tay');
  });

  test('Äá»•i má»‡nh giÃ¡ giá»¯a cÃ¡c frame sáº½ reset bá»™ Ä‘áº¿m', () {
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
      RecognitionUiStatus.lockedAnnounced,
    );
  });

  test('Táº¯t rung thÃ¬ khÃ´ng rung', () {
    settings = const AppSettings(
      vibrationEnabled: false,
    );

    controller.startScanning();
    sendStableFrames();

    expect(haptic.successCount, 0);
    expect(speech.speakCount, 1);
  });

  test('Lá»—i model chuyá»ƒn sang tráº¡ng thÃ¡i error', () {
    controller.startScanning();

    controller.processDetection(
      DetectionResult.error(
        'KhÃ´ng thá»ƒ táº£i model',
        isMock: true,
      ),
    );

    expect(
      controller.state.status,
      RecognitionUiStatus.error,
    );
    expect(haptic.errorCount, 1);
  });
}
