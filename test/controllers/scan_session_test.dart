import 'dart:async';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/recognition_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/scan_session.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';

import 'package:flutter_test/flutter_test.dart';
import '../support/app_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestBackend backend;
  late TestSpeech speech;
  late RecognitionController recognition;
  late ScanSession session;
  final valid = DetectionResult(
      status: DetectionStatus.detected,
      denomination: Denomination.vnd100000,
      confidence: .95);
  group('Điều phối tài nguyên', () {
    setUp(() {
      backend = TestBackend();
      speech = TestSpeech();
      recognition = RecognitionController(
          speechService: speech,
          hapticService: TestHaptic(),
          getSettings: () => const AppSettings());
      session = ScanSession(backend: backend, recognition: recognition);
    });
    tearDown(() async {
      await session.close();
      session.dispose();
      recognition.dispose();
    });

    test('New session ignores callbacks from the previous session', () async {
      await session.start();
      final old = backend.callbacks.single;
      backend.recognize();
      expect(recognition.state.hasResult, isTrue);
      final restarting = session.start();
      expect(recognition.state.hasResult, isFalse);
      for (var i = 0; i < 3; i++) {
        old(valid);
      }
      await restarting;
      expect(recognition.state.status, RecognitionUiStatus.scanning);
      backend.recognize();
      expect(recognition.state.hasResult, isTrue);
      expect(speech.spoken, hasLength(2));
    });

    test('Tạm dừng khi đang init không được mở stream sau khi rời màn',
        () async {
      backend.initializeGate = Completer<void>();
      final starting = session.start();
      await Future<void>.delayed(Duration.zero);
      final pausing = session.setVisible(false);
      backend.initializeGate!.complete();
      await starting;
      await pausing;
      expect(backend.callbacks, isEmpty);
      expect(backend.releases, greaterThanOrEqualTo(1));
      await session.setVisible(true);
      expect(backend.callbacks, hasLength(1));
    });

    test('Lỗi model có thông báo, thử lại khởi tạo được', () async {
      backend.initializeError = StateError('missing model');
      await session.start();
      expect(recognition.state.status, RecognitionUiStatus.error);
      expect(recognition.state.guidance, contains('missing model'));
      expect(backend.callbacks, isEmpty);
      backend.initializeError = null;
      await session.start();
      expect(recognition.state.status, RecognitionUiStatus.scanning);
      expect(backend.callbacks, hasLength(1));
    });

    test('Đóng trong lúc initialize đợi xong rồi mới dispose backend',
        () async {
      backend.initializeGate = Completer<void>();
      final starting = session.start();
      await Future<void>.delayed(Duration.zero);
      final closing = session.close();
      expect(backend.disposals, 0);
      backend.initializeGate!.complete();
      await starting;
      await closing;
      expect(backend.callbacks, isEmpty);
      expect(backend.disposals, 1);
    });
  });

  test('same denomination is announced again after four empty frames',
      () async {
    await session.start();
    backend.recognize(Denomination.vnd50000);
    expect(recognition.state.status, RecognitionUiStatus.lockedAnnounced);
    for (var i = 0; i < RecognitionController.requiredEmptyFrames; i++) {
      backend.emit(DetectionResult.empty(isMock: backend.isMock));
    }
    expect(recognition.state.status, RecognitionUiStatus.scanning);
    backend.recognize(Denomination.vnd50000);
    expect(recognition.state.status, RecognitionUiStatus.lockedAnnounced);
  });
}
