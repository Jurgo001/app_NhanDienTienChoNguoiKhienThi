import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/app_settings.dart';

class SettingsService {
  static const String _vibrationKey = 'vibration_enabled';
  static const String _speechRateKey = 'speech_rate';
  static const String _shortcutKey = 'hardware_shortcuts_enabled';

  late final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<AppSettings> loadSettings() async {
    // Remove the retired preference so automatic speech is always enabled.
    await _prefs.remove('auto_read_enabled');

    final vibration = await _prefs.getBool(_vibrationKey) ?? true;
    final hardwareShortcuts = await _prefs.getBool(_shortcutKey) ?? false;

    final rateName = await _prefs.getString(_speechRateKey) ?? 'normal';

    final speechRate = SpeechRateOption.values.firstWhere(
      (rate) => rate.name == rateName,
      orElse: () => SpeechRateOption.normal,
    );

    return AppSettings(
      vibrationEnabled: vibration,
      speechRate: speechRate,
      hardwareShortcutsEnabled: hardwareShortcuts,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setBool(
      _vibrationKey,
      settings.vibrationEnabled,
    );

    await _prefs.setString(
      _speechRateKey,
      settings.speechRate.name,
    );
    await _prefs.setBool(
      _shortcutKey,
      settings.hardwareShortcutsEnabled,
    );
  }

  static const String _countingSessionKey = 'money_counting_session_v1';

  Future<({int totalVnd, int noteCount})> loadCountingSession() async {
    final raw = await _prefs.getString(_countingSessionKey);
    if (raw == null) return (totalVnd: 0, noteCount: 0);
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        throw const FormatException('Invalid counting-session version');
      }
      final total = value['totalVnd'];
      final count = value['noteCount'];
      if (total is! int ||
          count is! int ||
          total < 0 ||
          count < 0 ||
          (count == 0) != (total == 0)) {
        throw const FormatException('Invalid counting-session totals');
      }
      return (totalVnd: total, noteCount: count);
    } on FormatException catch (error) {
      // Do not silently overwrite a corrupt saved total with zero.
      throw StateError('Dữ liệu phiên đếm lưu trên máy không hợp lệ: $error');
    }
  }

  Future<void> saveCountingSession(int totalVnd, int noteCount) async {
    if (totalVnd < 0 || noteCount < 0 || (noteCount == 0) != (totalVnd == 0)) {
      throw ArgumentError('Invalid counting session');
    }
    await _prefs.setString(
      _countingSessionKey,
      jsonEncode({
        'version': 1,
        'totalVnd': totalVnd,
        'noteCount': noteCount,
      }),
    );
  }
}
