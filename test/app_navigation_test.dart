import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/permission/camera_permission_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Huong dan trong Tuy chon tu doc va tu tro ve camera',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tapVisible(tester, find.text('Hướng dẫn sử dụng'));
    expect(h.speech.spoken, contains(AppStrings.spokenGuide));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Quyen camera tu mo duong khac phuc va cap lai duoc',
      (tester) async {
    final h = AppHarness();
    h.backend.access = CameraAccess.denied;
    h.backend.requestedAccess = CameraAccess.denied;
    await h.mount(tester);
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
    h.backend.requestedAccess = CameraAccess.granted;
    await tapVisible(tester, find.byKey(const Key('grant_camera_button')));
    expect(h.backend.access, CameraAccess.granted);
    await tapVisible(
        tester, find.byKey(const Key('continue_without_camera_button')));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Recognition screen has no manual replay or reset controls',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    expect(find.byKey(const Key('replay_button')), findsNothing);
    expect(find.byKey(const Key('scan_button')), findsNothing);
    await unmount(tester);
  });

  testWidgets('Vibration and speech rate persist without an auto-read toggle',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(find.byKey(const Key('auto_read_switch')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('vibration_switch')));
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    await unmount(tester);
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('vibration_switch')))
          .properties
          .toggled,
      isFalse,
    );
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('speech_rate_fast')))
          .properties
          .selected,
      isTrue,
    );
    await unmount(tester);
  });

  testWidgets('Tuy chon cuon duoc o 320x568 va chu gap doi', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final h = AppHarness();
    await h.mount(tester);

    // Tap the actual clickable button after scrolling, not its Text child.
    final openSettings = find.byKey(const Key('open_settings_button'));
    await tester.ensureVisible(openSettings);
    await tester.pumpAndSettle();
    final settingsAction = find.descendant(
      of: openSettings,
      matching: find.byType(OutlinedButton),
    );
    expect(settingsAction, findsOneWidget);
    await tester.tap(settingsAction);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Verify the controls remain scroll-reachable at 200% text scale.
    final rateControl = find.byKey(const Key('speech_rate_fast'));
    await tester.ensureVisible(rateControl);
    await tester.pumpAndSettle();
    final rateRect = tester.getRect(rateControl);
    expect(rateRect.top, greaterThanOrEqualTo(0));
    expect(rateRect.bottom, lessThanOrEqualTo(568));

    final openGuide = find.byKey(const Key('open_guide_button'));
    await tester.ensureVisible(openGuide);
    await tester.pumpAndSettle();
    final guideAction = find.descendant(
      of: openGuide,
      matching: find.byType(OutlinedButton),
    );
    expect(guideAction, findsOneWidget);
    await tester.tap(guideAction);
    await tester.pumpAndSettle();

    // Test the real navigation side effect: the six-step narration begins.
    expect(h.speech.spoken, contains(AppStrings.spokenGuide));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Thiếu TTS không chặn mở app và có thể thử lại', (tester) async {
    final h = AppHarness();
    h.speech.initializeError = StateError('missing voice');
    await h.mount(tester);
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(find.textContaining('Giọng nói chưa sẵn sàng'), findsOneWidget);
    h.speech.initializeError = null;
    await tapVisible(tester, find.text('Thử lại âm thanh / cài đặt'));
    expect(find.textContaining('Giọng nói chưa sẵn sàng'), findsNothing);
    await unmount(tester);
  });
}
