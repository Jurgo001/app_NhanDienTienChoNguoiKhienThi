import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'support/app_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TalkBack announces short mode; existing total stays visible',
      (tester) async {
    const channel = MethodChannel('money_recognition/touch_exploration');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? true : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final settings = MemorySettings()
      ..storedCount = (totalVnd: 6000, noteCount: 3);
    final backend = TestBackend();
    final speech = TestSpeech();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: settings,
    ));
    await tester.pumpAndSettle();
    final before = backend.callbacks.length;
    final spokenBefore = speech.spoken.length;
    await tester.ensureVisible(find.byKey(const Key('switch_mode_button')));
    await tester.tap(find.byKey(const Key('switch_mode_button')));
    await tester.pump();
    final node =
        tester.widget<Semantics>(find.byKey(const Key('mode_talkback_status')));
    expect(node.properties.liveRegion, isTrue);
    expect(node.properties.label, 'Đã chuyển sang chế độ đếm tiền.');
    // The stored count stays visible, but no longer occupies the mode announcement.
    expect(find.text('6.000đ'), findsOneWidget);
    expect(
        speech.spoken
            .skip(spokenBefore)
            .where((m) => m.contains('Đã chuyển sang chế độ')),
        isEmpty);
    expect(backend.callbacks.length, before);
    expect(find.byKey(const Key('talkback_confirm_counting_start_button')),
        findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(backend.callbacks.length, before);
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(backend.callbacks.length, greaterThan(before));
    await unmount(tester);
    semantics.dispose();
  });
}
