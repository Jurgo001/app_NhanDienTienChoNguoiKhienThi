import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('Dem tien: to dau tien duoc nhan ngay sau khi chuyen che do',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);

    // V11.2: phim volume mac dinh thuoc Android. Phai chuyen bang nut UI.
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(
        find.byKey(const Key('new_counting_session_button')), findsOneWidget);

    // Khong can doi camera trong neu chua co to tien truoc do.
    h.backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);
    expect(h.speech.spoken.any((s) => s.contains('Tổng hiện tại')), isTrue);
    await unmount(tester);
  });

  testWidgets('Dem tien: to dat san duoc dem mot lan sau khi camera san sang',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);

    // The same note may already have been seen in Recognition mode.
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(
        find.byKey(const Key('new_counting_session_button')), findsOneWidget);
    expect(find.text('0đ'), findsOneWidget);

    // The first note already in view must count after readiness. The mode
    // speech gate is exercised separately by mode_speech_gate_v11_5_test.dart.
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    expect(find.text('0đ'), findsNothing);
    expect(h.speech.spoken.any((s) => s.contains('Tổng hiện tại')), isTrue);

    // Keeping that same note in view must NOT add it again.
    final spokenBefore = h.speech.spoken.length;
    h.backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    expect(h.speech.spoken.length, spokenBefore);
    await unmount(tester);
  });
}
