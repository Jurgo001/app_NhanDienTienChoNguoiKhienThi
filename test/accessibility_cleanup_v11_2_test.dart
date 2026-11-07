import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/recognition_status.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/denomination_card.dart';
import 'support/app_fakes.dart';

void main() {
  test('Phim tat am luong mac dinh tat va copyWith giu gia tri', () {
    const settings = AppSettings();
    expect(settings.hardwareShortcutsEnabled, isFalse);
    final next = settings.copyWith(hardwareShortcutsEnabled: true);
    expect(next.hardwareShortcutsEnabled, isTrue);
    expect(
        next
            .copyWith(speechRate: SpeechRateOption.fast)
            .hardwareShortcutsEnabled,
        isTrue);
  });

  testWidgets('Nhan dien: khong con nut nghe lai va reset', (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    expect(find.byType(RecognitionScreen), findsOneWidget);
    expect(find.byKey(const Key('repeat_latest_result_button')), findsNothing);
    expect(find.byKey(const Key('new_counting_session_button')), findsNothing);
    expect(find.byKey(const Key('switch_mode_button')), findsOneWidget);
    expect(
        tester
            .widget<RecognitionStatus>(find.byType(RecognitionStatus))
            .announceChanges,
        isFalse);
    expect(
        tester
            .widget<DenominationCard>(find.byType(DenominationCard))
            .announceChanges,
        isFalse);
    await unmount(tester);
  });

  testWidgets('Dem tien: chi co chuyen che do, reset, tuy chon',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.byKey(const Key('switch_mode_button')));
    expect(
        find.byKey(const Key('new_counting_session_button')), findsOneWidget);
    expect(find.byKey(const Key('repeat_latest_result_button')), findsNothing);
    final startSpeech = h.speech.spoken.length;
    await tapVisible(tester, find.byKey(const Key('counting_total_card')));
    expect(h.speech.spoken.length, greaterThan(startSpeech));
    expect(h.speech.spoken.last, contains('Tổng hiện tại'));
    await unmount(tester);
  });

  testWidgets('Cho phep bat/tat phim tat trong Tuy chon, luu lai',
      (tester) async {
    final h = AppHarness();
    await h.mount(tester);
    await tapVisible(tester, find.text('Tùy chọn'));
    final toggle = find.byKey(const Key('hardware_shortcuts_switch'));
    expect(toggle, findsOneWidget);
    await tapVisible(tester, toggle);
    expect(h.settings.saved.hardwareShortcutsEnabled, isTrue);
    await unmount(tester);
  });
}
