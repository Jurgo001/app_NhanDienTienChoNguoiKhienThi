import 'package:camera/camera.dart';
import '../models/detection_result.dart';

enum CameraAccess { granted, denied, permanentlyDenied, notRequired }

typedef DetectionCallback = void Function(DetectionResult result);

/// Hợp đồng dùng chung: Android chạy camera/TFLite, Web chạy mẫu mô phỏng.
abstract class ScanBackend {
  bool get isMock;
  CameraController? get cameraController => null;
  Future<CameraAccess> permission({bool request = false});
  Future<void> openPermissionSettings();
  Future<void> initialize();
  Future<void> start(DetectionCallback onResult);

  /// Dừng nhận frame và đợi frame đang xử lý trước khi trả về.
  Future<void> stop({bool releaseCamera = false});
  Future<void> dispose();
}
