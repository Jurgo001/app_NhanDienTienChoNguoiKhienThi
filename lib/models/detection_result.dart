import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';

/// Trạng thái chi tiết của một lượt suy luận khung hình (Frame Inference).
enum DetectionStatus {
  /// Nhận diện thành công 1 tờ tiền rõ ràng, vượt ngưỡng tin cậy.
  detected,

  /// Không phát hiện tờ tiền nào trong khung hình.
  noMoney,

  /// Có dấu hiệu tờ tiền nhưng độ tin cậy thấp (mờ, rung tay, góc khuất).
  lowConfidence,

  /// Phát hiện từ 2 tờ tiền độc lập trở lên trong cùng khung hình.
  multipleNotes,

  /// Tờ tiền chiếm diện tích quá lớn (dí sát camera làm mất góc).
  tooClose,

  /// Tờ tiền quá nhỏ trong khung hình (cầm quá xa camera).
  tooFar,

  /// Môi trường thiếu sáng trầm trọng.
  tooDark,

  /// Ảnh bị cháy sáng / lóa đèn flash.
  tooBright,

  /// Khung hình đang bị bỏ qua do luồng inference trước chưa xong.
  skippedBusy,

  /// Lỗi kỹ thuật khi nạp hoặc chạy model TFLite.
  modelError,
}

/// Thông tin khung giới hạn (Bounding Box) đã chuẩn hóa về miền [0.0, 1.0].
class BoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final int classId;
  final String rawLabel;
  final double confidence;
  final Denomination? denomination;
  final BanknoteSide side;

  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.classId,
    required this.rawLabel,
    required this.confidence,
    this.denomination,
    this.side = BanknoteSide.unknown,
  });

  double get width => (x2 - x1).clamp(0.0, 1.0);
  double get height => (y2 - y1).clamp(0.0, 1.0);
  double get centerX => x1 + width / 2.0;
  double get centerY => y1 + height / 2.0;

  /// Tỷ lệ diện tích của box so với toàn bộ khung hình [0.0 - 1.0].
  double get areaRatio => (width * height).clamp(0.0, 1.0);

  @override
  String toString() {
    return 'BoundingBox(label: $rawLabel, conf: ${(confidence * 100).toStringAsFixed(1)}%, '
        'rect: [${x1.toStringAsFixed(2)}, ${y1.toStringAsFixed(2)}, '
        '${x2.toStringAsFixed(2)}, ${y2.toStringAsFixed(2)}])';
  }
}

/// DTO kết quả nhận diện trả về từ DetectorService (TV2) cho Controller (TV3).
class DetectionResult {
  /// Mệnh giá nhận diện được (null nếu chưa xác định hoặc có lỗi).
  final Denomination? denomination;

  /// Mặt trước hoặc mặt sau của tờ tiền.
  final BanknoteSide side;

  /// Độ tự tin từ 0.0 đến 1.0.
  final double confidence;

  /// Danh sách các BoundingBox sau khi đã lọc qua NMS.
  final List<BoundingBox> boxes;

  /// Trạng thái phân tích khung hình.
  final DetectionStatus status;

  /// Thông điệp gợi ý bằng tiếng Việt (phục vụ hướng dẫn giọng nói hoặc debug).
  final String? message;

  /// Thời gian chạy suy luận (ms).
  final int inferenceTimeMs;

  /// Thời điểm tạo kết quả.
  final DateTime timestamp;

  /// Đánh dấu kết quả này đến từ MockDetector hay TFLite thật.
  final bool isMock;

  /// Độ sáng trung bình của khung hình [0.0 - 255.0] nếu có đo.
  final double? brightness;

  DetectionResult({
    this.denomination,
    this.side = BanknoteSide.unknown,
    this.confidence = 0.0,
    this.boxes = const [],
    required this.status,
    this.message,
    this.inferenceTimeMs = 0,
    DateTime? timestamp,
    this.isMock = false,
    this.brightness,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Trả về true nếu đã nhận diện thành công một mệnh giá hợp lệ.
  bool get isRecognized =>
      status == DetectionStatus.detected && denomination != null;

  /// Factory tạo nhanh kết quả trống (không có tiền trong khung hình).
  factory DetectionResult.empty({
    int inferenceTimeMs = 0,
    double? brightness,
    bool isMock = false,
  }) {
    return DetectionResult(
      status: DetectionStatus.noMoney,
      message: 'Đưa một tờ tiền vào camera',
      inferenceTimeMs: inferenceTimeMs,
      brightness: brightness,
      isMock: isMock,
    );
  }

  /// Factory tạo nhanh kết quả lỗi.
  factory DetectionResult.error(String errorMsg, {bool isMock = false}) {
    return DetectionResult(
      status: DetectionStatus.modelError,
      message: errorMsg,
      isMock: isMock,
    );
  }

  @override
  String toString() {
    return 'DetectionResult(status: ${status.name}, '
        'denom: ${denomination?.displayText ?? "null"}, '
        'side: ${side.name}, '
        'conf: ${(confidence * 100).toStringAsFixed(1)}%, '
        'boxes: ${boxes.length}, '
        'time: ${inferenceTimeMs}ms, '
        'mock: $isMock)';
  }
}