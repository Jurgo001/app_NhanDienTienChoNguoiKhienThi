import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/permission/camera_permission_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Menu mở Hướng dẫn, quay về Menu và bắt đầu về màn chính',
      (tester) async {
    await tester.pumpWidget(const MoneyRecognitionApp());
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tapVisible(tester, find.text(AppStrings.listenGuide));
    expect(find.byType(GuideScreen), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Quay lại'));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tapVisible(tester, find.text(AppStrings.listenGuide));
    await tapVisible(tester, find.byKey(const Key('start_recognition_button')));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu mở quyền camera và cấp quyền một lần trở về Menu',
      (tester) async {
    await tester.pumpWidget(const MoneyRecognitionApp());
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tapVisible(tester, find.text('Camera và quyền truy cập'));
    expect(find.byType(CameraPermissionScreen), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('grant_camera_once_button')));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chrome giữ khung mobile cho cả màn chính và màn phụ',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MoneyRecognitionApp());
    expect(tester.getSize(find.byType(Scaffold)).width, 390);
    expect(tester.getSize(find.byType(Scaffold)).height, 844);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(tester.getSize(find.byType(Scaffold).last).width, 390);
    await tapVisible(tester, find.text(AppStrings.listenGuide));
    expect(tester.getSize(find.byType(Scaffold).last).width, 390);
    expect(tester.takeException(), isNull);
  });
}
