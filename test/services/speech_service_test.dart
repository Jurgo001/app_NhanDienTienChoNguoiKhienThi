import 'dart:async';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('Giọng vi-VN thiếu có lỗi rõ ràng và có thể khởi tạo lại', () async {
    var available = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return available;
      return 1;
    });
    final service = SpeechService();
    await expectLater(service.initialize(), throwsStateError);
    available = true;
    await service.initialize();
    await service.speak('Năm mươi nghìn đồng');
    await service.stop();
  });

  test('Stop khi đang chuẩn bị phát không để lời đọc cũ bắt đầu sau đó',
      () async {
    final rateGate = Completer<void>();
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'setSpeechRate') await rateGate.future;
      return 1;
    });
    final service = SpeechService();
    await service.initialize();
    final speaking = service.speak('Kết quả cũ');
    await Future<void>.delayed(Duration.zero);
    await service.stop();
    rateGate.complete();
    await speaking;
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
  });
  test('Consecutive utterances reuse the speech rate and avoid redundant stops',
      () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return call.method == 'isLanguageAvailable' ? true : 1;
    });
    final service = SpeechService();
    await service.speak('Một');
    await service.speak('Hai');
    await service.speak('Ba');
    expect(calls.where((c) => c.method == 'speak'), hasLength(3));
    expect(calls.where((c) => c.method == 'setSpeechRate'), hasLength(1));
    expect(calls.where((c) => c.method == 'stop'), isEmpty);
  });

  test('Flash and guidance cannot interrupt an active denomination', () async {
    final gate = Completer<int>();
    final spoken = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        spoken.add(call.arguments as String);
        return gate.future;
      }
      return 1;
    });
    final service = SpeechService();
    final result =
        service.speak('Một trăm nghìn đồng', priority: SpeechPriority.result);
    await Future<void>.delayed(Duration.zero);
    await service.speak('Đèn flash đã bật', priority: SpeechPriority.status);
    await service.speak('Giữ yên tay', priority: SpeechPriority.guidance);
    expect(spoken, ['Một trăm nghìn đồng']);
    gate.complete(1);
    await result;
  });

  test('Duplicate in-flight utterances are coalesced', () async {
    final gate = Completer<int>();
    var speaks = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        speaks++;
        return gate.future;
      }
      return 1;
    });
    final service = SpeechService();
    final first = service.speak('Giữ yên tay');
    final duplicate = service.speak('Giữ yên tay');
    expect(identical(first, duplicate), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(speaks, 1);
    gate.complete(1);
    await Future.wait([first, duplicate]);
  });

  test(
      'A denomination preempts guidance and an error does not poison later speech',
      () async {
    final oldSpeech = Completer<int>();
    final spoken = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'stop' && !oldSpeech.isCompleted)
        oldSpeech.complete(1);
      if (call.method == 'speak') {
        final text = call.arguments as String;
        spoken.add(text);
        if (text == 'Giữ yên tay') return oldSpeech.future;
        if (text == 'Lỗi engine') return 0;
      }
      return 1;
    });
    final service = SpeechService();
    final guidance =
        service.speak('Giữ yên tay', priority: SpeechPriority.guidance);
    await Future<void>.delayed(Duration.zero);
    await service.speak('Năm mươi nghìn đồng', priority: SpeechPriority.result);
    await guidance;
    expect(spoken.take(2), ['Giữ yên tay', 'Năm mươi nghìn đồng']);
    await expectLater(service.speak('Lỗi engine'), throwsStateError);
    await service.speak('Thử lại');
    expect(spoken.last, 'Thử lại');
  });
}
