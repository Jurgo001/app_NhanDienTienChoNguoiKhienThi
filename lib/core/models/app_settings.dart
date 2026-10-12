enum SpeechRateOption { slow, normal, fast }

class AppSettings {
  const AppSettings({
    this.autoReadEnabled = true,
    this.vibrationEnabled = true,
    this.speechRate = SpeechRateOption.normal,
  });

  final bool autoReadEnabled;
  final bool vibrationEnabled;
  final SpeechRateOption speechRate;

  AppSettings copyWith({
    bool? autoReadEnabled,
    bool? vibrationEnabled,
    SpeechRateOption? speechRate,
  }) {
    return AppSettings(
      autoReadEnabled: autoReadEnabled ?? this.autoReadEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      speechRate: speechRate ?? this.speechRate,
    );
  }
}
