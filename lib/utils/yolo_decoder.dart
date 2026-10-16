import 'dart:math' as math;
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/denomination_mapper.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/nms.dart';

/// Giải mã Output Tensor của YOLOv8 sang danh sách BoundingBox.
class YoloDecoder {
  YoloDecoder._();

  /// Giải mã đầu ra dạng phẳng (Float32List / List<double>) hoặc mảng lồng nhau.
  /// Hỗ trợ cả 2 layout phổ biến của YOLOv8 TFLite/LiteRT:
  /// - Layout A: [1, channels, anchors] -> [1, 22, 3549] (4 tọa độ + 18 classes = 22)
  /// - Layout B: [1, anchors, channels] -> [1, 3549, 22]
  static List<BoundingBox> decodeOutput({
    required List<double> flatOutput,
    required List<int> outputShape,
    required int inputSize,
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.45,
    double padX = 0.0,
    double padY = 0.0,
    double scaleWidth = 1.0,
    double scaleHeight = 1.0,
  }) {
    if (outputShape.length != 3 ||
        outputShape[0] != 1 ||
        flatOutput.isEmpty ||
        outputShape[1] <= 0 ||
        outputShape[2] <= 0 ||
        flatOutput.length != outputShape[1] * outputShape[2] ||
        inputSize <= 0 ||
        scaleWidth <= 0 ||
        scaleHeight <= 0) {
      return const [];
    }

    final int dim1 = outputShape[1];
    final int dim2 = outputShape[2];

    // Xác định chiều nào là số kênh (4 box + 18 classes = 22), chiều nào là số neo (3549)
    final bool isChannelsFirst =
        dim1 == 4 + DenominationMapper.classLabels.length;
    final int numChannels = isChannelsFirst ? dim1 : dim2;
    final int numAnchors = isChannelsFirst ? dim2 : dim1;
    final int numClasses = numChannels - 4;

    if (numClasses != DenominationMapper.classLabels.length) return const [];

    final List<BoundingBox> candidates = [];

    for (int i = 0; i < numAnchors; i++) {
      // 1. Tìm class có điểm xác suất cao nhất tại neo thứ i
      double maxScore = -1.0;
      int bestClassId = -1;

      for (int c = 0; c < numClasses; c++) {
        final int idx = isChannelsFirst
            ? ((4 + c) * numAnchors + i)
            : (i * numChannels + (4 + c));
        final double score = flatOutput[idx];
        if (score.isFinite && score > maxScore) {
          maxScore = score;
          bestClassId = c;
        }
      }

      if (maxScore < confidenceThreshold || bestClassId < 0) {
        continue;
      }

      // 2. Lấy tọa độ tâm (cx, cy) và kích thước (w, h)
      final double rawCx = flatOutput[
          isChannelsFirst ? (0 * numAnchors + i) : (i * numChannels + 0)];
      final double rawCy = flatOutput[
          isChannelsFirst ? (1 * numAnchors + i) : (i * numChannels + 1)];
      final double rawW = flatOutput[
          isChannelsFirst ? (2 * numAnchors + i) : (i * numChannels + 2)];
      final double rawH = flatOutput[
          isChannelsFirst ? (3 * numAnchors + i) : (i * numChannels + 3)];

      if (![rawCx, rawCy, rawW, rawH].every((v) => v.isFinite) ||
          rawW <= 0 ||
          rawH <= 0) continue;

      // Kiểm tra xem tọa độ đang ở hệ pixel [0..416] hay hệ chuẩn hóa [0..1]
      final bool isPixelCoords =
          rawCx > 2.0 || rawCy > 2.0 || rawW > 2.0 || rawH > 2.0;

      final double cxNorm = isPixelCoords ? (rawCx / inputSize) : rawCx;
      final double cyNorm = isPixelCoords ? (rawCy / inputSize) : rawCy;
      final double wNorm = isPixelCoords ? (rawW / inputSize) : rawW;
      final double hNorm = isPixelCoords ? (rawH / inputSize) : rawH;

      // Chuyển từ (cx, cy, w, h) sang (x1, y1, x2, y2) và trừ phần viền Letterbox (nếu có)
      double x1 = ((cxNorm - wNorm / 2.0) - padX) / scaleWidth;
      double y1 = ((cyNorm - hNorm / 2.0) - padY) / scaleHeight;
      double x2 = ((cxNorm + wNorm / 2.0) - padX) / scaleWidth;
      double y2 = ((cyNorm + hNorm / 2.0) - padY) / scaleHeight;

      x1 = x1.clamp(0.0, 1.0);
      y1 = y1.clamp(0.0, 1.0);
      x2 = math.max(x1, x2.clamp(0.0, 1.0));
      y2 = math.max(y1, y2.clamp(0.0, 1.0));

      if ((x2 - x1) < 0.02 || (y2 - y1) < 0.02) {
        continue;
      }

      final mapped = DenominationMapper.fromClassId(bestClassId);

      candidates.add(
        BoundingBox(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          classId: bestClassId,
          rawLabel:
              mapped?.rawLabel ?? DenominationMapper.getRawLabel(bestClassId),
          confidence: maxScore.clamp(0.0, 1.0),
          denomination: mapped?.denomination,
          side: mapped?.side ?? BanknoteSide.unknown,
        ),
      );
    }

    // 3. Áp dụng Non-Maximum Suppression để loại bỏ các box trùng lặp
    return NmsUtils.applyNMS(
      candidates,
      iouThreshold: iouThreshold,
      classAgnostic: true,
    );
  }
}
