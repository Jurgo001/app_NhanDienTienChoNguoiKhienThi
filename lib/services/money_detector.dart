import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/detection_result.dart';
import '../utils/image_converter.dart';
import '../utils/model_contract.dart';
import '../utils/transferred_frame.dart';
import '../utils/yolo_decoder.dart';
import 'detector_service.dart';
import 'image_quality_service.dart';
import 'persistent_worker.dart';
import 'model_asset_file.dart';

class _InferenceConfiguration {
  const _InferenceConfiguration(
      this.address,
      this.size,
      this.channelsFirst,
      this.outputShape,
      this.floor,
      this.iou,
      this.letterbox,
      this.minBrightness,
      this.maxBrightness);
  final int address, size;
  final bool channelsFirst, letterbox;
  final List<int> outputShape;
  final double floor, iou, minBrightness, maxBrightness;
}

class _InferenceRequest {
  const _InferenceRequest(this.frame, this.rotation);
  final TransferredFrame frame;
  final int rotation;
}

class _InferenceResult {
  const _InferenceResult(this.boxes, this.brightness, this.contrast,
      this.preprocessUs, this.invokeUs, this.decodeUs);
  final List<BoundingBox> boxes;
  final double brightness, contrast;
  final int preprocessUs, invokeUs, decodeUs;
}

_InferenceResult Function(_InferenceRequest) _createProcessor(
    _InferenceConfiguration configuration) {
  // The main isolate owns the native handle. The worker only borrows it and
  // must exit before the main isolate closes it.
  final interpreter =
      Interpreter.fromAddress(configuration.address, allocated: true);
  final input = interpreter.getInputTensor(0);
  final output = interpreter.getOutputTensor(0);
  final buffer = Float32List(configuration.size * configuration.size * 3);
  final inputBytes =
      buffer.buffer.asUint8List(buffer.offsetInBytes, buffer.lengthInBytes);
  final count = configuration.outputShape.reduce((a, b) => a * b);
  return (request) {
    final timer = Stopwatch()..start();
    final converted = ImageConverter.convertFrame(
      frame: request.frame.materialize(),
      rotation: request.rotation,
      targetSize: configuration.size,
      isChannelsFirst: configuration.channelsFirst,
      useLetterbox: configuration.letterbox,
      outputBuffer: buffer,
    );
    final preprocessUs = timer.elapsedMicroseconds;
    if (converted.meanBrightness < configuration.minBrightness ||
        converted.meanBrightness > configuration.maxBrightness) {
      return _InferenceResult(const [], converted.meanBrightness,
          converted.contrastStdDev, preprocessUs, 0, 0);
    }
    timer.reset();
    // The tensor shape stays fixed. This setter copies directly into its
    // allocated storage, avoiding Tensor.setTo's temporary native allocation.
    input.data = inputBytes;
    interpreter.invoke();
    final invokeUs = timer.elapsedMicroseconds;
    timer.reset();
    final bytes = output.data;
    // Decode while this view is valid; no new inference runs concurrently.
    final values = bytes.buffer.asFloat32List(bytes.offsetInBytes, count);
    final boxes = YoloDecoder.decodeOutput(
      flatOutput: values,
      outputShape: configuration.outputShape,
      inputSize: configuration.size,
      confidenceThreshold: configuration.floor,
      iouThreshold: configuration.iou,
      padX: converted.padX,
      padY: converted.padY,
      scaleWidth: converted.scaleWidth,
      scaleHeight: converted.scaleHeight,
    );
    return _InferenceResult(
        boxes,
        converted.meanBrightness,
        converted.contrastStdDev,
        preprocessUs,
        invokeUs,
        timer.elapsedMicroseconds);
  };
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
  final bool useLetterbox;
  final ImageQualityService qualityService;
  Interpreter? _interpreter;
  ModelAssetFile? _modelFile;
  Future<void>? _releasing;
  PersistentWorker<_InferenceConfiguration, _InferenceRequest,
      _InferenceResult>? _worker;
  Future<void>? _initializing, _disposing;
  Future<DetectionResult>? _active;
  bool _closing = false;
  String? _lastInitError;
  List<int> _inputShape = [], _outputShape = [];
  final _performanceLogClock = Stopwatch()..start();
  int _lastPerformanceLogMs = -1000;
  static final _emptyBuffer = Float32List(0);

  @override
  bool get isInitialized =>
      _interpreter != null &&
      (_worker?.isStarted ?? false) &&
      !_closing &&
      _releasing == null;
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
    if (_releasing != null) return _releasing!.then((_) => initialize());
    if (isInitialized) return Future.value();
    return _initializing ??= _load().whenComplete(() => _initializing = null);
  }

  Future<void> _load() async {
    Interpreter? next;
    ModelAssetFile? modelFile;
    PersistentWorker<_InferenceConfiguration, _InferenceRequest,
        _InferenceResult>? worker;
    try {
      _lastInitError = null;
      await _releaseHandles();
      final options = InterpreterOptions()..threads = 4;
      try {
        modelFile = await ModelAssetFile.create(modelAssetPath);
        next = Interpreter.fromFile(modelFile.file, options: options);
        await modelFile.releaseMappedPath();
      } finally {
        options.delete();
      }
      final input = next.getInputTensor(0), output = next.getOutputTensor(0);
      if (input.type != TensorType.float32 ||
          output.type != TensorType.float32) {
        throw StateError('Cần model float32; chưa hỗ trợ model lượng tử hóa.');
      }
      ModelContract.validate(input.shape, output.shape);
      _inputShape = List.of(input.shape);
      _outputShape = List.of(output.shape);
      final channelsFirst = _inputShape[1] == 3;
      final size = channelsFirst ? _inputShape[2] : _inputShape[1];
      worker = PersistentWorker();
      await worker.start(
        _InferenceConfiguration(
            next.address,
            size,
            channelsFirst,
            _outputShape,
            lowConfidenceFloor,
            iouThreshold,
            useLetterbox,
            qualityService.minBrightness,
            qualityService.maxBrightness),
        _createProcessor,
      );
      _worker = worker;
      _interpreter = next;
      _modelFile = modelFile;
    } catch (error) {
      await worker?.close();
      next?.close();
      await modelFile?.delete();
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
      final out = await _worker!
          .run(_InferenceRequest(TransferredFrame.fromCamera(image), rotation));
      final elapsed = clock.elapsedMilliseconds;
      if (kDebugMode &&
          _performanceLogClock.elapsedMilliseconds - _lastPerformanceLogMs >=
              1000) {
        _lastPerformanceLogMs = _performanceLogClock.elapsedMilliseconds;
        debugPrint(
            '[AI_PERF] total=$elapsed ms; preprocess=${out.preprocessUs / 1000} ms; '
            'invoke=${out.invokeUs / 1000} ms; decode=${out.decodeUs / 1000} ms');
      }
      return _evaluateDetections(
        boxes: out.boxes,
        inferenceTimeMs: elapsed,
        preprocessed: PreprocessedFrame(
          inputBuffer: _emptyBuffer,
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
      // Chỉ xác định hướng khi YOLO có phát hiện mệnh giá
      // nhưng chưa đủ độ tin cậy để công nhận kết quả.
      final String? positionGuidance = bestBox.denomination != null
          ? qualityService.getHorizontalGuidance(bestBox)
          : null;

      return DetectionResult(
        denomination: bestBox.denomination,
        side: bestBox.side,
        confidence: bestBox.confidence,
        boxes: [bestBox],
        status: DetectionStatus.lowConfidence,
        message: positionGuidance ??
            ImageQualityService.getGuidanceMessage(
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
  Future<void> releaseResources() {
    if (_closing) return _disposing ?? Future.value();
    return _releasing ??=
        _releaseAfterInitialize().whenComplete(() => _releasing = null);
  }

  Future<void> _releaseAfterInitialize() async {
    try {
      await _initializing;
    } catch (_) {}
    await _releaseHandles();
  }

  Future<void> _releaseHandles() async {
    await _active;
    final worker = _worker;
    final interpreter = _interpreter;
    final modelFile = _modelFile;
    _worker = null;
    _interpreter = null;
    _modelFile = null;
    try {
      await worker?.close();
    } finally {
      try {
        interpreter?.close();
      } finally {
        await modelFile?.delete();
      }
    }
  }

  @override
  Future<void> dispose() {
    _closing = true;
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      await _initializing;
    } catch (_) {}
    await _releasing;
    await _releaseHandles();
  }
}
