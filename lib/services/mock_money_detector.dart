import 'package:camera/camera.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/detector_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/image_quality_service.dart';

/// Các kịch bản giả lập phục vụ kiểm thử cho TV1, TV2 và TV3.
enum MockScenario {
  /// Xoay vòng lần lượt qua 9 mệnh giá sau mỗi vài khung hình.
  cycleAllDenominations,

  /// Luôn trả về tờ 50.000 VNĐ rõ nét (Confidence 94%).
  fixed50k,

  /// Giả lập ảnh bị rung mờ (Confidence 62% -> nhắc giữ yên tay).
  lowConfidenceBlur,

  /// Giả lập không có tờ tiền nào trong khung hình.
  noMoney,

  /// Giả lập phát hiện 2 tờ tiền cùng lúc.
  multipleNotes,

  /// Giả lập môi trường quá tối.
  tooDark,
}

/// Bộ nhận diện giả lập phục vụ kiểm thử độc lập với TFLite.
/// Luôn đánh dấu [isMock] = true để không nhầm với kết quả AI thật.
class MockMoneyDetector implements DetectorService {
  MockScenario scenario;
  final int simulatedDelayMs;

  bool _isInitialized = false;
  bool _isBusy = false;
  int _frameCounter = 0;

  MockMoneyDetector({
    this.scenario = MockScenario.cycleAllDenominations,
    this.simulatedDelayMs = 60,
  });

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isBusy => _isBusy;

  @override
  String get modelInfo => 'MOCK DETECTOR (${scenario.name}) - Dữ liệu mô phỏng';

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _isInitialized = true;
  }

  @override
  Future<DetectionResult> detectFrame(
    CameraImage cameraImage, {
    int sensorOrientation = 90,
  }) async {
    if (!_isInitialized) {
      return DetectionResult.error(
        '[MOCK] Chưa gọi initialize()',
        isMock: true,
      );
    }

    if (_isBusy) {
      return DetectionResult(
        status: DetectionStatus.skippedBusy,
        message: '[MOCK] Đang bận xử lý frame trước',
        isMock: true,
      );
    }

    _isBusy = true;
    try {
      await Future<void>.delayed(Duration(milliseconds: simulatedDelayMs));
      _frameCounter++;
      return buildMockResult();
    } finally {
      _isBusy = false;
    }
  }

  /// Tạo kết quả giả lập trực tiếp (có thể gọi khi test không cần mở Camera).
  DetectionResult buildMockResult() {
    switch (scenario) {
      case MockScenario.noMoney:
        return DetectionResult.empty(
          inferenceTimeMs: simulatedDelayMs,
          brightness: 130.0,
          isMock: true,
        );

      case MockScenario.tooDark:
        return DetectionResult(
          status: DetectionStatus.tooDark,
          message: '[MOCK] ${ImageQualityService.getGuidanceMessage(DetectionStatus.tooDark)}',
          inferenceTimeMs: simulatedDelayMs,
          brightness: 18.0,
          isMock: true,
        );

      case MockScenario.lowConfidenceBlur:
        const box = BoundingBox(
          x1: 0.18,
          y1: 0.28,
          x2: 0.82,
          y2: 0.72,
          classId: 13,
          rawLabel: '50000_mattruoc',
          confidence: 0.62,
          denomination: Denomination.vnd50000,
          side: BanknoteSide.front,
        );
        return DetectionResult(
          denomination: Denomination.vnd50000,
          side: BanknoteSide.front,
          confidence: 0.62,
          boxes: const [box],
          status: DetectionStatus.lowConfidence,
          message: '[MOCK] ${ImageQualityService.getGuidanceMessage(DetectionStatus.lowConfidence)}',
          inferenceTimeMs: simulatedDelayMs,
          brightness: 120.0,
          isMock: true,
        );

      case MockScenario.multipleNotes:
        const box1 = BoundingBox(
          x1: 0.05,
          y1: 0.15,
          x2: 0.48,
          y2: 0.55,
          classId: 1,
          rawLabel: '10000_mattruoc',
          confidence: 0.91,
          denomination: Denomination.vnd10000,
          side: BanknoteSide.front,
        );
        const box2 = BoundingBox(
          x1: 0.52,
          y1: 0.40,
          x2: 0.95,
          y2: 0.85,
          classId: 5,
          rawLabel: '100k_mattruoc',
          confidence: 0.89,
          denomination: Denomination.vnd100000,
          side: BanknoteSide.front,
        );
        return DetectionResult(
          status: DetectionStatus.multipleNotes,
          boxes: const [box1, box2],
          confidence: 0.91,
          message: '[MOCK] ${ImageQualityService.getGuidanceMessage(DetectionStatus.multipleNotes)}',
          inferenceTimeMs: simulatedDelayMs,
          brightness: 135.0,
          isMock: true,
        );

      case MockScenario.fixed50k:
        return _createDetectedMock(Denomination.vnd50000, BanknoteSide.front);

      case MockScenario.cycleAllDenominations:
        final all = Denomination.values;
        // Đổi mệnh giá sau mỗi 15 lượt quét để dễ quan sát ổn định nhiều frame
        final index = (_frameCounter ~/ 15) % all.length;
        final side = (_frameCounter % 2 == 0)
            ? BanknoteSide.front
            : BanknoteSide.back;
        return _createDetectedMock(all[index], side);
    }
  }

  DetectionResult _createDetectedMock(
    Denomination denomination,
    BanknoteSide side,
  ) {
    final box = BoundingBox(
      x1: 0.12,
      y1: 0.25,
      x2: 0.88,
      y2: 0.75,
      classId: 0,
      rawLabel: '${denomination.value}_${side.name}',
      confidence: 0.94,
      denomination: denomination,
      side: side,
    );

    return DetectionResult(
      denomination: denomination,
      side: side,
      confidence: 0.94,
      boxes: [box],
      status: DetectionStatus.detected,
      message: '[MOCK] ${denomination.displayText} (${side.label})',
      inferenceTimeMs: simulatedDelayMs,
      brightness: 140.0,
      isMock: true,
    );
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _isBusy = false;
  }
}