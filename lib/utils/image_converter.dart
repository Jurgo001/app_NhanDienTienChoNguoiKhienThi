import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Dữ liệu trả về sau khi tiền xử lý khung hình Camera.
class PreprocessedFrame {
  /// Mảng Float32 chuẩn hóa [0.0, 1.0] sẵn sàng nạp vào Input Tensor.
  final Float32List inputBuffer;

  /// Độ sáng trung bình của khung hình (0.0 -> 255.0).
  final double meanBrightness;

  /// Độ lệch chuẩn độ sáng (đánh giá độ tương phản / độ mờ sơ bộ).
  final double contrastStdDev;

  /// Thông số viền Letterbox để quy đổi ngược tọa độ BoundingBox chính xác.
  final double padX;
  final double padY;
  final double scaleWidth;
  final double scaleHeight;

  const PreprocessedFrame({
    required this.inputBuffer,
    required this.meanBrightness,
    required this.contrastStdDev,
    required this.padX,
    required this.padY,
    required this.scaleWidth,
    required this.scaleHeight,
  });
}

/// Chuyển đổi trực tiếp từ CameraImage sang Tensor Float32 tốc độ cao.
class ImageConverter {
  ImageConverter._();

  /// Chuyển đổi [CameraImage] sang [PreprocessedFrame] kích thước [targetSize] x [targetSize].
  /// Hỗ trợ cả 2 định dạng Input Tensor:
  /// - [isChannelsFirst] = true  -> NCHW: [1, 3, 416, 416] (chuẩn LiteRT / PyTorch export)
  /// - [isChannelsFirst] = false -> NHWC: [1, 416, 416, 3] (chuẩn TFLite truyền thống)
  static PreprocessedFrame convertCameraImage({
    required CameraImage cameraImage,
    required int sensorOrientation,
    int targetSize = 416,
    bool isChannelsFirst = true,
    bool useLetterbox = false,
  }) {
    final int srcWidth = cameraImage.width;
    final int srcHeight = cameraImage.height;

    final bool swapDimensions =
        sensorOrientation == 90 || sensorOrientation == 270;
    final int rotatedWidth = swapDimensions ? srcHeight : srcWidth;
    final int rotatedHeight = swapDimensions ? srcWidth : srcHeight;

    // Tính toán tỷ lệ co giãn (Stretch hoặc Letterbox)
    double scaleW = 1.0;
    double scaleH = 1.0;
    double padX = 0.0;
    double padY = 0.0;

    int drawWidth = targetSize;
    int drawHeight = targetSize;
    int offsetX = 0;
    int offsetY = 0;

    if (useLetterbox && rotatedWidth > 0 && rotatedHeight > 0) {
      final double scale = (targetSize / rotatedWidth) < (targetSize / rotatedHeight)
          ? (targetSize / rotatedWidth)
          : (targetSize / rotatedHeight);
      drawWidth = (rotatedWidth * scale).round();
      drawHeight = (rotatedHeight * scale).round();
      offsetX = ((targetSize - drawWidth) / 2).floor();
      offsetY = ((targetSize - drawHeight) / 2).floor();

      scaleW = drawWidth / targetSize;
      scaleH = drawHeight / targetSize;
      padX = offsetX / targetSize;
      padY = offsetY / targetSize;
    }

    final int planeSize = targetSize * targetSize;
    final Float32List buffer = Float32List(3 * planeSize);

    // Nếu dùng letterbox, phủ màu xám chuẩn YOLO (114 / 255 = 0.447)
    if (useLetterbox) {
      buffer.fillRange(0, buffer.length, 114.0 / 255.0);
    }

    double sumLuma = 0.0;
    double sumLumaSq = 0.0;
    int sampleCount = 0;

    final bool isYuv420 = cameraImage.format.group == ImageFormatGroup.yuv420 ||
        cameraImage.planes.length >= 3;

    final Plane yPlane = cameraImage.planes[0];
    final Uint8List yBytes = yPlane.bytes;
    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    Uint8List? uBytes;
    Uint8List? vBytes;
    int uvRowStride = 0;
    int uvPixelStride = 1;

    if (isYuv420 && cameraImage.planes.length >= 3) {
      uBytes = cameraImage.planes[1].bytes;
      vBytes = cameraImage.planes[2].bytes;
      uvRowStride = cameraImage.planes[1].bytesPerRow;
      uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;
    }

    for (int ty = 0; ty < drawHeight; ty++) {
      final int outY = ty + offsetY;
      final double normY = ty / drawHeight;

      for (int tx = 0; tx < drawWidth; tx++) {
        final int outX = tx + offsetX;
        final double normX = tx / drawWidth;

        // Quy đổi ngược từ tọa độ đích (đã xoay) về tọa độ khung hình gốc của cảm biến
        int srcX;
        int srcY;

        switch (sensorOrientation) {
          case 90:
            srcX = (normY * (srcWidth - 1)).toInt();
            srcY = ((1.0 - normX) * (srcHeight - 1)).toInt();
            break;
          case 180:
            srcX = ((1.0 - normX) * (srcWidth - 1)).toInt();
            srcY = ((1.0 - normY) * (srcHeight - 1)).toInt();
            break;
          case 270:
            srcX = ((1.0 - normY) * (srcWidth - 1)).toInt();
            srcY = (normX * (srcHeight - 1)).toInt();
            break;
          default:
            srcX = (normX * (srcWidth - 1)).toInt();
            srcY = (normY * (srcHeight - 1)).toInt();
            break;
        }

        int r = 0, g = 0, b = 0;

        if (isYuv420 && uBytes != null && vBytes != null) {
          final int yIndex = srcY * yRowStride + srcX * yPixelStride;
          final int uvIndex =
              (srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride;

          final int yVal = yBytes[yIndex.clamp(0, yBytes.length - 1)] & 0xFF;
          final int uVal = uBytes[uvIndex.clamp(0, uBytes.length - 1)] & 0xFF;
          final int vVal = vBytes[uvIndex.clamp(0, vBytes.length - 1)] & 0xFF;

          // Công thức chuyển đổi YUV420 sang RGB chuẩn ITU-R BT.601
          final int c = yVal - 16;
          final int d = uVal - 128;
          final int e = vVal - 128;

          r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

          if ((tx & 3) == 0 && (ty & 3) == 0) {
            sumLuma += yVal;
            sumLumaSq += yVal * yVal;
            sampleCount++;
          }
        } else {
          // BGRA8888 fallback
          final int bgraIndex = srcY * yRowStride + srcX * 4;
          if (bgraIndex + 2 < yBytes.length) {
            b = yBytes[bgraIndex] & 0xFF;
            g = yBytes[bgraIndex + 1] & 0xFF;
            r = yBytes[bgraIndex + 2] & 0xFF;
            final double luma = 0.299 * r + 0.587 * g + 0.114 * b;
            if ((tx & 3) == 0 && (ty & 3) == 0) {
              sumLuma += luma;
              sumLumaSq += luma * luma;
              sampleCount++;
            }
          }
        }

        final double rf = r / 255.0;
        final double gf = g / 255.0;
        final double bf = b / 255.0;

        final int pixelIdx = outY * targetSize + outX;
        if (isChannelsFirst) {
          // NCHW: [1, 3, H, W]
          buffer[pixelIdx] = rf;
          buffer[planeSize + pixelIdx] = gf;
          buffer[2 * planeSize + pixelIdx] = bf;
        } else {
          // NHWC: [1, H, W, 3]
          final int baseIdx = pixelIdx * 3;
          buffer[baseIdx] = rf;
          buffer[baseIdx + 1] = gf;
          buffer[baseIdx + 2] = bf;
        }
      }
    }

    final double meanLuma = sampleCount > 0 ? (sumLuma / sampleCount) : 128.0;
    final double variance = sampleCount > 0
        ? ((sumLumaSq / sampleCount) - (meanLuma * meanLuma)).clamp(0.0, 65025.0)
        : 0.0;

    return PreprocessedFrame(
      inputBuffer: buffer,
      meanBrightness: meanLuma,
      contrastStdDev: variance > 0 ? _sqrtApprox(variance) : 0.0,
      padX: padX,
      padY: padY,
      scaleWidth: scaleW,
      scaleHeight: scaleH,
    );
  }

  static double _sqrtApprox(double v) {
    if (v <= 0) return 0.0;
    double x = v;
    for (int i = 0; i < 6; i++) {
      x = 0.5 * (x + v / x);
    }
    return x;
  }
}