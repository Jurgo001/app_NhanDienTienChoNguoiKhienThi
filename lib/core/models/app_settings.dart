enum SpeechRateOption { slow, normal, fast }

class AppSettings {
  const AppSettings({
    this.vibrationEnabled = true,
    this.speechRate = SpeechRateOption.normal,
  });

  final bool vibrationEnabled;
  final SpeechRateOption speechRate;

  AppSettings copyWith({
    bool? vibrationEnabled,
    SpeechRateOption? speechRate,
  }) {
    return AppSettings(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      speechRate: speechRate ?? this.speechRate,
    );
  }
}
