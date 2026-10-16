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
    this.resultDuration = const Duration(seconds: 15),
  });
  final ScanBackend backend;
  final RecognitionController recognition;
  final Duration resultDuration;
  final Future<void> Function()? beforeStart;
  Future<void>? _pending;
  Timer? _resetTimer;
  int _generation = 0;
  bool _visible = true;
  bool _requested = false;
  bool _closed = false;
  bool _busy = false;
  bool get busy => _busy;

  bool _current(int token) => !_closed && _visible && token == _generation;

  Future<void> start() {
    if (_closed) return Future.value();
    _requested = true;
    _resetTimer?.cancel();
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
          await backend.start((result) => _receive(token, result));
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
    if (!_current(token) ||
        recognition.state.status != RecognitionUiStatus.scanning) return;
    recognition.processDetection(result);
    final status = recognition.state.status;
    if (status != RecognitionUiStatus.recognized &&
        status != RecognitionUiStatus.error) return;
    // Không await stop từ callback frame: stop phải đợi chính frame này kết thúc.
    unawaited(_enqueue(() async {
      await backend.stop();
      _notify();
    }));
    if (status == RecognitionUiStatus.recognized) _scheduleReset();
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(resultDuration, () {
      if (!_closed && _visible && _requested) unawaited(start());
    });
  }

  Future<void> setVisible(bool visible) {
    if (_closed || _visible == visible) return _pending ?? Future.value();
    _visible = visible;
    _resetTimer?.cancel();
    final token = ++_generation;
    recognition.clearCandidate();
    if (!visible) {
      return _enqueue(() async {
        await backend.stop(releaseCamera: true);
        _notify();
      });
    }
    if (!_requested) return _pending ?? Future.value();
    if (recognition.state.status == RecognitionUiStatus.scanning) {
      return _begin(token);
    }
    if (recognition.state.hasResult) _scheduleReset();
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
    _resetTimer?.cancel();
    return _enqueue(backend.dispose);
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
