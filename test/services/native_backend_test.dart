import 'dart:async';
import 'package:camera/camera.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/camera_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/detector_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend_native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/camera_fixtures.dart' show colorImage;

class MemoryCamera extends CameraService {
  bool initialized = false;
  FrameCallback? callback;
  Future<void>? active;
  Object? stopError;
  @override
  bool get isInitialized => initialized;
  @override
  Future<void> initializeCamera(
      {ResolutionPreset resolution = ResolutionPreset.medium}) async {
    initialized = true;
  }

  @override
  Future<void> startStream(FrameCallback onFrame) async {
    callback = onFrame;
  }

  Future<void> emit() => active = callback!(colorImage(), 270);
  @override
  Future<void> stopStream() async {
    await active;
    if (stopError != null) throw stopError!;
  }

  @override
  Future<void> dispose() async {
    try {
      await stopStream();
    } finally {
      initialized = false;
    }
  }
}

class MemoryDetector implements DetectorService {
  bool initialized = false, disposed = false;
  int? rotation;
  Object? error;
  Completer<DetectionResult>? gate;
  @override
  bool get isInitialized => initialized;
  @override
  bool get isBusy => false;
  @override
  String get modelInfo => 'test';
  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<DetectionResult> detectFrame(CameraImage image,
      {int sensorOrientation = 90}) async {
    rotation = sensorOrientation;
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return DetectionResult(
        status: DetectionStatus.detected,
        denomination: Denomination.vnd50000,
        confidence: .95);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class GrantedBackend extends NativeScanBackend {
  GrantedBackend(
      {required MemoryCamera camera, required MemoryDetector detector})
      : super(camera: camera, detector: detector);
  @override
  Future<CameraAccess> permission({bool request = false}) async =>
      CameraAccess.granted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Backend Android chuyển đúng frame/góc xoay từ camera sang detector',
      () async {
    final camera = MemoryCamera(), detector = MemoryDetector();
    final backend = GrantedBackend(camera: camera, detector: detector);
    final results = <DetectionResult>[];
    await backend.initialize();
    await backend.start(results.add);
    await camera.emit();
    expect(camera.initialized, isTrue);
    expect(detector.initialized, isTrue);
    expect(detector.rotation, 270);
    expect(results.single.denomination, Denomination.vnd50000);
    expect(results.single.isMock, isFalse);
    await backend.dispose();
  });
  test('Đợi frame đang suy luận kết thúc trước khi đóng detector', () async {
    final camera = MemoryCamera(), detector = MemoryDetector();
    detector.gate = Completer<DetectionResult>();
    final backend = GrantedBackend(camera: camera, detector: detector);
    await backend.initialize();
    await backend.start((_) {});
    final frame = camera.emit();
    final closing = backend.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(detector.disposed, isFalse);
    detector.gate!.complete(DetectionResult.empty());
    await frame;
    await closing;
    expect(detector.disposed, isTrue);
    expect(camera.initialized, isFalse);
  });
  test('Exception từ detector trở thành kết quả lỗi cho UI', () async {
    final camera = MemoryCamera(), detector = MemoryDetector();
    detector.error = StateError('inference failed');
    final backend = GrantedBackend(camera: camera, detector: detector);
    final results = <DetectionResult>[];
    await backend.initialize();
    await backend.start(results.add);
    await camera.emit();
    expect(results.single.status, DetectionStatus.modelError);
    expect(results.single.message, contains('inference failed'));
    await backend.dispose();
  });
  test('Camera stop lỗi vẫn giải phóng detector và controller', () async {
    final camera = MemoryCamera(), detector = MemoryDetector();
    final backend = GrantedBackend(camera: camera, detector: detector);
    await backend.initialize();
    camera.stopError = StateError('camera already closed');
    await expectLater(backend.dispose(), throwsStateError);
    expect(camera.initialized, isFalse);
    expect(detector.disposed, isTrue);
  });
}
