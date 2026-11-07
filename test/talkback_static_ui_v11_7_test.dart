import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen({required bool talkback, required RecognitionUiStatus status}) {
  return MaterialApp(
    home: RecognitionScreen(
      state: RecognitionUiState(
        status: status,
        denomination:
            status == RecognitionUiStatus.recognized ? '100.000đ' : null,
        spokenDenomination: status == RecognitionUiStatus.recognized
            ? 'Một trăm nghìn đồng'
            : null,
        isMock: false,
      ),
      onOpenSettings: () {},
      screenReaderActive: talkback,
      modeTalkBackAnnouncement:
          'Đã chuyển sang chế độ nhận diện tiền. Camera đã sẵn sàng.',
    ),
  );
}

void main() {
  testWidgets('TalkBack chi doc UI; ket qua va trang thai khong chiem focus',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _screen(talkback: true, status: RecognitionUiStatus.recognized),
    );
    expect(find.text('100.000đ'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('100.000đ')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Một trăm nghìn đồng')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Trạng thái:')), findsNothing);
    expect(
        find.bySemanticsLabel(RegExp('Đã chuyển sang chế độ nhận diện tiền')),
        findsNothing);
    expect(find.byKey(const Key('open_settings_button')), findsOneWidget);
    await tester.pumpWidget(
      _screen(talkback: true, status: RecognitionUiStatus.scanning),
    );
    expect(find.bySemanticsLabel(RegExp('100.000đ')), findsNothing);
    expect(find.byKey(const Key('open_settings_button')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Khi TalkBack tat van giu nhan trang thai va menh gia',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _screen(talkback: false, status: RecognitionUiStatus.recognized),
    );
    expect(find.bySemanticsLabel(RegExp('100.000đ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Trạng thái:')), findsOneWidget);
    semantics.dispose();
  });
}
