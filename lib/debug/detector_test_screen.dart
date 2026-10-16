import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/camera_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/detector_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/mock_money_detector.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/money_detector.dart';

/// Màn hình kiểm thử nội bộ dành riêng cho TV2 (Camera + TFLite/Mock).
class DetectorTestScreen extends StatefulWidget {
  const DetectorTestScreen({super.key});

  @override
  State<DetectorTestScreen> createState() => _DetectorTestScreenState();
}

class _DetectorTestScreenState extends State<DetectorTestScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService(minFrameIntervalMs: 300);
  late final MoneyDetector _realDetector;
  late final MockMoneyDetector _mockDetector;

  bool _useMock = false;
  bool _closing = false;
  late final Future<void> _initialization;
  bool _isLoading = true;
  String? _errorBanner;
  DetectionResult _latestResult = DetectionResult.empty();

  DetectorService get _activeDetector =>
      _useMock ? _mockDetector : _realDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realDetector = MoneyDetector(
      modelAssetPath: 'assets/models/best_float32.tflite',
    );
    _mockDetector = MockMoneyDetector();
    _initialization = _initPipeline();
  }

  Future<void> _initPipeline() async {
    setState(() {
      _isLoading = true;
      _errorBanner = null;
    });

    try {
      await _mockDetector.initialize();

      try {
        await _realDetector.initialize();
      } catch (e) {
        _errorBanner =
            'Không nạp được best_float32.tflite: $e.\nBạn có thể bật công tắc MOCK ở góc phải để test luồng.';
      }

      if (_closing) return;
      await _cameraService.initializeCamera();
      if (_closing) return;
      await _cameraService.startStream(_onCameraFrame);
    } catch (e) {
      _errorBanner = 'Lỗi khởi tạo Camera/Detector: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onCameraFrame(
    CameraImage cameraImage,
    int sensorOrientation,
  ) async {
    if (!mounted) return;
    final result = await _activeDetector.detectFrame(
      cameraImage,
      sensorOrientation: sensorOrientation,
    );

    if (result.status == DetectionStatus.skippedBusy) return;

    if (mounted) {
      setState(() {
        _latestResult = result;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closing || _isLoading) return;
    unawaited(_cameraService.handleAppLifecycleState(state).then((_) {
      if (mounted) setState(() {});
    }).catchError((Object error) {
      if (mounted) setState(() => _errorBanner = 'Lỗi camera: $error');
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closing = true;
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    await _initialization;
    await _cameraService.dispose();
    await _realDetector.dispose();
    await _mockDetector.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: const Text('TV2 Debug: Camera & TFLite'),
        actions: [
          Row(
            children: [
              const Text('MOCK', style: TextStyle(fontSize: 12)),
              Switch(
                value: _useMock,
                activeThumbColor: Colors.amber,
                onChanged: (val) {
                  setState(() {
                    _useMock = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorBanner != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade900,
              padding: const EdgeInsets.all(10),
              child: Text(
                _errorBanner!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (controller != null && controller.value.isInitialized)
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          CustomPaint(
                            painter: _BoundingBoxPainter(
                              boxes: _latestResult.boxes,
                              isMock: _latestResult.isMock,
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Camera chưa sẵn sàng',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
          ),
          _buildBottomTelemetryPanel(),
        ],
      ),
    );
  }

  Widget _buildBottomTelemetryPanel() {
    final denomText = _latestResult.denomination?.displayText ?? '---';
    final sideText = _latestResult.side.label;
    final confPct = (_latestResult.confidence * 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _latestResult.isMock
                    ? 'CHẾ ĐỘ: MÔ PHỎNG (MOCK)'
                    : 'CHẾ ĐỘ: AI TFLITE THẬT',
                style: TextStyle(
                  color:
                      _latestResult.isMock ? Colors.amber : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Thời gian xử lý: ${_latestResult.inferenceTimeMs} ms',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            denomText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mặt: $sideText | Độ tin cậy: $confPct% | Trạng thái: ${_latestResult.status.name}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Thông điệp: ${_latestResult.message ?? ""}',
            style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _activeDetector.modelInfo,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<BoundingBox> boxes;
  final bool isMock;

  _BoundingBoxPainter({required this.boxes, required this.isMock});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = isMock ? Colors.amber : Colors.greenAccent;

    for (final box in boxes) {
      final rect = Rect.fromLTRB(
        box.x1 * size.width,
        box.y1 * size.height,
        box.x2 * size.width,
        box.y2 * size.height,
      );
      canvas.drawRect(rect, paint);

      final textSpan = TextSpan(
        text: '${box.rawLabel} ${(box.confidence * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: isMock ? Colors.amber : Colors.greenAccent,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(rect.left, (rect.top - 18).clamp(0.0, size.height - 18)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes || oldDelegate.isMock != isMock;
  }
}
