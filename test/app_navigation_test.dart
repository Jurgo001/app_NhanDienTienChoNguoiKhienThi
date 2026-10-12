import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/permission/camera_permission_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/accessible_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final messenger = find.byType(ScaffoldMessenger);
  if (messenger.evaluate().isNotEmpty) {
    tester
        .state<ScaffoldMessengerState>(messenger.first)
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Đi tới và quay lại từ Cài đặt, Hướng dẫn, Quyền camera', (
    tester,
  ) async {
    await tester.pumpWidget(const MoneyRecognitionApp());

    await _tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Quay lại'));
    expect(find.byType(RecognitionScreen), findsOneWidget);

    await _tapVisible(tester, find.text(AppStrings.guideTitle));
    expect(find.byType(GuideScreen), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('listen_guide_button')));
    expect(find.text(AppStrings.listenGuideMockNotice), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Quay lại'));
    expect(find.byType(RecognitionScreen), findsOneWidget);

    await _tapVisible(tester, find.text(AppStrings.cameraPermissionTitle));
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('deny_camera_button')));
    expect(find.text(AppStrings.permissionDeniedTitle), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const Key('continue_without_camera_button')),
    );
    expect(find.byType(RecognitionScreen), findsOneWidget);

    await _tapVisible(tester, find.text(AppStrings.cameraPermissionTitle));
    await _tapVisible(tester, find.byKey(const Key('grant_camera_button')));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(find.text(AppStrings.permissionApprovedMockNotice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo bật Đọc lại, Quét lại xóa kết quả và các trạng thái', (
    tester,
  ) async {
    await tester.pumpWidget(const MoneyRecognitionApp());
    expect(
      tester
          .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
          .onPressed,
      isNull,
    );

    await _tapVisible(tester, find.byKey(const Key('demo_recognized_button')));
    expect(find.text(AppStrings.mockDenomination), findsOneWidget);
    expect(
      tester
          .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
          .onPressed,
      isNotNull,
    );
    await _tapVisible(tester, find.byKey(const Key('replay_button')));
    expect(find.text(AppStrings.replayMockNotice), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('scan_button')));
    expect(find.text(AppStrings.mockDenomination), findsNothing);
    expect(find.text(AppStrings.scanningTitle), findsOneWidget);
    expect(
      tester
          .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
          .onPressed,
      isNull,
    );

    await _tapVisible(tester, find.byKey(const Key('demo_unclear_button')));
    expect(find.text(AppStrings.unclearMessage), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('demo_error_button')));
    expect(find.text(AppStrings.errorMessage), findsOneWidget);
    expect(find.text(AppStrings.mockDenomination), findsNothing);
  });

  testWidgets('Cài đặt giữ giá trị khi rời màn hình rồi mở lại', (
    tester,
  ) async {
    await tester.pumpWidget(const MoneyRecognitionApp());
    await _tapVisible(tester, find.text(AppStrings.settingsTitle));

    await _tapVisible(tester, find.byKey(const Key('auto_read_switch')));
    await _tapVisible(tester, find.byKey(const Key('vibration_switch')));
    await _tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('auto_read_switch')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('vibration_switch')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('speech_rate_fast')))
          .selected,
      isTrue,
    );

    await _tapVisible(tester, find.byTooltip('Quay lại'));
    await _tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('auto_read_switch')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('vibration_switch')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('speech_rate_fast')))
          .selected,
      isTrue,
    );
  });

  testWidgets('Màn phụ vẫn cuộn ở 320×568, chữ phóng gấp đôi', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(const MoneyRecognitionApp());

    await _tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tester.ensureVisible(find.byKey(const Key('speech_rate_fast')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _tapVisible(tester, find.byTooltip('Quay lại'));

    await _tapVisible(tester, find.text(AppStrings.guideTitle));
    await tester.ensureVisible(find.byKey(const Key('listen_guide_button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _tapVisible(tester, find.byTooltip('Quay lại'));

    await _tapVisible(tester, find.text(AppStrings.cameraPermissionTitle));
    await tester.ensureVisible(find.byKey(const Key('deny_camera_button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
