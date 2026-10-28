import 'package:flutter/foundation.dart';
import '../core/models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._settingsService);
  final SettingsService _settingsService;
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;
  bool _isLoading = false, _disposed = false;
  bool get isLoading => _isLoading;
  Future<void> _writes = Future.value();
  Future<void> initialize() async {
    _isLoading = true;
    _notify();
    try {
      _settings = await _settingsService.loadSettings();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> setVibration(bool value) =>
      _update(_settings.copyWith(vibrationEnabled: value));
  Future<void> setSpeechRate(SpeechRateOption value) =>
      _update(_settings.copyWith(speechRate: value));

  Future<void> _update(AppSettings value) {
    // Cập nhật đồng bộ: thao tác kế tiếp luôn copy từ state mới nhất.
    _settings = value;
    _notify();
    final save = _writes.then((_) => _settingsService.saveSettings(value));
    // Một lần ghi lỗi không chặn những lần ghi tiếp. Caller vẫn nhận lỗi save.
    _writes = save.catchError((Object error) {
      debugPrint('Settings save: $error');
    });
    return save;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
