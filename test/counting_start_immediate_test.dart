import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/hardware_volume_shortcuts.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Vua chuyen sang dem tien thi to dau tien duoc nhan ngay',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.switchMode);
    await tester.pumpAndSettle();

    // No empty camera frames or artificial 1.1-second delay required.
    // The model still has to produce three stable frames.
    h.backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);
    expect(h.speech.spoken.any((s) => s.contains('Tổng hiện tại')), isTrue);
    await unmount(tester);
  });

  testWidgets('Da thay tien truoc luc chuyen che do thi phai rut ra',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    // Recognize a note in recognition-only mode before changing modes.
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.switchMode);
    await tester.pumpAndSettle();

    // The note shown before switching is not silently added to the new count.
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    expect(find.text('50.000đ'), findsNothing);
    expect(h.speech.spoken.last, contains('đưa tờ tiền'));
    await unmount(tester);
  });
}
