import 'package:flutter/material.dart';
import 'debug/detector_test_screen.dart';

/// Màn TV2 độc lập, chỉ chạy trên Android.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DetectorTestScreen(),
  ));
}
