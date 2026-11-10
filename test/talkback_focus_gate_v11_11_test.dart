import 'dart:async';

import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/app_fakes.dart';

class _ControlledSpeech extends TestSpeech {
  final startupGate = Completer<void>();
  final modeGate = Completer<void>();
  bool blockStartup = true;

  @override
  Future<void> waitForCurrentSpeech() async {
    if (blockStartup) await startupGate.future;
  }

  @override
  Future<void> speak(
    String text, {
    SpeechRateOption rate = SpeechRateOption.normal,
    SpeechPriority priority = SpeechPriority.instruction,
  }) async {
    spoken.add(text);
    rates.add(rate);
    if (text.contains('Đã chuyển sang chế độ')) {
      await modeGate.future;
    }
  }
}

// Check the real accessibility semantics tree, not the widget tree.
// ExcludeSemantics hides nodes from TalkBack without removing UI widgets.
bool _hasAccessibilityLabel(WidgetTester tester, String label) {
  final root =
      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  if (root == null) return false;

  bool found = false;
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().label.contains(label)) {
      found = true;
      return;
    }
    node.visitChildren((SemanticsNode child) {
      if (!found) visit(child);
      return !found;
    });
  }

  visit(root);
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('money_recognition/touch_exploration');

  testWidgets('Man hinh khoi dong giu semantics nut on dinh trong luc TTS',
      (tester) async {
    final handle = tester.ensureSemantics();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? true : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final speech = _ControlledSpeech();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: TestBackend(),
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 850));
    expect(_hasAccessibilityLabel(tester, 'Chuyển chế độ'), isTrue);
    speech.startupGate.complete();
    await tester.pumpAndSettle();
    expect(_hasAccessibilityLabel(tester, 'Chuyển chế độ'), isTrue);
    await unmount(tester);
    handle.dispose();
  });

  testWidgets(
      'Chuyen che do khong xoa roi tao lai semantics khi camera san sang',
      (tester) async {
    final handle = tester.ensureSemantics();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isTouchExplorationEnabled' ? true : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final speech = _ControlledSpeech();
    speech.blockStartup = false;
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: TestBackend(),
      speechService: speech,
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    expect(_hasAccessibilityLabel(tester, 'Chuyển chế độ'), isTrue);
    await tester.ensureVisible(find.byKey(const Key('switch_mode_button')));
    await tester.tap(find.byKey(const Key('switch_mode_button')));
    await tester.pump();
    await tester.pump();
    expect(_hasAccessibilityLabel(tester, 'Chuyển chế độ'), isTrue);
    speech.modeGate.complete();
    await tester.pumpAndSettle();
    expect(_hasAccessibilityLabel(tester, 'Chuyển chế độ'), isTrue);
    // Finish the estimated TalkBack wait before unmounting.
    // This does not change the app or speech/camera behavior.
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    await unmount(tester);
    handle.dispose();
  });
}
