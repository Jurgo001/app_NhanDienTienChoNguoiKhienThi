import 'package:camera/camera.dart';
import '../models/detection_result.dart';

enum CameraAccess { granted, denied, permanentlyDenied, notRequired }

typedef DetectionCallback = void Function(DetectionResult result);

/// Hợp đồng dùng chung: Android chạy camera/TFLite, Web chạy mẫu mô phỏng.
abstract class ScanBackend {
  // Chuyển thông báo bật/tắt flash lên lớp quản lý giọng nói.
  // Backend chỉ gửi nội dung, không trực tiếp điều khiển TTS.
  void Function(String message)? onFlashAnnouncement;

  bool get isMock;
  CameraController? get cameraController => null;
  Future<CameraAccess> permission({bool request = false});
  Future<void> openPermissionSettings();
  Future<void> initialize();
  Future<void> start(DetectionCallback onResult);

  /// Allows native backends to slow scanning after a result is announced.
  void setRecognitionLocked(bool locked) {}

  /// Dừng nhận frame và đợi frame đang xử lý trước khi trả về.
  Future<void> stop({bool releaseCamera = false});
  Future<void> dispose();
}
