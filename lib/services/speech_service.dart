import 'package:flutter_tts/flutter_tts.dart';
import '../core/models/app_settings.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initializing;
  bool _ready = false;
  int _request = 0;

  Future<void> initialize() {
    if (_ready) return Future.value();
    return _initializing ??=
        _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    final available = await _tts.isLanguageAvailable('vi-VN');
    if (available != true && available != 1) {
      throw StateError('Chưa có giọng tiếng Việt. Cài dữ liệu giọng vi-VN '
          'trong mục Chuyển văn bản thành giọng nói rồi thử lại.');
    }
    final configured = await _tts.setLanguage('vi-VN');
    if (configured == 0 || configured == false) {
      throw StateError('Không chọn được giọng tiếng Việt.');
    }
    await _tts.setVolume(1);
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  Future<void> speak(String text,
      {SpeechRateOption rate = SpeechRateOption.normal}) async {
    final token = ++_request;
    await initialize();
    if (token != _request) return;
    await _tts.stop();
    if (token != _request) return;
    final speed = switch (rate) {
      SpeechRateOption.slow => .35,
      SpeechRateOption.normal => .5,
      SpeechRateOption.fast => .7,
    };
    await _tts.setSpeechRate(speed);
    if (token != _request) return;
    final result = await _tts.speak(text);
    if (token == _request && (result == 0 || result == false)) {
      throw StateError(
          'Không phát được giọng nói. Kiểm tra âm lượng và giọng tiếng Việt.');
    }
  }

  Future<void> stop() async {
    ++_request;
    await _tts.stop();
  }
}
