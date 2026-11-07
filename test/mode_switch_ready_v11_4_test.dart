import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'support/app_fakes.dart';

class _SlowModeSpeech extends TestSpeech {
  Completer<void>? modeGate;
  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) async {
    spoken.add(text);
    rates.add(rate);
    if (text.contains('Đã chuyển sang chế độ đếm tiền')) {
      final gate = modeGate;
      if (gate != null) await gate.future;
    }
  }
}

void main() {
  testWidgets('Doc het thong bao roi moi mo camera dem tien', (tester) async {
    final backend = TestBackend();
    final speech = _SlowModeSpeech()..modeGate = Completer<void>();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    final startsBefore = backend.callbacks.length;
    final switchButton = find.byKey(const Key('switch_mode_button'));
    await tester.ensureVisible(switchButton);
    await tester.pumpAndSettle();
    await tester.tap(switchButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        speech.spoken.any((x) => x.contains('Đã chuyển sang chế độ đếm tiền')),
        isTrue);
    // While TTS is blocked, new camera stream is not started yet.
    expect(backend.callbacks.length, startsBefore);
    speech.modeGate!.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(backend.callbacks.length, startsBefore + 1);
    expect(
        find.byKey(const Key('new_counting_session_button')), findsOneWidget);
    await unmount(tester);
  });
}
