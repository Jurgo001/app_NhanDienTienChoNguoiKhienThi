import 'package:camera/camera.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';

/// Giao diện hợp đồng chung cho bộ nhận diện tiền (Thật và Mock).
/// TV3 chỉ cần gọi qua interface này trong RecognitionController.
abstract class DetectorService {
  /// Trả về true nếu model đã được nạp thành công và sẵn sàng suy luận.
  bool get isInitialized;

  /// Trả về true nếu đang bận xử lý một khung hình.
  bool get isBusy;

  /// Thông tin tóm tắt về model (tên file, input/output shape, chế độ).
  String get modelInfo;

  /// Khởi tạo tài nguyên (nạp file .tflite và cấp phát tensor).
  Future<void> initialize();

  /// Nhận một khung hình từ luồng Camera và trả về kết quả [DetectionResult].
  Future<DetectionResult> detectFrame(
    CameraImage cameraImage, {
    int sensorOrientation = 90,
  });

  /// Giải phóng bộ nhớ Interpreter khi đóng màn hình hoặc thoát ứng dụng.
  Future<void> dispose();
}