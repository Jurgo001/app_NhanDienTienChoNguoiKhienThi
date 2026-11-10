import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _oldModeText =
    'Đã chuyển sang chế độ nhận diện tiền. Camera đã sẵn sàng.';

Widget _screen(RecognitionUiStatus status) => MaterialApp(
      home: RecognitionScreen(
        state: RecognitionUiState(status: status, isMock: false),
        onOpenSettings: () {},
        screenReaderActive: true,
        modeTalkBackAnnouncement: _oldModeText,
      ),
    );

void main() {
  testWidgets('TalkBack khong tu doc lai thong bao chuyen che do khi rut tien',
      (tester) async {
    final semantics = tester.ensureSemantics();
    for (final status in [
      RecognitionUiStatus.scanning,
      RecognitionUiStatus.recognized,
      RecognitionUiStatus.scanning,
    ]) {
      await tester.pumpWidget(_screen(status));
      expect(find.bySemanticsLabel(_oldModeText), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Trạng thái:')), findsNothing);
      expect(find.byKey(const Key('open_settings_button')), findsOneWidget);
    }
    semantics.dispose();
  });
}
