import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'support/app_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const touchChannel = MethodChannel('money_recognition/touch_exploration');

  testWidgets('TalkBack reset: doc ve khong dong, khong phat TTS app',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      touchChannel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? true : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(touchChannel, null));
    final backend = TestBackend();
    final speech = TestSpeech();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch_mode_button')));
    await tester.tap(find.byKey(const Key('switch_mode_button')));
    await tester.pump();
    // Flutter fake clock advances through the short TalkBack mode delay.
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);

    final before = speech.spoken.length;
    await tapVisible(
        tester, find.byKey(const Key('new_counting_session_button')));
    await tapVisible(
        tester, find.byKey(const Key('confirm_count_reset_button')));
    expect(find.text('0đ'), findsOneWidget);
    expect(
      speech.spoken
          .skip(before)
          .where((s) => s.contains('Đã bắt đầu phiên đếm mới')),
      isEmpty,
    );
    final status =
        tester.widget<Semantics>(find.byKey(const Key('mode_talkback_status')));
    expect(status.properties.liveRegion, isTrue);
    expect(status.properties.label,
        'Đã bắt đầu phiên đếm mới. Tổng hiện tại không đồng.');
    await unmount(tester);
    semantics.dispose();
  });

  testWidgets('TalkBack tat: reset tiep tuc duoc doc bang TTS app',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      touchChannel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? false : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(touchChannel, null));
    final backend = TestBackend();
    final speech = TestSpeech();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    final before = speech.spoken.length;
    await tapVisible(
        tester, find.byKey(const Key('new_counting_session_button')));
    await tapVisible(
        tester, find.byKey(const Key('confirm_count_reset_button')));
    expect(find.text('0đ'), findsOneWidget);
    expect(
      speech.spoken
          .skip(before)
          .any((s) => s.contains('Đã bắt đầu phiên đếm mới')),
      isTrue,
    );
    await unmount(tester);
  });
}
