enum SpeechRateOption { slow, normal, fast }

class AppSettings {
  const AppSettings({
    this.vibrationEnabled = true,
    this.speechRate = SpeechRateOption.normal,
    this.hardwareShortcutsEnabled = false,
  });

  final bool vibrationEnabled;
  final SpeechRateOption speechRate;
  final bool hardwareShortcutsEnabled;

  AppSettings copyWith({
    bool? vibrationEnabled,
    SpeechRateOption? speechRate,
    bool? hardwareShortcutsEnabled,
  }) {
    return AppSettings(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      speechRate: speechRate ?? this.speechRate,
      hardwareShortcutsEnabled:
          hardwareShortcutsEnabled ?? this.hardwareShortcutsEnabled,
    );
  }
}
