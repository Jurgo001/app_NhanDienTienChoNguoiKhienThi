import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/guide/guide_screen.dart';

void main() {
  testWidgets(
      'Hướng dẫn V11 mô tả chuyển chế độ bằng nút và giữ phím chỉnh âm lượng',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GuideScreen(
        onAutoRead: () async {},
        onReadCompleted: () {},
      ),
    ));
    expect(find.text('Điều khiển chế độ và âm lượng'), findsOneWidget);
    expect(find.text('Chuyển chế độ'), findsOneWidget);
    expect(find.text('Tạo phiên đếm mới'), findsOneWidget);
    expect(find.text('Phím âm lượng'), findsOneWidget);
    expect(AppStrings.spokenGuide.toLowerCase(), contains('chuyển chế độ'));
    expect(AppStrings.spokenGuide.toLowerCase(), contains('giữ phím âm lượng'));
  });
}
