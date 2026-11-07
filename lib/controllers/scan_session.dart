import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/models/recognition_ui_state.dart';
import '../models/detection_result.dart';
import '../services/scan_backend.dart';
import 'recognition_controller.dart';

/// Tuần tự hóa tài nguyên; mỗi phiên có token để bỏ kết quả trả về muộn.
class ScanSession extends ChangeNotifier {
  ScanSession({
    required this.backend,
    required this.recognition,
    this.beforeStart,
  });
  final ScanBackend backend;
  final RecognitionController recognition;
  final Future<void> Function()? beforeStart;
  Future<void>? _pending;
  int _generation = 0;
  bool _visible = true;
  bool _requested = false;
  bool _closed = false;
  bool _resultsSuspended = false;
  bool _busy = false;
  bool get busy => _busy;

  Completer<void>? _cameraReadyGate;
  bool _modeFeedbackSpeechActive = false;

  /// Warmup frames may reach the detector but never reach recognition,
  /// counting or result TTS while the mode/ready narration is ongoing.
  void setModeFeedbackSpeechActive(bool active) {
    _modeFeedbackSpeechActive = active;
  }

  /// Begin a new native-camera readiness check before restarting the stream.
  void armCameraReadiness() {
    _cameraReadyGate = Completer<void>();
  }

  /// Completes when the detector returns a usable frame (and, if necessary,
  /// the pre-counting empty-camera guard has finished). A timeout does not
  /// claim the camera is ready and never restarts resources behind the UI.
  Future<bool> waitForCameraReadiness({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final gate = _cameraReadyGate;
    if (gate == null) return false;
    try {
      await gate.future.timeout(timeout);
      return true;
    } on TimeoutException {
      debugPrint('[MODE_READY] no usable AI frame within $timeout');
      return false;
    } finally {
      if (identical(_cameraReadyGate, gate)) _cameraReadyGate = null;
    }
  }

  /// Chi bo callback nhan dien khi dialog xac nhan dang mo.
  /// Camera va model van hoat dong, khong bi dong/mo lien tuc.
  void setResultsSuspended(bool suspended) {
    _resultsSuspended = suspended;
  }

  bool _current(int token) => !_closed && _visible && token == _generation;

  Future<void> start() {
    if (_closed) return Future.value();
    _requested = true;
    final token = ++_generation;
    recognition.startScanning(isMock: backend.isMock);
    return _begin(token);
  }

  Future<void> _begin(int token) => _enqueue(() async {
        if (!_current(token)) return;
        _busy = true;
        _notify();
        try {
          await backend.stop();
          await beforeStart?.call();
          if (!_current(token)) return;
          await backend.initialize();
          if (!_current(token)) {
            await backend.stop(releaseCamera: true);
            return;
          }
          backend.setRecognitionLocked(
              recognition.state.status == RecognitionUiStatus.lockedAnnounced);
          await backend.start((result) => _receive(token, result));
          if (_current(token)) recognition.announceScanningPrompt();
        } catch (error) {
          if (_current(token)) {
            recognition.showError('Không thể bắt đầu quét: $error',
                isMock: backend.isMock);
            await backend.stop(releaseCamera: true);
          }
        } finally {
          _busy = false;
          _notify();
        }
      });

  void _receive(int token, DetectionResult result) {
    if (!_current(token) || _resultsSuspended) return;
    // Readiness uses the first usable detector frame, not a UI preview.
    // Do not recognize or count this warmup frame while narration is active.
    if (_modeFeedbackSpeechActive) {
      if (result.status != DetectionStatus.skippedBusy &&
          result.status != DetectionStatus.modelError) {
        final gate = _cameraReadyGate;
        if (gate != null && !gate.isCompleted) gate.complete();
      }
      return;
    }
    recognition.processDetection(result);
    final status = recognition.state.status;
    backend.setRecognitionLocked(status == RecognitionUiStatus.lockedAnnounced);
    if (status != RecognitionUiStatus.error) return;
    // Không await stop từ callback frame: stop phải đợi chính frame này kết thúc.
    unawaited(_enqueue(() async {
      await backend.stop();
      _notify();
    }));
  }

  Future<void> setVisible(bool visible, {bool releaseCamera = true}) {
    if (_closed || _visible == visible) return _pending ?? Future.value();
    _visible = visible;
    final token = ++_generation;
    recognition.clearCandidate();
    if (!visible) {
      return _enqueue(() async {
        await backend.stop(releaseCamera: releaseCamera);
        _notify();
      });
    }
    if (!_requested) return _pending ?? Future.value();
    if (recognition.state.status == RecognitionUiStatus.scanning ||
        recognition.state.status == RecognitionUiStatus.lockedAnnounced) {
      return _begin(token);
    }
    return _pending ?? Future.value();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = (_pending ?? Future<void>.value()).then((_) => action());
    _pending = next.catchError((Object error, StackTrace stack) {
      debugPrint('Scan resource error: $error\n$stack');
      if (!_closed)
        recognition.showError('Lỗi camera: $error', isMock: backend.isMock);
    });
    return _pending ?? Future.value();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  /// Vô hiệu hóa token ngay, sau đó mới đóng tài nguyên bất đồng bộ.
  Future<void> close() {
    if (_closed) return _pending ?? Future.value();
    _closed = true;
    ++_generation;
    return _enqueue(backend.dispose);
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
