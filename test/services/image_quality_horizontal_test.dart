
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/image_quality_service.dart';

void main() {
  const service = ImageQualityService();

  BoundingBox makeBox(
    double x1,
    double x2, {
    double confidence = 0.70,
  }) {
    return BoundingBox(
      x1: x1,
      y1: 0.20,
      x2: x2,
      y2: 0.80,
      classId: 0,
      rawLabel: '1000',
      confidence: confidence,
    );
  }

  test('Tien lech trai thi huong dan dich sang phai', () {
    final box = makeBox(0.00, 0.50);

    expect(
      service.getHorizontalGuidance(box),
      'Dịch tờ tiền sang phải một chút',
    );
  });

  test('Tien o giua thi khong can can chinh', () {
    final box = makeBox(0.25, 0.75);

    expect(
      service.getHorizontalGuidance(box),
      isNull,
    );
  });

  test('Tien lech phai thi huong dan dich sang trai', () {
    final box = makeBox(0.50, 1.00);

    expect(
      service.getHorizontalGuidance(box),
      'Dịch tờ tiền sang trái một chút',
    );
  });

  test('Box co do tin cay thap thi khong doan huong', () {
    final box = makeBox(
      0.00,
      0.50,
      confidence: 0.45,
    );

    expect(
      service.getHorizontalGuidance(box),
      isNull,
    );
  });
}
