import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'support/app_fakes.dart';

class _GateSpeech extends TestSpeech {
  Completer<void>? blockNext;

  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) async {
    spoken.add(text);
    rates.add(rate);
    final gate = blockNext;
    blockNext = null;
    if (gate != null) await gate.future;
  }
}

void main() {
  testWidgets('TTS chỉnh tốc độ đọc xong mới thông báo trạng thái rung',
      (tester) async {
    final backend = TestBackend();
    final speech = _GateSpeech();
    final haptic = TestHaptic();
    final store = MemorySettings();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: haptic,
      settingsService: store,
    ));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Tùy chọn'));

    final before = speech.spoken.length;
    final gate = Completer<void>();
    speech.blockNext = gate;
    await tapVisible(tester, find.byKey(const Key('speech_rate_slow')));
    expect(store.saved.speechRate, SpeechRateOption.slow);
    expect(speech.spoken.length, before + 1);
    expect(speech.spoken.last, contains('Đã chọn tốc độ chậm'));
    expect(speech.rates.last, SpeechRateOption.slow);

    await tapVisible(tester, find.byKey(const Key('vibration_switch')));
    expect(store.saved.vibrationEnabled, isFalse);
    // While the previous announcement is held, the second may NOT start.
    expect(speech.spoken.length, before + 1);

    gate.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(speech.spoken.length, before + 2);
    expect(speech.spoken.last, 'Đã tắt phản hồi rung.');
    expect(speech.rates.last, SpeechRateOption.slow);

    await unmount(tester);
  });

  testWidgets('Nút Quay về thông báo bằng TTS trước khi trở lại camera',
      (tester) async {
    final speech = TestSpeech();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: TestBackend(),
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Tùy chọn'));
    await tapVisible(tester, find.byTooltip('Quay lại'));
    expect(
      speech.spoken
          .any((s) => s.contains('Đang quay lại màn hình nhận diện tiền')),
      isTrue,
    );
    expect(find.byType(RecognitionScreen), findsOneWidget);
    await unmount(tester);
  });
}
