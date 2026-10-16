import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/detector_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/image_quality_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/image_converter.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/yolo_decoder.dart';

/// Gói dữ liệu thô đã tách khỏi CameraImage để truyền an toàn sang Isolate ngầm.
class _IsolateFramePayload {
  final int interpreterAddress;
  final int width;
  final int height;
  final int sensorOrientation;
  final int targetSize;
  final bool isChannelsFirst;
  final bool isYuv420;
  final Uint8List yBytes;
  final Uint8List? uBytes;
  final Uint8List? vBytes;
  final int yRowStride;
  final int yPixelStride;
  final int uvRowStride;
  final int uvPixelStride;
  final List<int> outputShape;
  final bool isFloatInput;
  final bool isFloatOutput;
  final double lowConfidenceFloor;
  final double iouThreshold;

  const _IsolateFramePayload({
    required this.interpreterAddress,
    required this.width,
    required this.height,
    required this.sensorOrientation,
    required this.targetSize,
    required this.isChannelsFirst,
    required this.isYuv420,
    required this.yBytes,
    this.uBytes,
    this.vBytes,
    required this.yRowStride,
    required this.yPixelStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.outputShape,
    required this.isFloatInput,
    required this.isFloatOutput,
    required this.lowConfidenceFloor,
    required this.iouThreshold,
  });
}

/// Kết quả trả về từ Isolate ngầm về Main Thread.
class _IsolateInferenceOutput {
  final List<BoundingBox> boxes;
  final double meanBrightness;
  final double contrastStdDev;

  const _IsolateInferenceOutput({
    required this.boxes,
    required this.meanBrightness,
    required this.contrastStdDev,
  });
}

/// Dịch vụ nhận diện tiền mặt thực tế bằng TensorFlow Lite chạy trên Isolate ngầm.
class MoneyDetector implements DetectorService {
  final String modelAssetPath;
  final double confidenceThreshold;
  final double lowConfidenceFloor;
  final double iouThreshold;
  final ImageQualityService qualityService;

  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _isBusy = false;
  String? _lastInitError;

  List<int> _inputShape = const [1, 3, 416, 416];
  List<int> _outputShape = const [1, 22, 3549];
  TensorType _inputType = TensorType.float32;
  TensorType _outputType = TensorType.float32;
  int _inputSize = 416;
  bool _isInputChannelsFirst = true;

  MoneyDetector({
    this.modelAssetPath = 'assets/models/best_float32.tflite',
    this.confidenceThreshold = 0.78,
    this.lowConfidenceFloor = 0.40,
    this.iouThreshold = 0.45,
    this.qualityService = const ImageQualityService(),
  });

  @override
  bool get isInitialized => _isInitialized && _interpreter != null;

  @override
  bool get isBusy => _isBusy;

  String? get lastInitError => _lastInitError;

  @override
  String get modelInfo {
    if (!isInitialized) {
      return 'Chưa khởi tạo (${_lastInitError ?? "Chưa nạp model"})';
    }
    return 'TFLite (Isolate): $modelAssetPath | In: $_inputShape | Out: $_outputShape';
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized && _interpreter != null) return;

    try {
      _lastInitError = null;
      final options = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );
      _interpreter!.allocateTensors();

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      _inputShape = List<int>.from(inputTensor.shape);
      _outputShape = List<int>.from(outputTensor.shape);
      _inputType = inputTensor.type;
      _outputType = outputTensor.type;

      if (_inputShape.length == 4) {
        if (_inputShape[1] == 3) {
          _isInputChannelsFirst = true;
          _inputSize = _inputShape[2];
        } else {
          _isInputChannelsFirst = false;
          _inputSize = _inputShape[1];
        }
      }

      _isInitialized = true;
      debugPrint('✅ [MoneyDetector] Khởi tạo thành công: $modelInfo');
    } catch (e, stack) {
      _isInitialized = false;
      _lastInitError = e.toString();
      debugPrint('❌ [MoneyDetector] Lỗi khởi tạo TFLite: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<DetectionResult> detectFrame(
    CameraImage cameraImage, {
    int sensorOrientation = 90,
  }) async {
    if (!isInitialized || _interpreter == null) {
      return DetectionResult.error(
        _lastInitError ?? 'Model TFLite chưa được khởi tạo',
      );
    }

    if (_isBusy) {
      return DetectionResult(
        status: DetectionStatus.skippedBusy,
        message: ImageQualityService.getGuidanceMessage(
          DetectionStatus.skippedBusy,
        ),
      );
    }

    _isBusy = true;
    final stopwatch = Stopwatch()..start();

    try {
      // Sao chép nhanh mảng byte thô (< 0.5ms) để gửi sang Isolate an toàn
      final bool isYuv420 =
          cameraImage.format.group == ImageFormatGroup.yuv420 ||
          cameraImage.planes.length >= 3;

      final payload = _IsolateFramePayload(
        interpreterAddress: _interpreter!.address,
        width: cameraImage.width,
        height: cameraImage.height,
        sensorOrientation: sensorOrientation,
        targetSize: _inputSize,
        isChannelsFirst: _isInputChannelsFirst,
        isYuv420: isYuv420,
        yBytes: Uint8List.fromList(cameraImage.planes[0].bytes),
        uBytes: isYuv420 && cameraImage.planes.length >= 3
            ? Uint8List.fromList(cameraImage.planes[1].bytes)
            : null,
        vBytes: isYuv420 && cameraImage.planes.length >= 3
            ? Uint8List.fromList(cameraImage.planes[2].bytes)
            : null,
        yRowStride: cameraImage.planes[0].bytesPerRow,
        yPixelStride: cameraImage.planes[0].bytesPerPixel ?? 1,
        uvRowStride: isYuv420 && cameraImage.planes.length >= 3
            ? cameraImage.planes[1].bytesPerRow
            : 0,
        uvPixelStride: isYuv420 && cameraImage.planes.length >= 3
            ? (cameraImage.planes[1].bytesPerPixel ?? 1)
            : 1,
        outputShape: _outputShape,
        isFloatInput: _inputType == TensorType.float32,
        isFloatOutput: _outputType == TensorType.float32,
        lowConfidenceFloor: lowConfidenceFloor,
        iouThreshold: iouThreshold,
      );

      // Đẩy toàn bộ việc nặng sang luồng Isolate ngầm, giải phóng 100% UI Thread
      final _IsolateInferenceOutput isolateOut = await Isolate.run(
        () => _runHeavyInferenceInIsolate(payload),
      );

      stopwatch.stop();
      final int elapsedMs = stopwatch.elapsedMilliseconds;

      final dummyPreprocessed = PreprocessedFrame(
        inputBuffer: Float32List(0),
        meanBrightness: isolateOut.meanBrightness,
        contrastStdDev: isolateOut.contrastStdDev,
        padX: 0.0,
        padY: 0.0,
        scaleWidth: 1.0,
        scaleHeight: 1.0,
      );

      return _evaluateDetections(
        boxes: isolateOut.boxes,
        preprocessed: dummyPreprocessed,
        inferenceTimeMs: elapsedMs,
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('❌ [MoneyDetector] Lỗi khi chạy inference: $e\n$stack');
      return DetectionResult.error('Lỗi inference: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// Hàm tĩnh chạy hoàn toàn trên Worker Isolate (không làm khựng Camera).
  static _IsolateInferenceOutput _runHeavyInferenceInIsolate(
    _IsolateFramePayload p,
  ) {
    final int targetSize = p.targetSize;
    final int planeSize = targetSize * targetSize;
    final Float32List inputBuffer = Float32List(3 * planeSize);

    double sumLuma = 0.0;
    double sumLumaSq = 0.0;
    int sampleCount = 0;

    final int srcWidth = p.width;
    final int srcHeight = p.height;

    for (int ty = 0; ty < targetSize; ty++) {
      final double normY = ty / targetSize;
      for (int tx = 0; tx < targetSize; tx++) {
        final double normX = tx / targetSize;

        int srcX;
        int srcY;
        switch (p.sensorOrientation) {
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
        if (p.isYuv420 && p.uBytes != null && p.vBytes != null) {
          final int yIdx = srcY * p.yRowStride + srcX * p.yPixelStride;
          final int uvIdx =
              (srcY >> 1) * p.uvRowStride + (srcX >> 1) * p.uvPixelStride;

          final int yVal = p.yBytes[yIdx.clamp(0, p.yBytes.length - 1)] & 0xFF;
          final int uVal = p.uBytes![uvIdx.clamp(0, p.uBytes!.length - 1)] & 0xFF;
          final int vVal = p.vBytes![uvIdx.clamp(0, p.vBytes!.length - 1)] & 0xFF;

          final int c = yVal - 16;
          final int d = uVal - 128;
          final int e = vVal - 128;

          r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

          if ((tx & 7) == 0 && (ty & 7) == 0) {
            sumLuma += yVal;
            sumLumaSq += yVal * yVal;
            sampleCount++;
          }
        } else {
          final int bgraIdx = srcY * p.yRowStride + srcX * 4;
          if (bgraIdx + 2 < p.yBytes.length) {
            b = p.yBytes[bgraIdx] & 0xFF;
            g = p.yBytes[bgraIdx + 1] & 0xFF;
            r = p.yBytes[bgraIdx + 2] & 0xFF;
          }
        }

        final int pixelIdx = ty * targetSize + tx;
        if (p.isChannelsFirst) {
          inputBuffer[pixelIdx] = r / 255.0;
          inputBuffer[planeSize + pixelIdx] = g / 255.0;
          inputBuffer[2 * planeSize + pixelIdx] = b / 255.0;
        } else {
          final int baseIdx = pixelIdx * 3;
          inputBuffer[baseIdx] = r / 255.0;
          inputBuffer[baseIdx + 1] = g / 255.0;
          inputBuffer[baseIdx + 2] = b / 255.0;
        }
      }
    }

    // Gọi trực tiếp TFLite Interpreter từ địa chỉ bộ nhớ C++ trong Isolate ngầm
    final interpreter = Interpreter.fromAddress(p.interpreterAddress);
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    if (p.isFloatInput) {
      inputTensor.setTo(inputBuffer.buffer.asUint8List());
    } else {
      final Int8List qIn = Int8List(inputBuffer.length);
      for (int i = 0; i < inputBuffer.length; i++) {
        qIn[i] = (inputBuffer[i] * 255.0 - 128.0).round().clamp(-128, 127);
      }
      inputTensor.setTo(qIn.buffer.asUint8List());
    }

    interpreter.invoke();

    final int numOutputElements = p.outputShape.fold<int>(
      1,
      (prev, elem) => prev * elem,
    );
    final Float32List outputFloatBuffer = Float32List(numOutputElements);

    if (p.isFloatOutput) {
      final Uint8List rawOut = outputTensor.data;
      final Float32List view = rawOut.buffer.asFloat32List(
        rawOut.offsetInBytes,
        numOutputElements,
      );
      outputFloatBuffer.setAll(0, view);
    } else {
      final Uint8List rawOut = outputTensor.data;
      for (int i = 0; i < numOutputElements && i < rawOut.length; i++) {
        outputFloatBuffer[i] = (rawOut[i] & 0xFF) / 255.0;
      }
    }

    final List<BoundingBox> boxes = YoloDecoder.decodeOutput(
      flatOutput: outputFloatBuffer,
      outputShape: p.outputShape,
      inputSize: targetSize,
      confidenceThreshold: p.lowConfidenceFloor,
      iouThreshold: p.iouThreshold,
    );

    final double meanLuma = sampleCount > 0 ? (sumLuma / sampleCount) : 128.0;
    final double variance = sampleCount > 0
        ? ((sumLumaSq / sampleCount) - (meanLuma * meanLuma)).clamp(0.0, 65025.0)
        : 0.0;

    return _IsolateInferenceOutput(
      boxes: boxes,
      meanBrightness: meanLuma,
      contrastStdDev: variance,
    );
  }

  DetectionResult _evaluateDetections({
    required List<BoundingBox> boxes,
    required PreprocessedFrame preprocessed,
    required int inferenceTimeMs,
  }) {
    if (boxes.isEmpty) {
      final lightingIssue = qualityService.evaluateLighting(preprocessed);
      if (lightingIssue != null) {
        return DetectionResult(
          status: lightingIssue,
          message: ImageQualityService.getGuidanceMessage(lightingIssue),
          inferenceTimeMs: inferenceTimeMs,
          brightness: preprocessed.meanBrightness,
        );
      }
      return DetectionResult.empty(
        inferenceTimeMs: inferenceTimeMs,
        brightness: preprocessed.meanBrightness,
      );
    }

    final List<BoundingBox> confidentBoxes = boxes
        .where((b) => b.confidence >= confidenceThreshold)
        .toList();

    if (confidentBoxes.length >= 2) {
      return DetectionResult(
        status: DetectionStatus.multipleNotes,
        boxes: confidentBoxes,
        confidence: confidentBoxes.first.confidence,
        message: ImageQualityService.getGuidanceMessage(
          DetectionStatus.multipleNotes,
        ),
        inferenceTimeMs: inferenceTimeMs,
        brightness: preprocessed.meanBrightness,
      );
    }

    final BoundingBox bestBox = boxes.first;

    final geometryIssue = qualityService.evaluateBoxGeometry(bestBox);
    if (geometryIssue != null) {
      return DetectionResult(
        denomination: bestBox.denomination,
        side: bestBox.side,
        confidence: bestBox.confidence,
        boxes: [bestBox],
        status: geometryIssue,
        message: ImageQualityService.getGuidanceMessage(geometryIssue),
        inferenceTimeMs: inferenceTimeMs,
        brightness: preprocessed.meanBrightness,
      );
    }

    if (bestBox.confidence < confidenceThreshold ||
        bestBox.denomination == null) {
      return DetectionResult(
        denomination: bestBox.denomination,
        side: bestBox.side,
        confidence: bestBox.confidence,
        boxes: [bestBox],
        status: DetectionStatus.lowConfidence,
        message: ImageQualityService.getGuidanceMessage(
          DetectionStatus.lowConfidence,
        ),
        inferenceTimeMs: inferenceTimeMs,
        brightness: preprocessed.meanBrightness,
      );
    }

    return DetectionResult(
      denomination: bestBox.denomination,
      side: bestBox.side,
      confidence: bestBox.confidence,
      boxes: [bestBox],
      status: DetectionStatus.detected,
      message: bestBox.denomination!.spokenText,
      inferenceTimeMs: inferenceTimeMs,
      brightness: preprocessed.meanBrightness,
    );
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _isBusy = false;
    _interpreter?.close();
    _interpreter = null;
  }
}