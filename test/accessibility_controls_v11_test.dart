import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'support/app_fakes.dart';

const _channel = MethodChannel('money_recognition/touch_exploration');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'isTouchExplorationEnabled') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('TalkBack: setting change does not trigger duplicate app TTS',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text('Tùy chọn'));
    final n = h.speech.spoken.length;
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    await tapVisible(tester, find.byKey(const Key('vibration_switch')));
    expect(h.speech.spoken.length, n);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Mode switch is accessible without volume-button shortcut',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(find.byKey(const Key('switch_mode_button')), findsOneWidget);
    expect(find.byKey(const Key('new_counting_session_button')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('new_counting_session_button')), findsOneWidget);
    expect(find.byKey(const Key('repeat_latest_result_button')), findsNothing);
    await unmount(tester);
  });

  testWidgets(
      'Reset requires explicit user confirmation; cancel preserves count',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const Key('new_counting_session_button')));
    expect(find.text('Bắt đầu phiên đếm mới?'), findsOneWidget);
    await tapVisible(tester, find.text('Hủy'));
    expect(find.text('Bắt đầu phiên đếm mới?'), findsNothing);
    await unmount(tester);
  });
}
