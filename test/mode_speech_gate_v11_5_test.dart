import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/recognition_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/scan_session.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'support/app_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Khung hinh khong duoc cong khi dang doc camera san sang',
      (tester) async {
    final backend = TestBackend();
    final speech = TestSpeech();
    final recognition = RecognitionController(
      speechService: speech,
      hapticService: TestHaptic(),
      getSettings: () => const AppSettings(),
      isMoneyCounting: () => true,
    );
    final session = ScanSession(backend: backend, recognition: recognition);
    await session.start();
    session.setModeFeedbackSpeechActive(true);
    session.armCameraReadiness();
    backend.recognize(Denomination.vnd100000);
    expect(
        await session.waitForCameraReadiness(
            timeout: const Duration(milliseconds: 300)),
        isTrue);
    expect(recognition.state.hasResult, isFalse);
    expect(speech.spoken.where((s) => s.contains('Một trăm')), isEmpty);
    session.setModeFeedbackSpeechActive(false);
    backend.recognize(Denomination.vnd100000);
    await tester.pump();
    expect(recognition.state.hasResult, isTrue);
    await session.close();
    session.dispose();
    recognition.dispose();
  });

  testWidgets('TalkBack bat: TTS app doc du thong bao truoc khi mo camera',
      (tester) async {
    const channel = MethodChannel('money_recognition/touch_exploration');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'isTouchExplorationEnabled' ? true : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final backend = TestBackend();
    final speech = TestSpeech();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('switch_mode_button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final before = speech.spoken.length;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
        speech.spoken
            .skip(before)
            .where((x) => x.contains('Đã chuyển sang chế độ')),
        isNotEmpty);
    expect(find.text('0đ'), findsOneWidget);
    await unmount(tester);
  });
}
