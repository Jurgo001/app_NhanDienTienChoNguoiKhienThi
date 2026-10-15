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

/// Dịch vụ nhận diện tiền mặt thực tế bằng TensorFlow Lite (YOLOv8 Nano).
class MoneyDetector implements DetectorService {
  /// Đường dẫn file model trong pubspec.yaml (Ưu tiên bản Float32 ổn định).
  final String modelAssetPath;

  /// Ngưỡng tin cậy tối thiểu để công nhận kết quả hợp lệ (Mặc định: 0.78).
  final double confidenceThreshold;

  /// Ngưỡng tin cậy sàn để phát hiện tờ tiền bị mờ/rung (Mặc định: 0.40).
  final double lowConfidenceFloor;

  /// Ngưỡng lọc trùng lặp NMS IoU (Mặc định: 0.45).
  final double iouThreshold;

  /// Dịch vụ kiểm tra chất lượng ảnh (sáng/tối, gần/xa).
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
    return 'TFLite: $modelAssetPath | In: $_inputShape ($_inputType) | Out: $_outputShape';
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

      // Tự động nhận diện layout NCHW [1, 3, 416, 416] hay NHWC [1, 416, 416, 3]
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

    // Khóa van (Frame Throttling): bỏ qua nếu frame trước chưa chạy xong
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
      // 1. Tiền xử lý ảnh CameraImage -> Float32List [416x416]
      final PreprocessedFrame preprocessed = ImageConverter.convertCameraImage(
        cameraImage: cameraImage,
        sensorOrientation: sensorOrientation,
        targetSize: _inputSize,
        isChannelsFirst: _isInputChannelsFirst,
        useLetterbox: false, // Khớp với cấu hình Stretch to 416x416 trên Roboflow
      );

      // 2. Cấp phát bộ đệm đầu ra phẳng theo đúng số phần tử của Output Tensor
      final int numOutputElements = _outputShape.fold<int>(
        1,
        (prev, elem) => prev * elem,
      );
      final Float32List outputFloatBuffer = Float32List(numOutputElements);

      // 3. Chạy suy luận trực tiếp qua ByteBuffer và invoke()
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      if (_inputType == TensorType.float32) {
        inputTensor.setTo(preprocessed.inputBuffer.buffer.asUint8List());
      } else {
        // Fallback nếu nạp nhầm model uint8/int8: lượng tử hóa nhanh từ [0..1]
        final Int8List quantizedInput = Int8List(preprocessed.inputBuffer.length);
        for (int i = 0; i < preprocessed.inputBuffer.length; i++) {
          final int val = (preprocessed.inputBuffer[i] * 255.0 - 128.0)
              .round()
              .clamp(-128, 127);
          quantizedInput[i] = val;
        }
        inputTensor.setTo(quantizedInput.buffer.asUint8List());
      }

      // Thực thi suy luận trên thiết bị
      _interpreter!.invoke();

      // Đọc dữ liệu từ Output Tensor
      if (_outputType == TensorType.float32) {
        final Uint8List rawOutBytes = outputTensor.data;
        final Float32List floatView = rawOutBytes.buffer.asFloat32List(
          rawOutBytes.offsetInBytes,
          numOutputElements,
        );
        outputFloatBuffer.setAll(0, floatView);
      } else {
        final Uint8List rawOutBytes = outputTensor.data;
        for (int i = 0; i < numOutputElements && i < rawOutBytes.length; i++) {
          outputFloatBuffer[i] = (rawOutBytes[i] & 0xFF) / 255.0;
        }
      }

      // 4. Giải mã ma trận YOLOv8 với ngưỡng sàn lowConfidenceFloor
      final List<BoundingBox> boxes = YoloDecoder.decodeOutput(
        flatOutput: outputFloatBuffer,
        outputShape: _outputShape,
        inputSize: _inputSize,
        confidenceThreshold: lowConfidenceFloor,
        iouThreshold: iouThreshold,
        padX: preprocessed.padX,
        padY: preprocessed.padY,
        scaleWidth: preprocessed.scaleWidth,
        scaleHeight: preprocessed.scaleHeight,
      );

      stopwatch.stop();
      final int elapsedMs = stopwatch.elapsedMilliseconds;

      // 5. Đánh giá kết quả và phân loại trạng thái
      return _evaluateDetections(
        boxes: boxes,
        preprocessed: preprocessed,
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

  DetectionResult _evaluateDetections({
    required List<BoundingBox> boxes,
    required PreprocessedFrame preprocessed,
    required int inferenceTimeMs,
  }) {
    // Nếu không tìm thấy vật thể nào -> kiểm tra xem có phải do phòng quá tối không
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

    // Lọc các hộp đạt ngưỡng tin cậy cao
    final List<BoundingBox> confidentBoxes = boxes
        .where((b) => b.confidence >= confidenceThreshold)
        .toList();

    // Kiểm tra trường hợp có từ 2 tờ tiền độc lập trở lên trong khung hình
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

    // Kiểm tra khoảng cách cầm máy (quá sát hoặc quá xa)
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

    // Nếu độ tin cậy nằm trong vùng lấp lửng [lowConfidenceFloor .. confidenceThreshold)
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

    // Nhận diện thành công 1 tờ tiền rõ ràng
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