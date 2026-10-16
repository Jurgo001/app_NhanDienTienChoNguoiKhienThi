import 'dart:async';
import 'scan_backend.dart';
import 'mock_money_detector.dart';

ScanBackend createScanBackend() => WebScanBackend();

/// Chỉ kiểm tra giao diện/giọng nói. Không chạy model hoặc camera trên Web.
class WebScanBackend extends ScanBackend {
  final MockMoneyDetector _detector = MockMoneyDetector();
  Timer? _timer;
  @override
  bool get isMock => true;
  @override
  Future<CameraAccess> permission({bool request = false}) async =>
      CameraAccess.notRequired;
  @override
  Future<void> openPermissionSettings() async {}
  @override
  Future<void> initialize() => _detector.initialize();
  @override
  Future<void> start(DetectionCallback onResult) async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      onResult(_detector.buildMockResult());
    });
  }

  @override
  Future<void> stop({bool releaseCamera = false}) async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _detector.dispose();
  }
}
