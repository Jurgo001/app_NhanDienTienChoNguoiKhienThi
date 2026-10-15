import 'dart:math' as math;
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';

/// Thuật toán Non-Maximum Suppression (NMS) loại bỏ các hộp giới hạn trùng lặp.
class NmsUtils {
  NmsUtils._();

  /// Tính chỉ số Intersection over Union (IoU) giữa 2 hộp giới hạn.
  static double calculateIoU(BoundingBox a, BoundingBox b) {
    final double interX1 = math.max(a.x1, b.x1);
    final double interY1 = math.max(a.y1, b.y1);
    final double interX2 = math.min(a.x2, b.x2);
    final double interY2 = math.min(a.y2, b.y2);

    final double interWidth = math.max(0.0, interX2 - interX1);
    final double interHeight = math.max(0.0, interY2 - interY1);
    final double intersectionArea = interWidth * interHeight;

    if (intersectionArea <= 0.0) return 0.0;

    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double unionArea = areaA + areaB - intersectionArea;

    if (unionArea <= 0.0) return 0.0;
    return intersectionArea / unionArea;
  }

  /// Tính tỷ lệ phần giao chia cho diện tích hộp nhỏ hơn (Intersection over Minimum - IoM).
  /// Giúp lọc trường hợp 1 hộp nhỏ nằm lọt thỏm bên trong 1 hộp lớn trên cùng 1 tờ tiền.
  static double calculateIoM(BoundingBox a, BoundingBox b) {
    final double interX1 = math.max(a.x1, b.x1);
    final double interY1 = math.max(a.y1, b.y1);
    final double interX2 = math.min(a.x2, b.x2);
    final double interY2 = math.min(a.y2, b.y2);

    final double interWidth = math.max(0.0, interX2 - interX1);
    final double interHeight = math.max(0.0, interY2 - interY1);
    final double intersectionArea = interWidth * interHeight;

    if (intersectionArea <= 0.0) return 0.0;

    final double minArea = math.min(a.width * a.height, b.width * b.height);
    if (minArea <= 0.0) return 0.0;
    return intersectionArea / minArea;
  }

  /// Lọc danh sách BoundingBox bằng NMS.
  /// [classAgnostic] = true giúp gom các box đè lên nhau trên cùng 1 tờ tiền
  /// (dù khác nhãn mặt trước/sau hoặc khác mệnh giá) về 1 box có độ tự tin cao nhất.
  static List<BoundingBox> applyNMS(
    List<BoundingBox> boxes, {
    double iouThreshold = 0.45,
    bool classAgnostic = true,
    int maxDetections = 5,
  }) {
    if (boxes.isEmpty) return const [];

    final sorted = List<BoundingBox>.from(boxes)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<BoundingBox> selected = [];

    for (final candidate in sorted) {
      if (selected.length >= maxDetections) break;

      bool shouldSuppress = false;
      for (final kept in selected) {
        if (!classAgnostic && candidate.classId != kept.classId) {
          continue;
        }

        final iou = calculateIoU(candidate, kept);
        final iom = calculateIoM(candidate, kept);

        // Nếu đè lên nhau vượt ngưỡng IoU hoặc nằm lọt > 75% trong box lớn hơn thì loại bỏ
        if (iou > iouThreshold || iom > 0.75) {
          shouldSuppress = true;
          break;
        }
      }

      if (!shouldSuppress) {
        selected.add(candidate);
      }
    }

    return selected;
  }
}