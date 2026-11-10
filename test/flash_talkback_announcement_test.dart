import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/app_fakes.dart';

const _touchExplorationChannel =
    MethodChannel('money_recognition/touch_exploration');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_touchExplorationChannel, null);
  });

  testWidgets('TalkBack: flash status is a live region, without app TTS',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_touchExplorationChannel, (call) async {
      if (call.method == 'isTouchExplorationEnabled') return true;
      return null;
    });
    final semantics = tester.ensureSemantics();
    final h = AppHarness();
    await h.mount(tester);
    final finder = find.byKey(const Key('flash_talkback_status'));
    expect(finder, findsOneWidget);
    final initial = tester.widget<Semantics>(finder);
    expect(initial.properties.liveRegion, isFalse);
    final priorSpeech = h.speech.spoken.length;

    h.backend.onFlashAnnouncement?.call('Đã bật đèn flash');
    await tester.pump();
    final enabled = tester.widget<Semantics>(finder);
    expect(enabled.properties.liveRegion, isTrue);
    expect(enabled.properties.label, 'Đã bật đèn flash');
    expect(find.bySemanticsLabel('Đã bật đèn flash'), findsOneWidget);
    expect(h.speech.spoken.length, priorSpeech);

    h.backend.onFlashAnnouncement?.call('Đã bật đèn flash');
    await tester.pump();
    expect(h.speech.spoken.length, priorSpeech);
    expect(
        tester.widget<Semantics>(finder).properties.label, 'Đã bật đèn flash');

    h.backend.onFlashAnnouncement?.call('Đã tắt đèn flash');
    await tester.pump();
    expect(
        tester.widget<Semantics>(finder).properties.label, 'Đã tắt đèn flash');
    expect(find.bySemanticsLabel('Đã tắt đèn flash'), findsOneWidget);
    expect(h.speech.spoken.length, priorSpeech);
    await unmount(tester);
    semantics.dispose();
  });

  testWidgets('TalkBack off: flash uses the existing app speech',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_touchExplorationChannel, (call) async {
      if (call.method == 'isTouchExplorationEnabled') return false;
      return null;
    });
    final h = AppHarness();
    await h.mount(tester);
    final priorSpeech = h.speech.spoken.length;
    h.backend.onFlashAnnouncement?.call('Đã bật đèn flash');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flash_talkback_status')), findsNothing);
    expect(h.speech.spoken.length, priorSpeech + 1);
    expect(h.speech.spoken.last, 'Đã bật đèn flash');
    await unmount(tester);
  });
}
