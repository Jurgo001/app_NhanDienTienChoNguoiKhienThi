import 'package:flutter_tts/flutter_tts.dart';

import '../core/models/app_settings.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();

  Future<void> initialize() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
  }) async {
    await _tts.stop();

    final speed = switch (rate) {
      SpeechRateOption.slow => 0.35,
      SpeechRateOption.normal => 0.5,
      SpeechRateOption.fast => 0.7,
    };

    await _tts.setSpeechRate(speed);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}