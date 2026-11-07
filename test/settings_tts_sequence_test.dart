import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'support/app_fakes.dart';

// Models the production SpeechService's last-request-wins behavior: each new
// message stops the older pending one; the current message can be held for a
// navigation test. It records only actual requests, not discarded FIFO items.
class _InterruptibleSpeech extends TestSpeech {
  Completer<void>? _active;
  bool holdNewSpeech = false;

  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) {
    final previous = _active;
    if (previous != null && !previous.isCompleted) previous.complete();
    spoken.add(text);
    rates.add(rate);
    if (!holdNewSpeech) {
      _active = null;
      return Future.value();
    }
    final pending = Completer<void>();
    _active = pending;
    return pending.future;
  }

  void finishCurrent() {
    final current = _active;
    if (current != null && !current.isCompleted) current.complete();
    _active = null;
  }

  @override
  Future<void> stop() async {
    stops++;
    finishCurrent();
  }
}

Future<_InterruptibleSpeech> _mountSettings(WidgetTester tester) async {
  final speech = _InterruptibleSpeech();
  await tester.pumpWidget(MoneyRecognitionApp(
    backend: TestBackend(),
    speechService: speech,
    hapticService: TestHaptic(),
    settingsService: MemorySettings(),
  ));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Tùy chọn'));
  return speech;
}

Future<void> _pumpUntilRecognition(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    if (find.byType(RecognitionScreen).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Test tiếp theo sẽ báo lỗi nếu Navigator thật sự chưa pop.
}

void main() {
  testWidgets('Bấm Chậm → Nhanh → Vừa: phát ngay mức mới nhất, không FIFO',
      (tester) async {
    final speech = await _mountSettings(tester);
    speech.holdNewSpeech = true;
    final before = speech.spoken.length;
    await tapVisible(tester, find.byKey(const Key('speech_rate_slow')));
    expect(speech.spoken.last, contains('tốc độ chậm'));
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    expect(speech.spoken.last, contains('tốc độ nhanh'));
    await tapVisible(tester, find.byKey(const Key('speech_rate_normal')));
    expect(speech.spoken.last, contains('tốc độ vừa'));
    expect(speech.spoken.skip(before).toList(), [
      'Đã chọn tốc độ chậm. Đây là tốc độ đọc hiện tại.',
      'Đã chọn tốc độ nhanh. Đây là tốc độ đọc hiện tại.',
      'Đã chọn tốc độ vừa. Đây là tốc độ đọc hiện tại.',
    ]);
    expect(speech.rates.last, SpeechRateOption.normal);
    speech.finishCurrent();
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('Tốc độ mới ngắt lời bật/tắt rung đang phát', (tester) async {
    final speech = await _mountSettings(tester);
    speech.holdNewSpeech = true;
    await tapVisible(tester, find.byKey(const Key('vibration_switch')));
    expect(speech.spoken.last, contains('phản hồi rung'));
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    expect(speech.spoken.last, contains('tốc độ nhanh'));
    speech.finishCurrent();
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('Nút Back app đợi hết câu mới quay về camera', (tester) async {
    final speech = await _mountSettings(tester);
    speech.holdNewSpeech = true;
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    final previousCount = speech.spoken.length;
    // Đảm bảo nút Quay về có thể nhận tap kể cả khi trang vừa cuộn
    // xuống phần tốc độ giọng nói.
    final backButton = find.text('Quay lại camera');
    await tester.ensureVisible(backButton);
    await tester.pump();
    await tester.tap(backButton);
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(speech.spoken.length, previousCount);
    speech.holdNewSpeech = false;
    speech.finishCurrent();
    // Chờ thao tác Navigator.pop kết thúc thay vì giả định
    // pumpAndSettle xử lý xong mọi Future ngay sau khi mở gate.
    await _pumpUntilRecognition(tester);
    await tester.pumpAndSettle();
    expect(find.byType(RecognitionScreen), findsOneWidget);
    // Camera có thể đọc hướng dẫn tiếp ngay sau khi route đóng;
    // thông báo quay về vẫn phải xuất hiện sau lệnh bấm Back.
    expect(speech.spoken.skip(previousCount),
        contains('Đang quay lại màn hình nhận diện tiền.'));
    await unmount(tester);
  });

  testWidgets('Back Android cũng đợi hết câu xác nhận tốc độ', (tester) async {
    final speech = await _mountSettings(tester);
    speech.holdNewSpeech = true;
    await tapVisible(tester, find.byKey(const Key('speech_rate_slow')));
    final previousCount = speech.spoken.length;
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(speech.spoken.length, previousCount);
    speech.holdNewSpeech = false;
    speech.finishCurrent();
    // Chờ thao tác Navigator.pop kết thúc thay vì giả định
    // pumpAndSettle xử lý xong mọi Future ngay sau khi mở gate.
    await _pumpUntilRecognition(tester);
    await tester.pumpAndSettle();
    expect(find.byType(RecognitionScreen), findsOneWidget);
    // Camera có thể đọc hướng dẫn tiếp ngay sau khi route đóng;
    // thông báo quay về vẫn phải xuất hiện sau lệnh bấm Back.
    expect(speech.spoken.skip(previousCount),
        contains('Đang quay lại màn hình nhận diện tiền.'));
    await unmount(tester);
  });

  testWidgets('Mở Hướng dẫn: chờ hết câu đang đọc rồi mới mở', (tester) async {
    final speech = await _mountSettings(tester);
    speech.holdNewSpeech = true;
    await tapVisible(tester, find.byKey(const Key('speech_rate_fast')));
    final before = speech.spoken.length;
    // Nút Hướng dẫn có thể nằm phía trên vùng hiển thị sau khi chọn tốc độ.
    final guideButton = find.byKey(const Key('open_guide_button'));
    await tester.ensureVisible(guideButton);
    await tester.pumpAndSettle();
    await tester.tap(guideButton);
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(speech.spoken.length, before);
    speech.holdNewSpeech = false;
    speech.finishCurrent();
    await tester.pumpAndSettle();
    expect(speech.spoken, contains(AppStrings.spokenGuide));
    await unmount(tester);
  });

  testWidgets('Không có câu đang đọc: nút Back thông báo rồi quay về',
      (tester) async {
    final speech = await _mountSettings(tester);
    await tapVisible(tester, find.byTooltip('Quay lại'));
    // Camera có thể đã đọc tiếp câu "Hãy đưa một tờ tiền...".
    expect(speech.spoken, contains('Đang quay lại màn hình nhận diện tiền.'));
    expect(find.byType(RecognitionScreen), findsOneWidget);
    await unmount(tester);
  });
}
