import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_colors.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/accessible_button.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/mobile_page.dart';

void main() {
  testWidgets('TalkBack can browse saved total, without live announcement',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: RecognitionScreen(
        state: const RecognitionUiState(
            status: RecognitionUiStatus.scanning, isMock: false),
        onOpenSettings: () {},
        isMoneyCounting: true,
        totalVnd: 150000,
        noteCount: 2,
        screenReaderActive: true,
      ),
    ));
    expect(find.bySemanticsLabel(RegExp('Tổng tiền hiện tại')), findsOneWidget);
    expect(find.byKey(const Key('counting_total_card')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Reset is visually destructive; Settings remains neutral',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecognitionScreen(
        state: const RecognitionUiState(
            status: RecognitionUiStatus.scanning, isMock: false),
        onOpenSettings: () {},
        isMoneyCounting: true,
        onNewCountingSession: () {},
      ),
    ));
    final reset = tester.widget<AccessibleButton>(
        find.byKey(const Key('new_counting_session_button')));
    final settings = tester.widget<AccessibleButton>(
        find.byKey(const Key('open_settings_button')));
    expect(reset.destructive, isTrue);
    expect(settings.destructive, isFalse);
    expect(AppColors.error, isNot(AppColors.navy));
  });

  testWidgets('Camera timeout exposes explicit recovery action',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: RecognitionScreen(
        state: const RecognitionUiState(
            status: RecognitionUiStatus.scanning, isMock: false),
        onOpenSettings: () {},
        isMockBackend: false,
        serviceNotice: 'Camera chưa sẵn sàng.',
        cameraRetryRequired: true,
        onRetryCamera: () => retried = true,
      ),
    ));
    final retry = find.byKey(const Key('retry_camera_after_timeout_button'));
    expect(retry, findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    expect(retried, isTrue);
  });

  testWidgets('Guide uses dark page background', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GuideScreen(onAutoRead: () async {}, onReadCompleted: () {}),
    ));
    await tester.pump();
    final page = tester.widget<MobilePage>(find.byType(MobilePage));
    expect(page.background, AppColors.navySoft);
  });
}
