import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'support/app_fakes.dart';

void main() {
  testWidgets('V11: chuyển chế độ bằng nút, giữ tổng cũ; reset cần xác nhận',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);

    // Phím âm lượng nay thuộc Android; màn hình cần nút chuyển chế độ.
    expect(find.byKey(const Key('switch_mode_button')), findsOneWidget);
    expect(find.byKey(const Key('new_counting_session_button')), findsNothing);

    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(
        find.byKey(const Key('new_counting_session_button')), findsOneWidget);
    expect(h.speech.spoken.any((s) => s.contains('chế độ đếm tiền')), isTrue);

    // Đếm một tờ 100.000 đồng.
    h.backend.recognize(Denomination.vnd100000);
    await tester.pumpAndSettle();
    expect(find.text('100.000đ'), findsOneWidget);

    // Chuyển đi rồi về không làm mất tổng tiền đã đếm.
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(find.byKey(const Key('new_counting_session_button')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(find.text('100.000đ'), findsOneWidget);

    // Hủy xác nhận không làm mất tiền.
    await tapVisible(
        tester, find.byKey(const Key('new_counting_session_button')));
    expect(find.text('Bắt đầu phiên đếm mới?'), findsOneWidget);
    await tapVisible(tester, find.text('Hủy'));
    expect(find.text('100.000đ'), findsOneWidget);

    // Chỉ đặt về 0 sau khi nhấn Xác nhận xóa phiên.
    await tapVisible(
        tester, find.byKey(const Key('new_counting_session_button')));
    await tapVisible(tester, find.text('Xác nhận xóa phiên'));
    expect(find.text('0đ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('V11: không có nút reset khi ở chế độ nhận diện', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    expect(find.byKey(const Key('switch_mode_button')), findsOneWidget);
    expect(find.byKey(const Key('new_counting_session_button')), findsNothing);
    await unmount(tester);
  });
}
