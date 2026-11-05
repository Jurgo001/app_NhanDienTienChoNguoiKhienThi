import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum VolumeHoldAction { switchMode, newSession }

/// Lắng nghe sự kiện nhấn giữ 3 giây từ MainActivity của Android.
/// Nhấn ngắn do Android xử lý như thao tác âm lượng bình thường.
class HardwareVolumeShortcuts {
  HardwareVolumeShortcuts({required this.onAction});

  static const MethodChannel _channel =
      MethodChannel('doc_tien_viet/volume_shortcuts');

  final Future<void> Function(VolumeHoldAction action) onAction;
  static HardwareVolumeShortcuts? _current;
  bool _disposed = false;

  void register() {
    _current = this;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLongPress') return;
      final action = switch (call.arguments) {
        'volume_up' => VolumeHoldAction.switchMode,
        'volume_down' => VolumeHoldAction.newSession,
        _ => null,
      };
      if (action != null) await _dispatch(action);
    });
  }

  Future<void> _dispatch(VolumeHoldAction action) async {
    if (!_disposed) await onAction(action);
  }

  /// Gửi lệnh bật/tắt bắt phím: chỉ ở màn hình camera và lúc app foreground.
  Future<void> setEnabled(bool enabled, {required bool countingMode}) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('setCaptureEnabled', {
        'enabled': enabled,
        'countingMode': countingMode,
      });
    } on MissingPluginException {
      // Widget test, web và nền tảng không có MainActivity Android.
    } on PlatformException catch (e) {
      debugPrint('Phim am luong khong san sang: ${e.message}');
    }
  }

  @visibleForTesting
  static Future<void> simulateHold(VolumeHoldAction action) async {
    await _current?._dispatch(action);
  }

  void dispose() {
    _disposed = true;
    if (identical(_current, this)) {
      _current = null;
      _channel.setMethodCallHandler(null);
    }
  }
}
