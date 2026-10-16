import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/app_settings.dart';

class SettingsService {
  static const String _autoReadKey = 'auto_read_enabled';
  static const String _vibrationKey = 'vibration_enabled';
  static const String _speechRateKey = 'speech_rate';

  late final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<AppSettings> loadSettings() async {
    final autoRead = await _prefs.getBool(_autoReadKey) ?? true;

    final vibration = await _prefs.getBool(_vibrationKey) ?? true;

    final rateName = await _prefs.getString(_speechRateKey) ?? 'normal';

    final speechRate = SpeechRateOption.values.firstWhere(
      (rate) => rate.name == rateName,
      orElse: () => SpeechRateOption.normal,
    );

    return AppSettings(
      autoReadEnabled: autoRead,
      vibrationEnabled: vibration,
      speechRate: speechRate,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setBool(
      _autoReadKey,
      settings.autoReadEnabled,
    );

    await _prefs.setBool(
      _vibrationKey,
      settings.vibrationEnabled,
    );

    await _prefs.setString(
      _speechRateKey,
      settings.speechRate.name,
    );
  }
}
