import 'package:flutter/services.dart';

abstract final class CameraCapabilities {
  static const _channel =
      MethodChannel('money_recognition/camera_capabilities');

  static Future<bool> supportsTorch(String cameraId) async {
    try {
      return await _channel
              .invokeMethod<bool>('hasTorch', {'cameraId': cameraId}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static bool isTorchUnavailableError(String description) {
    final value = description.toLowerCase();
    return value.contains('no flash unit') ||
        value.contains('does not have a flash') ||
        value.contains('flash is not supported') ||
        value.contains('torch is not supported');
  }
}
