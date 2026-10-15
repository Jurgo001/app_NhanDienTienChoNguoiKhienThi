
import 'package:flutter/foundation.dart';

import '../core/models/app_settings.dart';
import '../core/models/recognition_ui_state.dart';
import '../models/denomination.dart';
import '../models/detection_result.dart';
import '../services/speech_service.dart';
import '../services/haptic_service.dart';

class RecognitionController extends ChangeNotifier {
  RecognitionController({
    required SpeechService speechService,
    required HapticService hapticService,
    required AppSettings Function() getSettings,
  })  : _speech = speechService,
        _haptic = hapticService,
        _getSettings = getSettings;

  final SpeechService _speech;
  final HapticService _haptic;
  final AppSettings Function() _getSettings;

  RecognitionUiState _state = const RecognitionUiState(
    status: RecognitionUiStatus.ready,
  );

  RecognitionUiState get state => _state;

  Denomination? _currentDenomination;
  Denomination? _candidate;
  int _consecutiveFrames = 0;

  bool _disposed = false;

  // Ngưỡng thử nghiệm, cần hiệu chỉnh bằng dữ liệu thực tế.
  static const double minimumConfidence = 0.75;
  static const int requiredStableFrames = 3;

  void _updateState(RecognitionUiState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  /// Bắt đầu phiên nhận diện mới.
  void startScanning() {

    _clearResult();

    _updateState(
      const RecognitionUiState(
        status: RecognitionUiStatus.scanning,
        guidance: 'Đưa một tờ tiền vào camera',
      ),
    );
  }

  /// Nhận kết quả một frame từ TV2.
  void processDetection(DetectionResult result) {
    if (_disposed ||
        _state.status != RecognitionUiStatus.scanning) {
      return;
    }

    if (result.status == DetectionStatus.modelError) {
      showError(
        result.message ?? 'Không thể chạy mô hình nhận diện',
      );
      return;
    }

    if (!result.isRecognized ||
        result.confidence < minimumConfidence) {
      _candidate = null;
      _consecutiveFrames = 0;

      if (result.status == DetectionStatus.noMoney ||
          result.status == DetectionStatus.skippedBusy) {
        return;
      }

      _updateState(
        RecognitionUiState(
          status: RecognitionUiStatus.scanning,
          guidance: result.message ??
              'Chưa nhận diện rõ, vui lòng thử lại',
          isMock: result.isMock,
        ),
      );
      return;
    }

    final denomination = result.denomination!;

    if (_candidate == denomination) {
      _consecutiveFrames++;
    } else {
      _candidate = denomination;
      _consecutiveFrames = 1;
    }

    if (_consecutiveFrames < requiredStableFrames) {
      return;
    }

    _confirmResult(
      denomination,
      isMock: result.isMock,
    );
  }

  void _confirmResult(
    Denomination denomination, {
    required bool isMock,
  }) {
    if (_state.status == RecognitionUiStatus.recognized) {
      return;
    }

    _currentDenomination = denomination;

    _updateState(
      RecognitionUiState(
        status: RecognitionUiStatus.recognized,
        denomination: denomination.displayText,
        isMock: isMock,
      ),
    );

    final settings = _getSettings();

    if (settings.vibrationEnabled) {
      _runFeedback(() => _haptic.vibrateSuccess());
    }

    if (settings.autoReadEnabled) {
      _runFeedback(
        () => _speech.speak(
          denomination.spokenText,
          rate: settings.speechRate,
        ),
      );
    }
  }

  /// Đọc lại mệnh giá đã xác nhận.
  Future<void> replayResult() async {
    final denomination = _currentDenomination;
    if (denomination == null || _disposed) return;

    await _speech.speak(
      denomination.spokenText,
      rate: _getSettings().speechRate,
    );
  }

  /// Xóa kết quả và bắt đầu quét lại.
  Future<void> resetScan() async {

    _clearResult();
    await _speech.stop();

    _updateState(
      const RecognitionUiState(
        status: RecognitionUiStatus.scanning,
        guidance: 'Đang chờ nhận diện',
      ),
    );
  }

  /// Hiển thị trường hợp chưa xác định.
  void showUnclear({bool isMock = false}) {
    _clearResult();

    _updateState(
      RecognitionUiState(
        status: RecognitionUiStatus.unclear,
        guidance: 'Chưa xác định được mệnh giá',
        isMock: isMock,
      ),
    );
  }

  /// Hiển thị lỗi kỹ thuật.
  void showError(String message, {bool isMock = false}) {
    _clearResult();

    _updateState(
      RecognitionUiState(
        status: RecognitionUiStatus.error,
        guidance: message,
        isMock: isMock,
      ),
    );

    if (_getSettings().vibrationEnabled) {
      _runFeedback(() => _haptic.vibrateError());
    }
  }

  /// Dùng cho nút mô phỏng khi camera chưa sẵn sàng.
  void simulateRecognition(Denomination denomination) {
  if (_disposed ||
      _state.status != RecognitionUiStatus.scanning) {
    return;
  }

  for (var i = 0; i < requiredStableFrames; i++) {
    processDetection(
      DetectionResult(
        status: DetectionStatus.detected,
        denomination: denomination,
        confidence: 0.95,
        isMock: true,
      ),
    );
  }
}

  void _clearResult() {
    _currentDenomination = null;
    _candidate = null;
    _consecutiveFrames = 0;
  }

  void _runFeedback(Future<void> Function() action) {
    action().catchError((Object error, StackTrace stack) {
      debugPrint('Recognition feedback error: $error');
    });
  }

  @override
  void dispose() {
    _disposed = true;

    super.dispose();
  }
}
