import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/permission/camera_permission_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/accessible_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets(
      'Bốn màn điều hướng, nghe hướng dẫn và xin quyền thật qua backend',
      (tester) async {
    final h = AppHarness();
    h.backend.access = CameraAccess.denied;
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Quay lại'));
    await tapVisible(tester, find.text(AppStrings.guideTitle));
    expect(find.byType(GuideScreen), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('listen_guide_button')));
    expect(h.speech.spoken.single, AppStrings.spokenGuide);
    await tapVisible(tester, find.byTooltip('Quay lại'));
    await tapVisible(tester, find.text(AppStrings.cameraPermissionTitle));
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('grant_camera_button')));
    expect(h.backend.access, CameraAccess.granted);
    expect(find.textContaining('Đã được cấp quyền camera.'), findsOneWidget);
    await tapVisible(
        tester, find.byKey(const Key('continue_without_camera_button')));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Frame → UI → TTS/rung; Đọc lại và Quét lại hoạt động',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    expect(
        tester
            .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
            .onPressed,
        isNull);
    await tapVisible(tester, find.byKey(const Key('scan_button')));
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    expect(find.text('50.000 VNĐ'), findsOneWidget);
    expect(find.text('Năm mươi nghìn đồng'), findsOneWidget);
    expect(h.speech.spoken, ['Năm mươi nghìn đồng']);
    expect(h.haptic.successes, 1);
    await tapVisible(tester, find.byKey(const Key('replay_button')));
    expect(h.speech.spoken, hasLength(2));
    await tapVisible(tester, find.byKey(const Key('scan_button')));
    expect(find.text('50.000 VNĐ'), findsNothing);
    expect(find.text(AppStrings.scanningTitle), findsOneWidget);
    expect(
        tester
            .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Thay đổi nhanh cài đặt được lưu và còn sau khi tạo lại app',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tapVisible(tester, find.byKey(const Key('auto_read_switch')));
    await tapVisible(tester, find.byKey(const Key('vibration_switch')));
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    await unmount(tester);
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(
        tester
            .widget<Semantics>(find.byKey(const Key('auto_read_switch')))
            .properties
            .toggled,
        isFalse);
    expect(
        tester
            .widget<Semantics>(find.byKey(const Key('vibration_switch')))
            .properties
            .toggled,
        isFalse);
    expect(
        tester
            .widget<Semantics>(find.byKey(const Key('speech_rate_fast')))
            .properties
            .selected,
        isTrue);
    await unmount(tester);
  });

  testWidgets('Màn phụ vẫn cuộn ở 320×568 và cỡ chữ gấp đôi', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final h = AppHarness();
    h.backend.access = CameraAccess.denied;
    await h.mount(tester);
    for (final label in [
      AppStrings.settingsTitle,
      AppStrings.guideTitle,
      AppStrings.cameraPermissionTitle
    ]) {
      await tapVisible(tester, find.text(label));
      final target = label == AppStrings.settingsTitle
          ? 'speech_rate_fast'
          : label == AppStrings.guideTitle
              ? 'listen_guide_button'
              : 'grant_camera_button';
      await tester.ensureVisible(find.byKey(Key(target)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byTooltip('Quay lại'));
    }
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
