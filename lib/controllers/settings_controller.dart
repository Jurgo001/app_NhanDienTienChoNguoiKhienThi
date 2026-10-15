
import 'package:flutter/foundation.dart';

import '../core/models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._settingsService);

  final SettingsService _settingsService;

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _settingsService.loadSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAutoRead(bool enabled) async {
    await _update(
      _settings.copyWith(autoReadEnabled: enabled),
    );
  }

  Future<void> setVibration(bool enabled) async {
    await _update(
      _settings.copyWith(vibrationEnabled: enabled),
    );
  }

  Future<void> setSpeechRate(SpeechRateOption rate) async {
    await _update(
      _settings.copyWith(speechRate: rate),
    );
  }

  Future<void> _update(AppSettings newSettings) async {
    await _settingsService.saveSettings(newSettings);

    _settings = newSettings;
    notifyListeners();
  }
}
