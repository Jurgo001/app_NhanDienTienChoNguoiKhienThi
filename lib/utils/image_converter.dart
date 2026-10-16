import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';

class PreprocessedFrame {
  const PreprocessedFrame({
    required this.inputBuffer,
    required this.meanBrightness,
    required this.contrastStdDev,
    required this.padX,
    required this.padY,
    required this.scaleWidth,
    required this.scaleHeight,
  });
  final Float32List inputBuffer;
  final double meanBrightness;
  final double contrastStdDev;
  final double padX, padY, scaleWidth, scaleHeight;
}

/// Chỉ chứa byte và stride, truyền được sang isolate mà không mang plugin.
class FramePlane {
  FramePlane(Plane plane)
      : bytes = Uint8List.fromList(plane.bytes),
        rowStride = plane.bytesPerRow,
        pixelStride = plane.bytesPerPixel ?? 1;
  final Uint8List bytes;
  final int rowStride, pixelStride;
}

class FrameData {
  FrameData.fromCamera(CameraImage image)
      : width = image.width,
        height = image.height,
        format = image.format.group,
        planes = image.planes.map(FramePlane.new).toList();
  final int width, height;
  final ImageFormatGroup format;
  final List<FramePlane> planes;
}

class ImageConverter {
  ImageConverter._();
  static PreprocessedFrame convertCameraImage({
    required CameraImage cameraImage,
    required int sensorOrientation,
    int targetSize = 416,
    bool isChannelsFirst = true,
    bool useLetterbox = false,
  }) =>
      convertFrame(
        frame: FrameData.fromCamera(cameraImage),
        rotation: sensorOrientation,
        targetSize: targetSize,
        isChannelsFirst: isChannelsFirst,
        useLetterbox: useLetterbox,
      );

  /// RGB / 255; xoay trước, giữ tỷ lệ bằng letterbox 114 khi được yêu cầu.
  /// Cùng một hàm được dùng trong test và worker TFLite.
  static PreprocessedFrame convertFrame({
    required FrameData frame,
    required int rotation,
    int targetSize = 416,
    bool isChannelsFirst = true,
    bool useLetterbox = false,
  }) {
    final angle = rotation % 360;
    if (frame.width <= 0 ||
        frame.height <= 0 ||
        targetSize <= 0 ||
        ![0, 90, 180, 270].contains(angle)) {
      throw ArgumentError('Kích thước hoặc góc xoay frame không hợp lệ.');
    }
    final yuv = frame.format == ImageFormatGroup.yuv420;
    if ((!yuv && frame.format != ImageFormatGroup.bgra8888) ||
        frame.planes.length < (yuv ? 3 : 1)) {
      throw UnsupportedError('Định dạng camera chưa hỗ trợ: ${frame.format}');
    }
    final first = frame.planes[0];
    final swap = angle == 90 || angle == 270;
    final rw = swap ? frame.height : frame.width;
    final rh = swap ? frame.width : frame.height;
    var dw = targetSize, dh = targetSize, ox = 0, oy = 0;
    if (useLetterbox) {
      final scale = math.min(targetSize / rw, targetSize / rh);
      dw = (rw * scale).round().clamp(1, targetSize);
      dh = (rh * scale).round().clamp(1, targetSize);
      ox = (targetSize - dw) ~/ 2;
      oy = (targetSize - dh) ~/ 2;
    }
    final planeSize = targetSize * targetSize;
    final buffer = Float32List(planeSize * 3);
    if (useLetterbox) buffer.fillRange(0, buffer.length, 114 / 255);
    double sum = 0, squared = 0;
    var samples = 0;
    final sampleStep = targetSize <= 16 ? 1 : 4;
    for (var ty = 0; ty < dh; ty++) {
      final ry = ((ty + .5) * rh / dh).floor().clamp(0, rh - 1);
      for (var tx = 0; tx < dw; tx++) {
        final rx = ((tx + .5) * rw / dw).floor().clamp(0, rw - 1);
        final (sx, sy) = switch (angle) {
          90 => (ry, frame.height - 1 - rx),
          180 => (frame.width - 1 - rx, frame.height - 1 - ry),
          270 => (frame.width - 1 - ry, rx),
          _ => (rx, ry),
        };
        int r, g, b;
        double luma;
        if (yuv) {
          final u = frame.planes[1], v = frame.planes[2];
          final yy = first.bytes[sy * first.rowStride + sx * first.pixelStride];
          final uu =
              u.bytes[(sy ~/ 2) * u.rowStride + (sx ~/ 2) * u.pixelStride];
          final vv =
              v.bytes[(sy ~/ 2) * v.rowStride + (sx ~/ 2) * v.pixelStride];
          final c = yy - 16, d = uu - 128, e = vv - 128;
          r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
          luma = yy.toDouble();
        } else {
          final index = sy * first.rowStride + sx * 4;
          b = first.bytes[index];
          g = first.bytes[index + 1];
          r = first.bytes[index + 2];
          luma = .299 * r + .587 * g + .114 * b;
        }
        if (tx % sampleStep == 0 && ty % sampleStep == 0) {
          sum += luma;
          squared += luma * luma;
          samples++;
        }
        final pixel = (ty + oy) * targetSize + tx + ox;
        if (isChannelsFirst) {
          buffer[pixel] = r / 255;
          buffer[planeSize + pixel] = g / 255;
          buffer[2 * planeSize + pixel] = b / 255;
        } else {
          buffer[3 * pixel] = r / 255;
          buffer[3 * pixel + 1] = g / 255;
          buffer[3 * pixel + 2] = b / 255;
        }
      }
    }
    final mean = samples == 0 ? 0.0 : sum / samples;
    final variance =
        samples == 0 ? 0.0 : math.max(0.0, squared / samples - mean * mean);
    return PreprocessedFrame(
      inputBuffer: buffer,
      meanBrightness: mean,
      contrastStdDev: math.sqrt(variance),
      padX: ox / targetSize,
      padY: oy / targetSize,
      scaleWidth: dw / targetSize,
      scaleHeight: dh / targetSize,
    );
  }
}
