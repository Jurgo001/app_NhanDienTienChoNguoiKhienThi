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
}
