import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/image_converter.dart';

/// Dịch vụ đánh giá chất lượng khung hình thực tế từ Camera.
class ImageQualityService {
  /// Ngưỡng độ sáng tối thiểu (0 - 255). Dưới mức này coi là quá tối.
  final double minBrightness;

  /// Ngưỡng độ sáng tối đa (0 - 255). Trên mức này coi là bị lóa/cháy sáng.
  final double maxBrightness;

  /// Tỷ lệ diện tích box tối thiểu so với khung hình. Dưới mức này là cầm quá xa.
  final double minBoxAreaRatio;

  /// Tỷ lệ diện tích box tối đa so với khung hình. Trên mức này là cầm quá sát.
  final double maxBoxAreaRatio;

  const ImageQualityService({
    this.minBrightness = 35.0,
    this.maxBrightness = 240.0,
    this.minBoxAreaRatio = 0.08,
    this.maxBoxAreaRatio = 0.88,
  });

  /// Kiểm tra điều kiện ánh sáng của khung hình trước hoặc sau khi suy luận.
  DetectionStatus? evaluateLighting(PreprocessedFrame frame) {
    if (frame.meanBrightness < minBrightness) {
      return DetectionStatus.tooDark;
    }
    if (frame.meanBrightness > maxBrightness) {
      return DetectionStatus.tooBright;
    }
    return null;
  }

  /// Kiểm tra kích thước hình học của hộp giới hạn tờ tiền.
  DetectionStatus? evaluateBoxGeometry(BoundingBox box) {
    final double area = box.areaRatio;
    if (area > maxBoxAreaRatio) {
      return DetectionStatus.tooClose;
    }
    if (area < minBoxAreaRatio) {
      return DetectionStatus.tooFar;
    }
    return null;
  }

  /// Trả về câu hướng dẫn hành động bằng tiếng Việt tương ứng với trạng thái.
  static String getGuidanceMessage(DetectionStatus status) {
    switch (status) {
      case DetectionStatus.detected:
        return 'Đã nhận diện thành công';
      case DetectionStatus.noMoney:
        return 'Đưa một tờ tiền vào camera';
      case DetectionStatus.lowConfidence:
        return 'Xin giữ yên tay';
      case DetectionStatus.multipleNotes:
        return 'Chỉ đưa một tờ tiền vào camera';
      case DetectionStatus.tooClose:
        return 'Đưa máy ra xa một chút';
      case DetectionStatus.tooFar:
        return 'Đưa máy lại gần hơn';
      case DetectionStatus.tooDark:
        return 'Môi trường quá tối, vui lòng bật thêm đèn';
      case DetectionStatus.tooBright:
        return 'Ảnh bị chói sáng, vui lòng nghiêng nhẹ tờ tiền';
      case DetectionStatus.skippedBusy:
        return 'Đang xử lý khung hình trước';
      case DetectionStatus.modelError:
        return 'Model TFLite chưa chạy được inference';
    }
  }
}