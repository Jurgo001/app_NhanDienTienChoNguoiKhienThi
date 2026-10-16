import 'package:flutter/foundation.dart';
import '../core/models/app_settings.dart';
import '../core/models/recognition_ui_state.dart';
import '../models/denomination.dart';
import '../models/detection_result.dart';
import '../services/speech_service.dart';
import '../services/haptic_service.dart';
import '../services/image_quality_service.dart';

class RecognitionController extends ChangeNotifier {
  RecognitionController({
    required SpeechService speechService,
    required HapticService hapticService,
    required AppSettings Function() getSettings,
    this.onFeedbackError,
  })  : _speech = speechService,
        _haptic = hapticService,
        _getSettings = getSettings;
  final SpeechService _speech;
  final HapticService _haptic;
  final AppSettings Function() _getSettings;
  final void Function(Object error)? onFeedbackError;
  RecognitionUiState _state =
      const RecognitionUiState(status: RecognitionUiStatus.ready);
  RecognitionUiState get state => _state;
  Denomination? _currentDenomination, _candidate;
  DetectionStatus? _guidanceCandidate;
  int _consecutiveFrames = 0, _guidanceFrames = 0;
  DateTime? _lastGuidance;
  bool _disposed = false;
  static const double minimumConfidence = 0.78;
  static const int requiredStableFrames = 3;

  void _updateState(RecognitionUiState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  void startScanning({bool isMock = true}) {
    _clearResult();
    _lastGuidance = null;
    _updateState(RecognitionUiState(
      status: RecognitionUiStatus.scanning,
      guidance: 'Đưa một tờ tiền vào camera',
      isMock: isMock,
    ));
  }

  void processDetection(DetectionResult result) {
    if (_disposed || _state.status != RecognitionUiStatus.scanning) return;
    if (result.status == DetectionStatus.skippedBusy) return;
    if (result.status == DetectionStatus.modelError) {
      showError(result.message ?? 'Không thể chạy mô hình nhận diện',
          isMock: result.isMock);
      return;
    }
    if (!result.isRecognized ||
        !result.confidence.isFinite ||
        result.confidence < minimumConfidence) {
      _candidate = null;
      _consecutiveFrames = 0;
      final status = result.status == DetectionStatus.detected
          ? DetectionStatus.lowConfidence
          : result.status;
      final message =
          result.message ?? ImageQualityService.getGuidanceMessage(status);
      if (_state.guidance != message || _state.isMock != result.isMock) {
        _updateState(RecognitionUiState(
          status: RecognitionUiStatus.scanning,
          guidance: message,
          isMock: result.isMock,
        ));
      }
      _speakGuidance(status, message);
      return;
    }
    _guidanceCandidate = null;
    _guidanceFrames = 0;
    final denomination = result.denomination!;
    if (_candidate == denomination) {
      _consecutiveFrames++;
    } else {
      _candidate = denomination;
      _consecutiveFrames = 1;
    }
    if (_consecutiveFrames >= requiredStableFrames) {
      _confirmResult(denomination, isMock: result.isMock);
    }
  }

  void _speakGuidance(DetectionStatus status, String message) {
    if (_guidanceCandidate == status) {
      _guidanceFrames++;
    } else {
      _guidanceCandidate = status;
      _guidanceFrames = 1;
    }
    final now = DateTime.now();
    if (_guidanceFrames < 3 ||
        !_getSettings().autoReadEnabled ||
        (_lastGuidance != null && now.difference(_lastGuidance!).inSeconds < 8))
      return;
    _lastGuidance = now;
    _runFeedback(() => _speech.speak(message, rate: _getSettings().speechRate));
  }

  void _confirmResult(Denomination denomination, {required bool isMock}) {
    _currentDenomination = denomination;
    _updateState(RecognitionUiState(
      status: RecognitionUiStatus.recognized,
      denomination: denomination.displayText,
      spokenDenomination: denomination.spokenText,
      isMock: isMock,
    ));
    final settings = _getSettings();
    if (settings.vibrationEnabled) _runFeedback(_haptic.vibrateSuccess);
    if (settings.autoReadEnabled) {
      _runFeedback(() => _speech.speak(
            isMock
                ? 'Kết quả mô phỏng. ${denomination.spokenText}'
                : denomination.spokenText,
            rate: settings.speechRate,
          ));
    }
  }

  Future<void> replayResult() async {
    final denomination = _currentDenomination;
    if (denomination == null || _disposed) return;
    await _speech.speak(
      _state.isMock
          ? 'Kết quả mô phỏng. ${denomination.spokenText}'
          : denomination.spokenText,
      rate: _getSettings().speechRate,
    );
  }

  Future<void> resetScan() async {
    final isMock = _state.isMock;
    startScanning(isMock: isMock);
    await _speech.stop();
  }

  void clearCandidate() {
    _candidate = null;
    _consecutiveFrames = 0;
    _guidanceCandidate = null;
    _guidanceFrames = 0;
  }

  void _clearResult() {
    _currentDenomination = null;
    clearCandidate();
  }

  void showUnclear({bool isMock = false}) {
    _clearResult();
    _updateState(RecognitionUiState(
      status: RecognitionUiStatus.unclear,
      guidance: 'Chưa xác định được mệnh giá',
      isMock: isMock,
    ));
  }

  void showError(String message, {bool isMock = false}) {
    _clearResult();
    _updateState(RecognitionUiState(
      status: RecognitionUiStatus.error,
      guidance: message,
      isMock: isMock,
    ));
    if (_getSettings().vibrationEnabled) _runFeedback(_haptic.vibrateError);
  }

  void simulateRecognition(Denomination denomination) {
    if (_disposed || _state.status != RecognitionUiStatus.scanning) return;
    for (var i = 0; i < requiredStableFrames; i++) {
      processDetection(DetectionResult(
        status: DetectionStatus.detected,
        denomination: denomination,
        confidence: .95,
        isMock: true,
      ));
    }
  }

  void _runFeedback(Future<void> Function() action) {
    action().catchError((Object error, StackTrace stack) {
      debugPrint('Recognition feedback error: $error');
      if (!_disposed) onFeedbackError?.call(error);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
