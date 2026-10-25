import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/detection_result.dart';
import '../utils/image_converter.dart';
import '../utils/model_contract.dart';
import '../utils/yolo_decoder.dart';
import 'detector_service.dart';
import 'image_quality_service.dart';

class _InferenceRequest {
  const _InferenceRequest(
      this.address,
      this.frame,
      this.rotation,
      this.size,
      this.channelsFirst,
      this.outputShape,
      this.floor,
      this.iou,
      this.letterbox);
  final int address, rotation, size;
  final FrameData frame;
  final bool channelsFirst, letterbox;
  final List<int> outputShape;
  final double floor, iou;
}

class _InferenceResult {
  const _InferenceResult(this.boxes, this.brightness, this.contrast);
  final List<BoundingBox> boxes;
  final double brightness, contrast;
}

/// Chạy trên worker; không đóng Interpreter.fromAddress vì nó mượn native handle.
_InferenceResult _infer(_InferenceRequest p) {
  final converted = ImageConverter.convertFrame(
    frame: p.frame,
    rotation: p.rotation,
    targetSize: p.size,
    isChannelsFirst: p.channelsFirst,
    useLetterbox: p.letterbox,
  );
  


  
final interpreter = Interpreter.fromAddress(p.address);

// Đồng bộ trạng thái cấp phát tensor cho wrapper trong isolate.
interpreter.allocateTensors();

interpreter
    .getInputTensor(0)
    .setTo(converted.inputBuffer.buffer.asUint8List());

interpreter.invoke();




  interpreter
      .getInputTensor(0)
      .setTo(converted.inputBuffer.buffer.asUint8List());
  interpreter.invoke();
  final tensor = interpreter.getOutputTensor(0);
  final bytes = tensor.data;
  final count = p.outputShape.reduce((a, b) => a * b);
  final values = Float32List.fromList(
    bytes.buffer.asFloat32List(bytes.offsetInBytes, count),
  );
  final boxes = YoloDecoder.decodeOutput(
    flatOutput: values,
    outputShape: p.outputShape,
    inputSize: p.size,
    confidenceThreshold: p.floor,
    iouThreshold: p.iou,
    padX: converted.padX,
    padY: converted.padY,
    scaleWidth: converted.scaleWidth,
    scaleHeight: converted.scaleHeight,
  );
  return _InferenceResult(
      boxes, converted.meanBrightness, converted.contrastStdDev);
}

class MoneyDetector implements DetectorService {
  MoneyDetector({
    this.modelAssetPath = 'assets/models/best_float32.tflite',
    this.confidenceThreshold = 0.78,
    this.lowConfidenceFloor = 0.40,
    this.iouThreshold = 0.45,
    this.useLetterbox = true,
    this.qualityService = const ImageQualityService(),
  });
  final String modelAssetPath;
  final double confidenceThreshold, lowConfidenceFloor, iouThreshold;
  // YOLO predict mặc định giữ tỷ lệ. Cần đối chiếu bằng ảnh validation thực tế.
  final bool useLetterbox;
  final ImageQualityService qualityService;
  Interpreter? _interpreter;
  Future<void>? _initializing;
  Future<DetectionResult>? _active;
  bool _closing = false;
  String? _lastInitError;
  List<int> _inputShape = [], _outputShape = [];
  bool _channelsFirst = true;
  int _size = 416;
  @override
  bool get isInitialized => _interpreter != null && !_closing;
  @override
  bool get isBusy => _active != null;
  String? get lastInitError => _lastInitError;
  @override
  String get modelInfo => isInitialized
      ? 'TFLite float32: $_inputShape → $_outputShape'
      : 'Chưa nạp model: ${_lastInitError ?? modelAssetPath}';

  @override
  Future<void> initialize() {
    if (_closing) return Future.error(StateError('Detector đã đóng.'));
    if (isInitialized) return Future.value();
    return _initializing ??= _load().whenComplete(() => _initializing = null);
  }

  Future<void> _load() async {
    Interpreter? next;
    try {
      _lastInitError = null;
      final options = InterpreterOptions()..threads = 4;
      try {
        next = await Interpreter.fromAsset(modelAssetPath, options: options);
      } finally {
        options.delete();
      }
      next.allocateTensors();
      final input = next.getInputTensor(0), output = next.getOutputTensor(0);
      if (input.type != TensorType.float32 ||
          output.type != TensorType.float32) {
        throw StateError('Cần model float32; chưa hỗ trợ model lượng tử hóa.');
      }
      ModelContract.validate(input.shape, output.shape);
      _inputShape = List.of(input.shape);
      _outputShape = List.of(output.shape);
      _channelsFirst = _inputShape[1] == 3;
      _size = _channelsFirst ? _inputShape[2] : _inputShape[1];
      _interpreter = next;
    } catch (error) {
      next?.close();
      _lastInitError = error.toString();
      rethrow;
    }
  }

  @override
  Future<DetectionResult> detectFrame(CameraImage image,
      {int sensorOrientation = 90}) {
    if (!isInitialized) {
      return Future.value(
          DetectionResult.error(_lastInitError ?? 'Model chưa sẵn sàng.'));
    }
    if (isBusy) {
      return Future.value(DetectionResult(status: DetectionStatus.skippedBusy));
    }
    return _active =
        _detect(image, sensorOrientation).whenComplete(() => _active = null);
  }

  Future<DetectionResult> _detect(CameraImage image, int rotation) async {
    final clock = Stopwatch()..start();
    try {
      final payload = _InferenceRequest(
        _interpreter!.address,
        FrameData.fromCamera(image),
        rotation,
        _size,
        _channelsFirst,
        _outputShape,
        lowConfidenceFloor,
        iouThreshold,
        useLetterbox,
      );
      final out = await Isolate.run(() => _infer(payload));
      debugPrint(
      '[AI_PERF] Frame processing: '
      '${clock.elapsedMilliseconds} ms',
      );
      return _evaluateDetections(
        boxes: out.boxes,
        inferenceTimeMs: clock.elapsedMilliseconds,
        preprocessed: PreprocessedFrame(
          inputBuffer: Float32List(0),
          meanBrightness: out.brightness,
          contrastStdDev: out.contrast,
          padX: 0,
          padY: 0,
          scaleWidth: 1,
          scaleHeight: 1,
        ),
      );
    } catch (error, stack) {
      debugPrint('TFLite inference error: $error\n$stack');
      return DetectionResult.error('Lỗi suy luận: $error');
    }
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

    final List<BoundingBox> confidentBoxes =
        boxes.where((b) => b.confidence >= confidenceThreshold).toList();

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
    _closing = true;
    try {
      await _initializing;
    } catch (_) {/* lỗi init đã chuyển cho caller */}
    await _active;
    _interpreter?.close();
    _interpreter = null;
  }
}
