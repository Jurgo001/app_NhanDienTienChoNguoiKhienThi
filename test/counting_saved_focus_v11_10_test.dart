import 'package:app_ho_tro_nguoi_khiem_thi/controllers/money_counting_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/app_fakes.dart';

void main() {
  test('Luu tong va so to; mo lai app phuc hoi; reset luu 0 dong', () async {
    final store = MemorySettings();
    final first = MoneyCountingController(storage: store);
    await first.initialize();
    expect(first.totalVnd, 0);
    first.recordStableRecognition(Denomination.vnd50000);
    first.recordStableRecognition(Denomination.vnd100000);
    await first.flush();
    expect(store.storedCount.totalVnd, 150000);
    expect(store.storedCount.noteCount, 2);

    final reopened = MoneyCountingController(storage: store);
    await reopened.initialize();
    expect(reopened.totalVnd, 150000);
    expect(reopened.noteCount, 2);
    reopened.startNewSession();
    await reopened.flush();

    final afterReset = MoneyCountingController(storage: store);
    await afterReset.initialize();
    expect(afterReset.totalVnd, 0);
    expect(afterReset.noteCount, 0);
    first.dispose();
    reopened.dispose();
    afterReset.dispose();
  });

  testWidgets('TalkBack khong bam focus vao chu TO TIEN trong camera',
      (tester) async {
    final semantics = tester.ensureSemantics();
    Widget screen(Widget? preview) => MaterialApp(
          home: RecognitionScreen(
            state: const RecognitionUiState(
              status: RecognitionUiStatus.scanning,
              isMock: false,
            ),
            onOpenSettings: () {},
            onSwitchMode: () {},
            screenReaderActive: true,
            cameraPreview: preview,
          ),
        );
    await tester.pumpWidget(screen(null));
    expect(find.text('TỜ TIỀN'), findsOneWidget);
    expect(find.bySemanticsLabel('TỜ TIỀN'), findsNothing);
    expect(find.bySemanticsLabel('Chuyển chế độ'), findsOneWidget);

    // Show camera preview: the semantics node must not be replaced by a
    // disappearing fake banknote, or change the switch button's label.
    await tester.pumpWidget(screen(const ColoredBox(color: Colors.black)));
    expect(find.bySemanticsLabel('TỜ TIỀN'), findsNothing);
    expect(find.bySemanticsLabel('Chuyển chế độ'), findsOneWidget);
    semantics.dispose();
  });
}
