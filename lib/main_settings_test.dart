//tét
import 'package:flutter/material.dart';

import 'controllers/settings_controller.dart';
import 'core/models/app_settings.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SettingsTestApp());
}

class SettingsTestApp extends StatefulWidget {
  const SettingsTestApp({super.key});

  @override
  State<SettingsTestApp> createState() =>
      _SettingsTestAppState();
}

class _SettingsTestAppState extends State<SettingsTestApp> {
  late final SettingsController controller;

  @override
  void initState() {
    super.initState();

    controller = SettingsController(SettingsService());
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Kiểm tra lưu cài đặt'),
        ),
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final settings = controller.settings;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SwitchListTile(
                  title: const Text('Tự động đọc mệnh giá'),
                  value: settings.autoReadEnabled,
                  onChanged: (value) =>
                      controller.setAutoRead(value),
                ),
                SwitchListTile(
                  title: const Text('Rung thông báo'),
                  value: settings.vibrationEnabled,
                  onChanged: (value) =>
                      controller.setVibration(value),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tốc độ đọc',
                  style: TextStyle(fontSize: 18),
                ),
                DropdownButton<SpeechRateOption>(
                  isExpanded: true,
                  value: settings.speechRate,
                  items: SpeechRateOption.values.map((rate) {
                    final label = switch (rate) {
                      SpeechRateOption.slow => 'Chậm',
                      SpeechRateOption.normal => 'Bình thường',
                      SpeechRateOption.fast => 'Nhanh',
                    };

                    return DropdownMenuItem(
                      value: rate,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (rate) {
                    if (rate != null) {
                      controller.setSpeechRate(rate);
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hãy thay đổi cài đặt, đóng ứng dụng, '
                  'sau đó mở lại bằng cùng lệnh Flutter '
                  'để xem dữ liệu có được giữ hay không.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
