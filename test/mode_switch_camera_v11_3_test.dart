import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/hardware_volume_shortcuts.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Doi che do khoi dong camera sau thong bao', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    final beforeInit = h.backend.initializations;
    final beforeStop = h.backend.stops;
    final beforeRelease = h.backend.releases;
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(h.backend.initializations, greaterThan(beforeInit));
    expect(h.backend.stops, greaterThan(beforeStop));
    expect(h.backend.releases, beforeRelease);
    h.backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Phim giam phai giu hai lan de xoa phien', (tester) async {
    final h = AppHarness();
    h.settings.saved = const AppSettings(hardwareShortcutsEnabled: true);
    await h.mount(tester);
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    h.backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);
    final beforeStop = h.backend.stops;

    // The first physical hold only warns, not resets.
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.newSession);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('100.000đ'), findsOneWidget);
    expect(h.backend.stops, beforeStop);
    expect(
        h.speech.spoken.any(
            (text) => text.contains('Giữ phím giảm âm lượng thêm lần nữa')),
        isTrue);

    // Only a second independent hold confirms reset.
    await HardwareVolumeShortcuts.simulateHold(VolumeHoldAction.newSession);
    await tester.pumpAndSettle();
    expect(find.text('0đ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Nut reset man hinh co huy va xac nhan lon', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    final beforeStop = h.backend.stops;
    await tapVisible(
        tester, find.byKey(const Key('new_counting_session_button')));
    final cancel = find.byKey(const Key('cancel_count_reset_button'));
    final confirm = find.byKey(const Key('confirm_count_reset_button'));
    expect(cancel, findsOneWidget);
    expect(confirm, findsOneWidget);
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(72));
    expect(tester.getSize(confirm).height, greaterThanOrEqualTo(72));
    expect(h.backend.stops, beforeStop);
    await tapVisible(tester, cancel);
    expect(find.text('50.000đ'), findsOneWidget);
    await unmount(tester);
  });
}
