import 'package:flutter/material.dart';
// 1. Import màn hình test của bạn vào đây
import 'package:app_ho_tro_nguoi_khiem_thi/debug/detector_test_screen.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      // 2. Trỏ thẳng luồng khởi động vào màn hình của TV2
      home: DetectorTestScreen(), 
    ),
  );
}