import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback nhận khung hình từ Camera kèm góc xoay cảm biến.
typedef FrameCallback = Future<void> Function(
  CameraImage image,
  int sensorOrientation,
);

/// Dịch vụ quản lý Camera Stream và vòng đời phần cứng cho Android.
class CameraService {
  CameraController? _controller;
  CameraDescription? _backCamera;
  FrameCallback? _onFrameCallback;

  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Khoảng nghỉ tối thiểu giữa 2 lần đẩy frame vào AI (mặc định 120ms ~ 8 FPS).
  /// Giúp điện thoại không bị nóng và không tràn bộ nhớ.
  final int minFrameIntervalMs;

  CameraService({this.minFrameIntervalMs = 120});

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isStreaming => _isStreaming;

  int get sensorOrientation => _backCamera?.sensorOrientation ?? 90;

  /// Kiểm tra và yêu cầu quyền truy cập Camera trên Android.
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Khởi tạo Camera sau với độ phân giải Medium và hệ màu YUV420 chuẩn Android.
  Future<void> initializeCamera({
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    final hasPermission = await requestCameraPermission();
    if (!hasPermission) {
      throw CameraException(
        'permissionDenied',
        'Quyền truy cập Camera bị từ chối.',
      );
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException(
        'noCameraAvailable',
        'Không tìm thấy thiết bị Camera trên máy.',
      );
    }

    _backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    await _disposeControllerOnly();

    final controller = CameraController(
      _backCamera!,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    _controller = controller;
    debugPrint(
      '✅ [CameraService] Đã mở Camera: ${_backCamera!.name}, '
      'sensorOrientation: ${_backCamera!.sensorOrientation}°',
    );
  }

  /// Bắt đầu luồng nhận khung hình liên tục kèm bộ khóa van chống tràn frame.
  Future<void> startStream(FrameCallback onFrame) async {
    if (!isInitialized || _controller == null) {
      throw StateError('Camera chưa được khởi tạo trước khi gọi startStream.');
    }
    if (_isStreaming) return;

    _onFrameCallback = onFrame;
    _isStreaming = true;

    await _controller!.startImageStream((CameraImage image) async {
      if (!_isStreaming || _isProcessingFrame) return;

      final now = DateTime.now();
      if (now.difference(_lastFrameTime).inMilliseconds < minFrameIntervalMs) {
        return;
      }

      _isProcessingFrame = true;
      _lastFrameTime = now;

      try {
        await onFrame(image, sensorOrientation);
      } catch (e) {
        debugPrint('⚠️ [CameraService] Lỗi xử lý frame: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  /// Tạm dừng luồng nhận khung hình.
  Future<void> stopStream() async {
    if (!_isStreaming || _controller == null) return;
    _isStreaming = false;
    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (e) {
      debugPrint('⚠️ [CameraService] Lỗi khi dừng stream: $e');
    }
  }

  /// Xử lý tự động đóng/mở lại Camera khi ứng dụng chuyển xuống nền hoặc bật lên.
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      await stopStream();
      await _disposeControllerOnly();
    } else if (state == AppLifecycleState.resumed) {
      await initializeCamera();
      if (_onFrameCallback != null) {
        await startStream(_onFrameCallback!);
      }
    }
  }

  Future<void> _disposeControllerOnly() async {
    final oldController = _controller;
    _controller = null;
    _isStreaming = false;
    _isProcessingFrame = false;
    if (oldController != null) {
      try {
        if (oldController.value.isStreamingImages) {
          await oldController.stopImageStream();
        }
        await oldController.dispose();
      } catch (e) {
        debugPrint('⚠️ [CameraService] Lỗi giải phóng controller: $e');
      }
    }
  }

  /// Giải phóng hoàn toàn Camera.
  Future<void> dispose() async {
    _onFrameCallback = null;
    await _disposeControllerOnly();
  }
}