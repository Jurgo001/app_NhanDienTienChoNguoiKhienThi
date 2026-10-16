import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

typedef FrameCallback = Future<void> Function(CameraImage image, int rotation);

class CameraService {
  CameraService({this.minFrameIntervalMs = 120});
  final int minFrameIntervalMs;
  CameraController? _controller;
  CameraDescription? _backCamera;
  FrameCallback? _onFrameCallback;
  Future<void>? _frameInFlight;
  Future<void>? _lifecycle;
  bool _isStreaming = false;
  bool _resumeCamera = false, _resumeStream = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _isStreaming;
  int get sensorOrientation => _backCamera?.sensorOrientation ?? 90;

  int get frameRotation {
    final orientation = _controller?.value.deviceOrientation;
    final deviceAngle = switch (orientation) {
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
      _ => 0,
    };
    return (_backCamera?.lensDirection == CameraLensDirection.front
            ? sensorOrientation + deviceAngle
            : sensorOrientation - deviceAngle + 360) %
        360;
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted || (await Permission.camera.request()).isGranted;
  }

  Future<void> initializeCamera({
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    if (isInitialized) return;
    if (!await requestCameraPermission()) {
      throw CameraException('permissionDenied', 'Chưa được cấp quyền camera.');
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('noCameraAvailable', 'Không tìm thấy camera.');
    }
    _backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final next = CameraController(
      _backCamera!,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await next.initialize();
      _controller = next;
    } catch (_) {
      await next.dispose();
      rethrow;
    }
  }

  Future<void> startStream(FrameCallback onFrame) async {
    final camera = _controller;
    if (camera == null || !isInitialized) {
      throw StateError('Camera chưa khởi tạo.');
    }
    if (_isStreaming) return;
    _onFrameCallback = onFrame;
    _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
    _isStreaming = true;
    try {
      await camera.startImageStream((image) {
        final now = DateTime.now();
        if (!_isStreaming ||
            _frameInFlight != null ||
            now.difference(_lastFrameTime).inMilliseconds < minFrameIntervalMs)
          return;
        _lastFrameTime = now;
        // Future.sync bắt cả lỗi đồng bộ và bất đồng bộ từ callback.
        _frameInFlight = Future.sync(() => onFrame(image, frameRotation))
            .catchError((Object error, StackTrace stack) {
          debugPrint('Camera frame error: $error\n$stack');
        }).whenComplete(() {
          _frameInFlight = null;
        });
      });
    } catch (_) {
      _isStreaming = false;
      rethrow;
    }
  }

  Future<void> stopStream() async {
    _isStreaming = false;
    final camera = _controller;
    try {
      if (camera != null && camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } finally {
      await _frameInFlight;
    }
  }

  /// Dùng bởi màn debug; app chính tuần tự hóa lifecycle qua ScanSession.
  Future<void> handleAppLifecycleState(AppLifecycleState state) {
    final operation = (_lifecycle ?? Future<void>.value())
        .then((_) => _handleLifecycle(state));
    _lifecycle = operation.catchError((Object error) {
      debugPrint('Camera lifecycle error: $error');
    });
    return operation;
  }

  Future<void> _handleLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (!_resumeCamera) return;
      _resumeCamera = false;
      await initializeCamera();
      if (_resumeStream && _onFrameCallback != null) {
        _resumeStream = false;
        await startStream(_onFrameCallback!);
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!isInitialized) return;
      _resumeCamera = true;
      _resumeStream = _isStreaming;
      await _releaseCamera();
    }
  }

  Future<void> _releaseCamera() async {
    try {
      await stopStream();
    } finally {
      final old = _controller;
      _controller = null;
      await old?.dispose();
    }
  }

  Future<void> dispose() async {
    await _lifecycle;
    _resumeCamera = false;
    _resumeStream = false;
    _onFrameCallback = null;
    await _releaseCamera();
  }
}
