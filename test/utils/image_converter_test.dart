import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart' as cp;
import 'package:app_ho_tro_nguoi_khiem_thi/utils/image_converter.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/yolo_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/transferred_frame.dart';

CameraImage colorImage() =>
    CameraImage.fromPlatformInterface(cp.CameraImageData(
      format: const cp.CameraImageFormat(cp.ImageFormatGroup.bgra8888,
          raw: 1111970369),
      width: 2,
      height: 2,
      planes: [
        cp.CameraImagePlane(
          bytes: Uint8List.fromList([
            0,
            0,
            255,
            255,
            0,
            255,
            0,
            255,
            255,
            0,
            0,
            255,
            255,
            255,
            255,
            255
          ]),
          bytesPerRow: 8,
          bytesPerPixel: 4,
        )
      ],
    ));

void main() {
  test('Xoay bốn hướng giữ đúng thứ tự pixel', () {
    final expected = <int, List<double>>{
      0: [1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1],
      90: [0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0],
      180: [1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0],
      270: [0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1],
    };
    for (final entry in expected.entries) {
      final frame = ImageConverter.convertCameraImage(
          cameraImage: colorImage(),
          sensorOrientation: entry.key,
          targetSize: 2,
          isChannelsFirst: false);
      expect(frame.inputBuffer.toList(), entry.value);
      expect(frame.meanBrightness, closeTo(127.5, .01));
      expect(frame.contrastStdDev, greaterThan(0));
    }
  });
  test('NCHW và NHWC chứa cùng RGB, đúng vị trí kênh', () {
    final frame = ImageConverter.convertCameraImage(
        cameraImage: colorImage(), sensorOrientation: 0, targetSize: 2);
    expect(frame.inputBuffer.toList(), [1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1]);
  });
  test('YUV tôn trọng row/pixel stride riêng cho cả U và V', () {
    final image = CameraImage.fromPlatformInterface(cp.CameraImageData(
      format: const cp.CameraImageFormat(cp.ImageFormatGroup.yuv420, raw: 35),
      width: 2,
      height: 2,
      planes: [
        cp.CameraImagePlane(
            bytes: Uint8List.fromList([16, 0, 235, 0, 0, 0, 81, 0, 145]),
            bytesPerRow: 6,
            bytesPerPixel: 2),
        cp.CameraImagePlane(
            bytes: Uint8List.fromList([128, 0]),
            bytesPerRow: 2,
            bytesPerPixel: 2),
        cp.CameraImagePlane(
            bytes: Uint8List.fromList([128]), bytesPerRow: 1, bytesPerPixel: 1),
      ],
    ));
    final out = ImageConverter.convertCameraImage(
        cameraImage: image,
        sensorOrientation: 0,
        targetSize: 2,
        isChannelsFirst: false);
    expect(out.inputBuffer.take(3), [0, 0, 0]);
    expect(out.inputBuffer.skip(3).take(3), [1, 1, 1]);
    expect(out.inputBuffer[6], closeTo(76 / 255, .001));
    expect(out.inputBuffer[9], closeTo(150 / 255, .001));
  });
  test('Letterbox dùng màu 114 và giải mã box về ảnh không có viền', () {
    final image = CameraImage.fromPlatformInterface(cp.CameraImageData(
      format: const cp.CameraImageFormat(cp.ImageFormatGroup.bgra8888,
          raw: 1111970369),
      width: 4,
      height: 2,
      planes: [
        cp.CameraImagePlane(
            bytes: Uint8List.fromList(
                List<int>.generate(32, (i) => i % 4 == 3 ? 255 : 0)),
            bytesPerRow: 16,
            bytesPerPixel: 4)
      ],
    ));
    final frame = ImageConverter.convertCameraImage(
        cameraImage: image,
        sensorOrientation: 0,
        targetSize: 4,
        useLetterbox: true,
        isChannelsFirst: false);
    expect(frame.padY, .25);
    expect(frame.scaleHeight, .5);
    expect(frame.inputBuffer[0], closeTo(114 / 255, .0001));
    final output = List<double>.filled(22, 0);
    output[0] = .5;
    output[1] = .5;
    output[2] = .8;
    output[3] = .3;
    output[4] = .95;
    final box = YoloDecoder.decodeOutput(
            flatOutput: output,
            outputShape: [1, 22, 1],
            inputSize: 4,
            padY: frame.padY,
            scaleHeight: frame.scaleHeight)
        .single;
    expect(box.y1, closeTo(.2, .001));
    expect(box.y2, closeTo(.8, .001));
  });
  test('Reused buffers preserve every pixel and letterbox across rotations',
      () {
    final frame = FrameData.fromPlanes(
      width: 4,
      height: 2,
      format: ImageFormatGroup.bgra8888,
      planes: [
        FramePlane.fromBytes(
          Uint8List.fromList(List.generate(32, (i) => (i * 17) % 256)),
          rowStride: 16,
          pixelStride: 4,
        )
      ],
    );
    final buffer = Float32List(4 * 4 * 3)..fillRange(0, 48, double.nan);
    for (final channelsFirst in [true, false]) {
      for (final rotation in [0, 90, 180, 270]) {
        final expected = ImageConverter.convertFrame(
          frame: frame,
          rotation: rotation,
          targetSize: 4,
          isChannelsFirst: channelsFirst,
          useLetterbox: true,
        );
        final reused = ImageConverter.convertFrame(
          frame: frame,
          rotation: rotation,
          targetSize: 4,
          isChannelsFirst: channelsFirst,
          useLetterbox: true,
          outputBuffer: buffer,
        );
        expect(identical(reused.inputBuffer, buffer), isTrue);
        expect(reused.inputBuffer, expected.inputBuffer);
        expect(reused.meanBrightness, expected.meanBrightness);
        expect(reused.padX, expected.padX);
        expect(reused.padY, expected.padY);
      }
    }
  });

  test('Transferred frame is a snapshot independent of camera plane reuse', () {
    final image = colorImage();
    final expected = List<int>.from(image.planes.first.bytes);
    final transferred = TransferredFrame.fromCamera(image);
    image.planes.first.bytes.fillRange(0, image.planes.first.bytes.length, 0);
    final frame = transferred.materialize();
    expect(frame.planes.single.bytes, expected);
    expect(frame.planes.single.rowStride, 8);
    expect(frame.planes.single.pixelStride, 4);
    expect(() => transferred.materialize(), throwsA(isA<ArgumentError>()));
  });

  test('Wrong-sized output buffers are rejected before preprocessing', () {
    expect(
        () => ImageConverter.convertFrame(
              frame: FrameData.fromCamera(colorImage()),
              rotation: 0,
              targetSize: 2,
              outputBuffer: Float32List(1),
            ),
        throwsArgumentError);
  });
}
