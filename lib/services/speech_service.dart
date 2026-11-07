import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/models/app_settings.dart';

enum SpeechPriority { status, guidance, instruction, result }

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initializing;
  Future<void> _configuration = Future.value();
  Future<void>? _activeSpeech;
  String? _activeText;
  SpeechRateOption? _activeRate, _configuredRate;
  SpeechPriority _activePriority = SpeechPriority.status;
  bool _ready = false, _nativeSpeaking = false;
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

  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) {
    final active = _activeSpeech;
    if (active != null) {
      if (_activeText == text && _activeRate == rate) return active;
      // Do not queue obsolete camera instructions behind a denomination.
      if (priority.index < _activePriority.index) return Future.value();
    }
    final token = ++_request;
    _activeText = text;
    _activeRate = rate;
    _activePriority = priority;
    final speaking = _speak(token, text, rate).whenComplete(() {
      if (token == _request) {
        _activeSpeech = null;
        _activeText = null;
        _activeRate = null;
        _nativeSpeaking = false;
      }
    });
    _activeSpeech = speaking;
    return speaking;
  }

  Future<void> _speak(int token, String text, SpeechRateOption rate) async {
    await initialize();
    if (token != _request) return;
    // Serialize only native preparation, never the duration of speech.
    // This lets a result interrupt guidance without stale rate changes racing.
    final prepare = _configuration.then((_) async {
      if (token != _request) return;
      if (_nativeSpeaking) {
        await _tts.stop();
        _nativeSpeaking = false;
      }
      if (token != _request) return;
      if (_configuredRate != rate) {
        final speed = switch (rate) {
          SpeechRateOption.slow => .35,
          SpeechRateOption.normal => .5,
          SpeechRateOption.fast => .7,
        };
        await _tts.setSpeechRate(speed);
        _configuredRate = rate;
      }
    });
    _configuration = prepare.catchError((Object _) {});
    await prepare;
    if (token != _request) return;
    _nativeSpeaking = true;
    // Audio focus is requested only while app TTS is speaking on Android.
    // This may reduce overlap with TalkBack; it does not change a11y focus.
    final result = await _tts.speak(text, focus: true);
    if (token == _request && (result == 0 || result == false)) {
      throw StateError(
          'Không phát được giọng nói. Kiểm tra âm lượng và giọng tiếng Việt.');
    }
  }

  // Wait for the current app TTS utterance, without stopping or replaying it.
  // Android TalkBack owns its own queue, which a normal app cannot await.
  Future<void> waitForCurrentSpeech() async {
    final current = _activeSpeech;
    if (current != null) await current;
  }

  Future<void> stop() async {
    ++_request;
    _activeSpeech = null;
    _activeText = null;
    _activeRate = null;
    _nativeSpeaking = false;
    // Cancellation must not wait for pending initialization/rate configuration.
    await _tts.stop();
  }
}
