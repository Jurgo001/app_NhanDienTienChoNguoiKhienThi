import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/camera_capabilities.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('money_recognition/camera_capabilities');
  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('Torch support is read for the selected camera ID', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      expect(call.method, 'hasTorch');
      expect((call.arguments as Map)['cameraId'], '10');
      return false;
    });
    expect(await CameraCapabilities.supportsTorch('10'), isFalse);
  });

  test('Flash-capable phones retain automatic torch support', () async {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    expect(await CameraCapabilities.supportsTorch('0'), isTrue);
  });

  test('Missing or failed capability queries disable only the optional torch',
      () async {
    expect(await CameraCapabilities.supportsTorch('10'), isFalse);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (_) async => throw PlatformException(code: 'camera_unavailable'));
    expect(await CameraCapabilities.supportsTorch('10'), isFalse);
  });

  test('Unsupported flash errors are distinguished from fatal camera errors',
      () {
    expect(
        CameraCapabilities.isTorchUnavailableError(
            'java.lang.IllegalStateException: No flash unit'),
        isTrue);
    expect(CameraCapabilities.isTorchUnavailableError('flash is not supported'),
        isTrue);
    expect(CameraCapabilities.isTorchUnavailableError('Camera disconnected'),
        isFalse);
    expect(CameraCapabilities.isTorchUnavailableError('Camera device error'),
        isFalse);
  });
}
