//tét
import 'package:flutter/material.dart';
import 'services/speech_service.dart';

void main() {
  runApp(const TtsTestApp());
}

class TtsTestApp extends StatefulWidget {
  const TtsTestApp({super.key});

  @override
  State<TtsTestApp> createState() => _TtsTestAppState();
}

class _TtsTestAppState extends State<TtsTestApp> {
  final SpeechService _speech = SpeechService();

  String status = 'Chưa kiểm tra';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _speech.initialize();
      if (mounted) {
        setState(() => status = 'TTS đã khởi tạo');
      }
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Lỗi: $e');
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Kiểm tra TTS tiếng Việt')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(status),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await _speech.speak('Một trăm nghìn đồng');
                },
                child: const Text('Đọc 100.000 đồng'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _speech.stop();
                },
                child: const Text('Dừng đọc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}