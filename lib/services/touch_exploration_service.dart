import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reports Android touch-exploration status (typically enabled with TalkBack).
/// This does not expose the screen reader's current utterance or identity.
class TouchExplorationService extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('money_recognition/touch_exploration');
  bool _enabled = false;
  bool _disposed = false;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTouchExplorationChanged' &&
          call.arguments is bool) {
        _update(call.arguments as bool);
      }
    });
    try {
      final value =
          await _channel.invokeMethod<bool>('isTouchExplorationEnabled');
      if (value != null) _update(value);
    } on MissingPluginException {
      // Widget tests / platforms that do not implement the Android channel.
      // accessibleNavigation is a general accessibility hint, not a TalkBack ID.
      _update(PlatformDispatcher
          .instance.accessibilityFeatures.accessibleNavigation);
    } on PlatformException catch (error) {
      debugPrint('Touch exploration unavailable: ${error.message}');
      _update(PlatformDispatcher
          .instance.accessibilityFeatures.accessibleNavigation);
    }
  }

  void updateFallback(bool value) => _update(value);

  void _update(bool value) {
    if (_disposed || value == _enabled) return;
    _enabled = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
