import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detection_result.dart';
import 'camera_service.dart';
import 'detector_service.dart';
import 'money_detector.dart';
import 'scan_backend.dart';

ScanBackend createScanBackend() => NativeScanBackend();

class NativeScanBackend extends ScanBackend {
  NativeScanBackend({CameraService? camera, DetectorService? detector})
      : camera = camera ?? CameraService(),
        detector = detector ?? MoneyDetector();
  final CameraService camera;
  final DetectorService detector;
  CameraController? _listenedCamera;
  VoidCallback? _errorListener;

  @override
  bool get isMock => false;
  @override
  CameraController? get cameraController => camera.controller;
  @override
  Future<CameraAccess> permission({bool request = false}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Nhận diện thật hiện hỗ trợ Android. '
          'Chạy trên Chrome để thử giao diện mô phỏng.');
    }
    var status = await Permission.camera.status;
    if (request && !status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) return CameraAccess.granted;
    return status.isPermanentlyDenied || status.isRestricted
        ? CameraAccess.permanentlyDenied
        : CameraAccess.denied;
  }

  @override
  Future<void> openPermissionSettings() async {
    if (!await openAppSettings()) {
      throw StateError(
          'Không mở được cài đặt. Mở Cài đặt → Ứng dụng → Quyền camera.');
    }
  }

  @override
  Future<void> initialize() async {
    final access = await permission(request: true);
    if (access != CameraAccess.granted) {
      throw StateError(access == CameraAccess.permanentlyDenied
          ? 'Camera bị chặn. Mở Quyền camera → Cài đặt ứng dụng để cấp lại.'
          : 'Chưa được cấp quyền camera. Mở Quyền camera để thử lại.');
    }
    if (!detector.isInitialized) await detector.initialize();
    if (!camera.isInitialized) await camera.initializeCamera();
  }

  @override
  Future<void> start(DetectionCallback onResult) async {
    final controller = camera.controller;
    if (controller != null) {
      _listenedCamera = controller;
      _errorListener = () {
        if (controller.value.hasError) {
          onResult(DetectionResult.error(
            controller.value.errorDescription ?? 'Camera gặp lỗi khi nhận ảnh.',
          ));
        }
      };
      controller.addListener(_errorListener!);
    }
    await camera.startStream((image, rotation) async {
      try {
        onResult(
            await detector.detectFrame(image, sensorOrientation: rotation));
      } catch (error) {
        onResult(DetectionResult.error('Lỗi xử lý khung hình: $error'));
      }
    });
  }

  @override
  Future<void> stop({bool releaseCamera = false}) async {
    if (_errorListener != null)
      _listenedCamera?.removeListener(_errorListener!);
    _listenedCamera = null;
    _errorListener = null;
    try {
      await camera.stopStream();
    } finally {
      if (releaseCamera) await camera.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await stop(releaseCamera: true);
    } finally {
      await detector.dispose();
    }
  }
}
