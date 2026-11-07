import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Nut Tuy chon to va khong con hai nut goc', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    expect(find.byKey(const Key('open_settings_button')), findsOneWidget);
    expect(find.text(AppStrings.cameraPermissionTitle), findsNothing);
    expect(find.text(AppStrings.guideTitle), findsNothing);
    await unmount(tester);
  });

  testWidgets('Toc do chon duoc xac nhan bang dung TTS', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tapVisible(tester, find.text(AppStrings.slow));
    expect(h.settings.saved.speechRate, SpeechRateOption.slow);
    expect(h.speech.spoken.last, contains('Đã chọn tốc độ chậm'));
    expect(h.speech.rates.last, SpeechRateOption.slow);
    await unmount(tester);
  });

  testWidgets('Bat tat rung co loi xac nhan TTS', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tapVisible(tester, find.byKey(const Key('vibration_switch')));
    expect(h.settings.saved.vibrationEnabled, isFalse);
    expect(h.speech.spoken.last, 'Đã tắt phản hồi rung.');
    await unmount(tester);
  });

  testWidgets('Guide khong co nut thao tac cu', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GuideScreen(onAutoRead: () async {}, onReadCompleted: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);
    expect(find.byKey(const Key('listen_guide_button')), findsNothing);
    expect(find.byKey(const Key('start_recognition_button')), findsNothing);
    expect(find.text('Điều khiển chế độ và âm lượng'), findsOneWidget);
  });

  testWidgets('TalkBack khong tu dong dong trang huong dan', (tester) async {
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: GuideScreen(
          onAutoRead: () async {},
          onReadCompleted: () => closed = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.byType(GuideScreen), findsOneWidget);
  });

  testWidgets('Camera bi tu choi van co nut cap quyen lai', (tester) async {
    final h = AppHarness();
    h.backend.access = CameraAccess.denied;
    h.backend.requestedAccess = CameraAccess.denied;
    await h.mount(tester);
    await tapVisible(
        tester, find.byKey(const Key('continue_without_camera_button')));
    expect(find.byKey(const Key('recover_camera_permission_button')),
        findsOneWidget);
    await unmount(tester);
  });
}
