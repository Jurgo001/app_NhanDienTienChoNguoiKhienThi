import 'package:flutter_test/flutter_test.dart';

import 'package:app_ho_tro_nguoi_khiem_thi/controllers/recognition_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/haptic_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';

// Giả lập TTS để kiểm tra số lần đọc.
// Không cần phát âm thanh thật khi chạy unit test.
class FakeSpeechService extends SpeechService {
  int speakCount = 0;
  int stopCount = 0;
  String? lastSpokenText;

  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) async {
    speakCount++;
    lastSpokenText = text;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

// Giả lập rung để kiểm tra phản hồi thành công hoặc lỗi.
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

  // Tạo kết quả nhận diện giả lập để kiểm thử controller.
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

  // Gửi 3 frame liên tiếp cùng một mệnh giá.
  void sendStableFrames() {
    for (var i = 0; i < 3; i++) {
      controller.processDetection(result());
    }
  }

  // Khởi tạo lại controller và các dịch vụ giả trước mỗi test.
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

  // Giải phóng controller sau mỗi test.
  tearDown(() {
    controller.dispose();
  });

  // TEST 1: Trạng thái ban đầu.
  test('Trạng thái ban đầu là ready', () {
    expect(
      controller.state.status,
      RecognitionUiStatus.ready,
    );
  });

  // TEST 2: Chưa đủ 3 frame thì chưa công nhận mệnh giá.
  test('Chưa đủ 3 frame thì chưa xác nhận', () {
    controller.startScanning();

    controller.processDetection(result());
    controller.processDetection(result());

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );

    expect(speech.speakCount, 0);
    expect(haptic.successCount, 0);
  });

  // TEST 3: Đủ 3 frame thì xác nhận và đọc mệnh giá.
  test('Đủ 3 frame thì xác nhận mệnh giá', () {
    controller.startScanning();

    sendStableFrames();

    expect(
      controller.state.status,
      RecognitionUiStatus.lockedAnnounced,
    );

    // Dùng giá trị từ enum để tránh sai định dạng tiền.
    expect(
      controller.state.denomination,
      Denomination.vnd100000.displayText,
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

  // TEST 4: Khi đã khóa kết quả, không đọc lặp cùng một tờ.
  test('Không tự đọc lặp trong cùng một phiên', () {
    controller.startScanning();

    sendStableFrames();

    // Camera vẫn nhìn thấy tờ tiền trong 5 frame tiếp theo.
    for (var i = 0; i < 5; i++) {
      controller.processDetection(result());
    }

    expect(
      controller.state.status,
      RecognitionUiStatus.lockedAnnounced,
    );

    expect(speech.speakCount, 1);
    expect(haptic.successCount, 1);
  });

  // TEST 5: Confidence thấp không được xác nhận.
  test('Confidence thấp không được xác nhận', () {
    controller.startScanning();

    for (var i = 0; i < 5; i++) {
      controller.processDetection(
        result(confidence: 0.40),
      );
    }

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );

    expect(
      speech.lastSpokenText,
      'Xin giữ yên tay',
    );
  });

  // TEST 6: Đổi mệnh giá giữa các frame phải đếm lại từ đầu.
  test('Đổi mệnh giá giữa các frame sẽ reset bộ đếm', () {
    controller.startScanning();

    controller.processDetection(result());

    controller.processDetection(
      result(
        denomination: Denomination.vnd200000,
      ),
    );

    controller.processDetection(result());

    // Chưa đủ 3 frame liên tiếp của 100.000đ.
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

    expect(
      controller.state.denomination,
      Denomination.vnd100000.displayText,
    );

    expect(speech.speakCount, 1);
  });

  // TEST 7: Khi người dùng tắt rung thì không rung.
  test('Tắt rung thì không rung', () {
    settings = const AppSettings(
      vibrationEnabled: false,
    );

    controller.startScanning();
    sendStableFrames();

    expect(haptic.successCount, 0);
    expect(speech.speakCount, 1);
  });

  // TEST 8: Lỗi model phải chuyển sang trạng thái error.
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
    expect(speech.speakCount, 0);
  });

  // TEST 9: Không đọc lặp khi camera chưa phát hiện tiền.
  test('Không đọc lặp khi không phát hiện tiền', () {
    controller.startScanning();

    // Mô phỏng camera xử lý 15 frame không nhìn thấy tiền.
    for (var i = 0; i < 15; i++) {
      controller.processDetection(
        DetectionResult.empty(isMock: true),
      );
    }

    expect(
      controller.state.status,
      RecognitionUiStatus.scanning,
    );

    // startScanning() chỉ đổi trạng thái.
    // Trong ứng dụng thật, ScanSession sẽ gọi lời nhắc đầu lượt.
    // Các frame noMoney không được tạo thêm lời đọc.
    expect(speech.speakCount, 0);
  });
}
