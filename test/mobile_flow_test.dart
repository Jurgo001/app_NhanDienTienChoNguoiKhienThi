import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Huong dan tu doc, doc 6 buoc va tro ve camera', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    await tapVisible(tester, find.text('Hướng dẫn sử dụng'));
    expect(h.speech.spoken.contains(AppStrings.spokenGuide), isTrue);
    expect(AppStrings.spokenGuide, contains('Bước sáu'));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(find.byKey(const Key('listen_guide_button')), findsNothing);
    expect(find.byKey(const Key('start_recognition_button')), findsNothing);
    await unmount(tester);
  });

  testWidgets('Tu dong khoi phuc khi camera bi chan', (tester) async {
    final h = AppHarness();
    h.backend.access = CameraAccess.permanentlyDenied;
    h.backend.requestedAccess = CameraAccess.permanentlyDenied;
    await h.mount(tester);
    expect(find.byKey(const Key('grant_camera_button')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('grant_camera_button')));
    expect(h.backend.settingsOpened, 1);
    await tapVisible(
        tester, find.byKey(const Key('continue_without_camera_button')));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Desktop giữ khung mobile khi điều hướng', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = AppHarness();
    await h.mount(tester);
    expect(tester.getSize(find.byType(Scaffold)), const Size(390, 844));
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(tester.getSize(find.byType(Scaffold).last).width, 390);
    await tapVisible(tester, find.text('Hướng dẫn sử dụng'));
    expect(tester.getSize(find.byType(Scaffold).last).width, 390);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Rời màn hình dừng camera; quay về tạo callback mới',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    final old = h.backend.callbacks.single;
    await tapVisible(tester, find.text(AppStrings.settingsTitle));
    expect(h.backend.releases, greaterThanOrEqualTo(1));
    await tapVisible(tester, find.byTooltip('Quay lại'));
    expect(h.backend.callbacks, hasLength(2));
    // Callback phiên cũ không được làm UI đổi kết quả.
    for (var i = 0; i < 3; i++) {
      // Gửi từ nguồn cũ, không phải callback mới sau resume.
      old(DetectionResult(
          status: DetectionStatus.detected,
          denomination: Denomination.vnd100000,
          confidence: .95));
    }
    await tester.pumpAndSettle();
    expect(find.text('100.000 VNĐ'), findsNothing);
    h.backend.recognize();
    await tester.pumpAndSettle();
    expect(find.text('100.000 VNĐ'), findsOneWidget);
    await unmount(tester);
  });
}
