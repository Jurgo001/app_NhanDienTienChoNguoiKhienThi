//tét
import 'package:flutter/material.dart';
import 'services/haptic_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HapticTestApp());
}

class HapticTestApp extends StatelessWidget {
  const HapticTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final haptic = HapticService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Kiểm tra chức năng rung'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await haptic.vibrateSuccess();
                },
                child: const Text('Rung thành công'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await haptic.vibrateError();
                },
                child: const Text('Rung thất bại'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await haptic.stop();
                },
                child: const Text('Dừng rung'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
