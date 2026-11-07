import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen({required bool talkBack, required int total}) {
  return MaterialApp(
    home: RecognitionScreen(
      state: const RecognitionUiState(
        status: RecognitionUiStatus.scanning,
        isMock: false,
      ),
      onOpenSettings: () {},
      isMoneyCounting: true,
      totalVnd: total,
      noteCount: total == 0 ? 0 : 1,
      screenReaderActive: talkBack,
    ),
  );
}

void main() {
  testWidgets('TalkBack khong doc tong tien dong khi camera cap nhat',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_screen(talkBack: true, total: 0));
    expect(find.text('0đ'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tổng tiền hiện tại')), findsNothing);
    expect(find.byKey(const Key('switch_mode_button')), findsOneWidget);
    await tester.pumpWidget(_screen(talkBack: true, total: 100000));
    expect(find.text('100.000đ'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tổng tiền hiện tại')), findsNothing);
    semantics.dispose();
  });

  testWidgets('Khong bat TalkBack van hien tong tien nhu cu', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_screen(talkBack: false, total: 100000));
    expect(find.bySemanticsLabel(RegExp('Tổng tiền hiện tại')), findsOneWidget);
    semantics.dispose();
  });
}
