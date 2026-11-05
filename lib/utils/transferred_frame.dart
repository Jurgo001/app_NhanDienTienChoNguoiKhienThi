import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'image_converter.dart';

/// One snapshot copy into transferable storage; no second plane copy is needed
/// when the receiving worker materializes the message.
class TransferredFrame {
  TransferredFrame.fromCamera(CameraImage image)
      : width = image.width,
        height = image.height,
        format = image.format.group,
        lengths = [for (final plane in image.planes) plane.bytes.length],
        rowStrides = [for (final plane in image.planes) plane.bytesPerRow],
        pixelStrides = [
          for (final plane in image.planes) plane.bytesPerPixel ?? 1
        ],
        data = TransferableTypedData.fromList(
            [for (final plane in image.planes) plane.bytes]);

  final int width, height;
  final ImageFormatGroup format;
  final List<int> lengths, rowStrides, pixelStrides;
  final TransferableTypedData data;

  FrameData materialize() {
    final bytes = data.materialize().asUint8List();
    var offset = 0;
    final planes = <FramePlane>[];
    for (var i = 0; i < lengths.length; i++) {
      planes.add(FramePlane.fromBytes(
        Uint8List.sublistView(bytes, offset, offset + lengths[i]),
        rowStride: rowStrides[i],
        pixelStride: pixelStrides[i],
      ));
      offset += lengths[i];
    }
    return FrameData.fromPlanes(
        width: width, height: height, format: format, planes: planes);
  }
}
