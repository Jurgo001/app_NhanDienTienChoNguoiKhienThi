import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart' as cp;

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
