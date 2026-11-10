import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'support/app_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TalkBack full mode summary; camera opens only after delay',
      (tester) async {
    const channel = MethodChannel('money_recognition/touch_exploration');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? true : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final backend = TestBackend();
    final speech = TestSpeech();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    final streams = backend.callbacks.length;
    final spokenBefore = speech.spoken.length;
    await tester.ensureVisible(find.byKey(const Key('switch_mode_button')));
    await tester.tap(find.byKey(const Key('switch_mode_button')));
    await tester.pump();
    final node =
        tester.widget<Semantics>(find.byKey(const Key('mode_talkback_status')));
    expect(node.properties.liveRegion, isTrue);
    expect(node.properties.label, contains('Đã chuyển sang chế độ đếm tiền'));
    expect(
        speech.spoken
            .skip(spokenBefore)
            .where((m) => m.contains('Đã chuyển sang chế độ')),
        isEmpty);
    expect(backend.callbacks.length, streams);
    await tester.pump(const Duration(seconds: 5));
    expect(backend.callbacks.length, streams);
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(backend.callbacks.length, greaterThan(streams));
    backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    expect(find.text('50.000đ'), findsOneWidget);
    await unmount(tester);
    semantics.dispose();
  });
}
