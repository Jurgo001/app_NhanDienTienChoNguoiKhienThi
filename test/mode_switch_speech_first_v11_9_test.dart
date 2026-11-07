import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'support/app_fakes.dart';

class _HoldModeSpeech extends TestSpeech {
  Completer<void>? modeGate;

  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) async {
    spoken.add(text);
    rates.add(rate);
    if (text.contains('Đã chuyển sang chế độ') && modeGate != null) {
      await modeGate!.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TalkBack bat: phai doc xong truoc khi khoi dong camera dem',
      (tester) async {
    const channel = MethodChannel('money_recognition/touch_exploration');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? true : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final backend = TestBackend();
    final speech = _HoldModeSpeech();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();

    // Simulate a note that has already been recognized before switching.
    backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();

    final before = backend.callbacks.length;
    final gate = Completer<void>();
    speech.modeGate = gate;
    final switchButton = find.byKey(const Key('switch_mode_button'));
    await tester.ensureVisible(switchButton);
    await tester.pumpAndSettle();
    await tester.tap(switchButton);
    await tester.pump(const Duration(milliseconds: 150));

    // TalkBack enabled MUST NOT skip the app speech and start early.
    expect(
        speech.spoken.any((x) => x.contains('Đã chuyển sang chế độ đếm tiền')),
        isTrue);
    expect(backend.callbacks.length, before);

    gate.complete();
    await tester.pumpAndSettle();
    expect(backend.callbacks.length, greaterThan(before));

    // A preloaded banknote can be accepted after narration with no forced
    // empty-camera frame; the existing controller then prevents duplicates.
    backend.recognize(Denomination.vnd50000);
    await tester.pumpAndSettle();
    expect(find.text('0đ'), findsNothing);
    expect(speech.spoken.any((x) => x.contains('Tổng hiện tại')), isTrue);
    await unmount(tester);
  });
}
