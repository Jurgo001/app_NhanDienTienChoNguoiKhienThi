import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/hardware_volume_shortcuts.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Phim + doi che do, tu tiep tuc tong cu; phim - tao phien moi',
      (tester) async {
    final harness = AppHarness();
    await harness.mount(tester);

    // Không còn nút chuyển chế độ trong giao diện.
    expect(find.text('Chuyển sang đếm tiền'), findsNothing);
    expect(find.text('Chuyển sang nhận diện tiền'), findsNothing);

    // Mô phỏng sự kiện ĐÃ được Android xác nhận là giữ đủ 3 giây.
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.switchMode);
    await tester.pumpAndSettle();
    expect(harness.speech.spoken.last, contains('chế độ đếm tiền'));

    // Khi mới đổi chế độ phải đưa hết tiền ra khỏi camera 1,1 giây.
    harness.backend.emit(DetectionResult.empty(isMock: false));
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 1250),
        ));
    for (var i = 0; i < 4; i++) {
      harness.backend.emit(DetectionResult.empty(isMock: false));
    }
    await tester.pumpAndSettle();

    harness.backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);

    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.switchMode);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsNothing);

    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.switchMode);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);
    expect(harness.speech.spoken.last, contains('Tiếp tục phiên trước'));

    // Không cần qua menu hoặc hộp thoại để tạo phiên mới.
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.newSession);
    await tester.pumpAndSettle();
    expect(find.text('0đ'), findsOneWidget);
    expect(harness.speech.spoken.last, contains('Đã bắt đầu phiên đếm mới'));
    await unmount(tester);
  });

  testWidgets('Phim - ngoai che do dem khong xoa tong', (tester) async {
    final harness = AppHarness();
    await harness.mount(tester);
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.newSession);
    await tester.pumpAndSettle();
    expect(
        harness.speech.spoken.any((s) => s.contains('phiên đếm mới')), isFalse);
    await unmount(tester);
  });
}
