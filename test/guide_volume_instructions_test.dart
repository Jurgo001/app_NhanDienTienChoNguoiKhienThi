import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';

void main() {
  testWidgets('Hướng dẫn hiển thị phím cứng và TTS đề cập đầy đủ',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GuideScreen(
        onListen: () {},
        onStartRecognition: () {},
      ),
    ));
    expect(find.text('Điều khiển bằng phím âm lượng'), findsOneWidget);
    expect(
        find.text('Giữ phím tăng âm lượng (+) trong 3 giây'), findsOneWidget);
    expect(
        find.text('Giữ phím giảm âm lượng (−) trong 3 giây'), findsOneWidget);
    expect(find.text('Nhấn ngắn để điều chỉnh âm lượng'), findsOneWidget);
    expect(AppStrings.spokenGuide.toLowerCase(), contains('tăng âm lượng'));
    expect(AppStrings.spokenGuide.toLowerCase(), contains('giảm âm lượng'));
  });
}
