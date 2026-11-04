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
  Denomination? _candidate;
  String? _guidanceCandidate;
  int _consecutiveFrames = 0, _guidanceFrames = 0, _emptyFrames = 0;
  DateTime? _lastGuidance;
  bool _disposed = false;
  bool _resultSpeechInProgress = false;
  static const double minimumConfidence = 0.78;
  static const int requiredStableFrames = 3;
  static const int requiredEmptyFrames = 4;
  static const Duration guidanceCooldown = Duration(milliseconds: 3500);

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
      guidance: 'Hãy đưa một tờ tiền vào giữa camera và giữ yên.',
      isMock: isMock,
    ));
  }

  void announceScanningPrompt() {
    if (_state.status != RecognitionUiStatus.scanning ||
        _disposed ||
        _resultSpeechInProgress) {
      return;
    }
    _lastGuidance = DateTime.now();
    final prompt =
        _state.guidance ?? 'Hãy đưa một tờ tiền vào giữa camera và giữ yên.';
    _runFeedback(() => _speech.speak(prompt,
        rate: _getSettings().speechRate, priority: SpeechPriority.guidance));
  }

  // Đọc thông báo khi flash tự bật hoặc tự tắt.
  // Sử dụng SpeechService hiện có để giữ chung cấu hình giọng nói.
  void announceFlashStatus(String message) {
    // Không đọc nếu controller đã đóng.
    // Không chen ngang lúc đang thông báo mệnh giá tiền.
    if (_disposed ||
        _state.status != RecognitionUiStatus.scanning ||
        _resultSpeechInProgress) {
      return;
    }

    // Tạm ngăn lời nhắc camera đọc đè ngay sau thông báo flash.
    _lastGuidance = DateTime.now();

    // Reset bộ đếm để không phát lại lời nhắc từ các frame trước.
    _guidanceCandidate = null;
    _guidanceFrames = 0;

    debugPrint('[FLASH_TTS] $message');

    // Dùng tốc độ đọc mà người dùng đã chọn trong cài đặt.
    _runFeedback(
      () => _speech.speak(
        message,
        rate: _getSettings().speechRate,
        priority: SpeechPriority.status,
      ),
    );
  }

  void processDetection(DetectionResult result) {
    if (_disposed) return;
    if (_state.status == RecognitionUiStatus.lockedAnnounced) {
      if (result.status == DetectionStatus.noMoney) {
        if (++_emptyFrames >= requiredEmptyFrames) _beginNextTurn();
      } else if (result.status != DetectionStatus.skippedBusy) {
        _emptyFrames = 0;
      }
      return;
    }
    if (_state.status != RecognitionUiStatus.scanning) return;
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
    debugPrint(
      '[STABLE] '
      'Menh gia: ${denomination.value} | '
      'Frame: $_consecutiveFrames/$requiredStableFrames | '
      'Confidence: ${result.confidence.toStringAsFixed(2)}',
    );
    if (_consecutiveFrames >= requiredStableFrames) {
      _confirmResult(denomination, isMock: result.isMock);
    }
  }

  void _speakGuidance(DetectionStatus status, String message) {
    // Không lặp lời nhắc khi camera không thấy tiền.
    if (status == DetectionStatus.noMoney) {
      _guidanceCandidate = null;
      _guidanceFrames = 0;
      return;
    }

    // Chỉ cộng frame nếu nội dung hướng dẫn không thay đổi.
    if (_guidanceCandidate == message) {
      _guidanceFrames++;
    } else {
      _guidanceCandidate = message;
      _guidanceFrames = 1;
    }

    final now = DateTime.now();

    // Cần đủ 3 frame và không đọc cảnh báo quá thường xuyên.
    if (_guidanceFrames < 3 ||
        (_lastGuidance != null &&
            now.difference(_lastGuidance!) < guidanceCooldown)) {
      return;
    }

    _lastGuidance = now;

    // Log để kiểm tra ứng dụng yêu cầu TTS đọc câu gì.
    debugPrint('[GUIDANCE_TTS] $message');

    _runFeedback(
      () => _speech.speak(
        message,
        rate: _getSettings().speechRate,
        priority: SpeechPriority.guidance,
      ),
    );
  }

  void _confirmResult(Denomination denomination, {required bool isMock}) {
    _emptyFrames = 0;
    _updateState(RecognitionUiState(
      status: RecognitionUiStatus.lockedAnnounced,
      denomination: denomination.displayText,
      spokenDenomination: denomination.spokenText,
      isMock: isMock,
    ));
    final settings = _getSettings();
    if (settings.vibrationEnabled) _runFeedback(_haptic.vibrateSuccess);
    _resultSpeechInProgress = true;

    _runFeedback(() async {
      try {
        await _speech.speak(
          isMock
              ? 'Kết quả mô phỏng. ${denomination.spokenText}'
              : denomination.spokenText,
          rate: settings.speechRate,
          priority: SpeechPriority.result,
        );
      } finally {
        _resultSpeechInProgress = false;
      }
    });
  }

  void _beginNextTurn() {
    final isMock = _state.isMock;
    _clearResult();
    _lastGuidance = null;
    _updateState(RecognitionUiState(
      status: RecognitionUiStatus.scanning,
      guidance: 'Hãy đưa một tờ tiền vào giữa camera và giữ yên.',
      isMock: isMock,
    ));
    announceScanningPrompt();
  }

  void clearCandidate() {
    _candidate = null;
    _consecutiveFrames = 0;
    _guidanceCandidate = null;
    _guidanceFrames = 0;
  }

  void _clearResult() {
    _emptyFrames = 0;
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
