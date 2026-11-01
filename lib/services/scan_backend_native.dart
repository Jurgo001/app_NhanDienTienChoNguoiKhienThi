import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detection_result.dart';
import 'camera_service.dart';
import 'detector_service.dart';
import 'money_detector.dart';
import 'scan_backend.dart';

import 'dart:async';
import 'package:light_sensor/light_sensor.dart';

ScanBackend createScanBackend() => NativeScanBackend();

class NativeScanBackend extends ScanBackend {
  NativeScanBackend({CameraService? camera, DetectorService? detector})
      : camera = camera ?? CameraService(),
        detector = detector ?? MoneyDetector();
  final CameraService camera;
  final DetectorService detector;
  CameraController? _listenedCamera;
  VoidCallback? _errorListener;
  DateTime? _classificationPauseUntil;
  DetectionStatus? _lastGuidanceStatus;
  int _sameGuidanceFrames = 0;

  // Đếm số frame liên tiếp bị thiếu sáng.
  int _consecutiveDarkFrames = 0;

// Mỗi phiên quét chỉ thử tự bật flash một lần.
// Tránh gọi camera liên tục nếu thiết bị không hỗ trợ.
  bool _flashAttempted = false;
// Thời điểm cần kiểm tra lại ánh sáng phòng.
  DateTime? _nextLightProbeAt;

// Thời điểm bắt đầu tạm tắt flash để đo sáng.
  DateTime? _lightProbeStartedAt;

  bool _lightProbeActive = false;
  int _brightProbeFrames = 0;
  DateTime? _lastDebugPrint;

  // Dùng camera để kiểm tra ánh sáng nếu Lux không đủ hữu ích.
bool _useCameraLightFallback = false;
  // Theo dõi dữ liệu từ cảm biến ánh sáng môi trường.
  StreamSubscription<int>? _luxSubscription;

  int? _currentLux;
  

// Đếm thời gian ánh sáng môi trường đủ sáng để tắt flash.
  DateTime? _luxBrightSince;

// Ghi nhận lúc bật flash để camera có thời gian chỉnh phơi sáng.
  DateTime? _torchStartedAt;

  @override
  bool get isMock => false;
  @override
  CameraController? get cameraController => camera.controller;
  @override
  Future<CameraAccess> permission({bool request = false}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Nhận diện thật hiện hỗ trợ Android. '
          'Chạy trên Chrome để thử giao diện mô phỏng.');
    }
    var status = await Permission.camera.status;
    if (request && !status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) return CameraAccess.granted;
    return status.isPermanentlyDenied || status.isRestricted
        ? CameraAccess.permanentlyDenied
        : CameraAccess.denied;
  }

  @override
  Future<void> openPermissionSettings() async {
    if (!await openAppSettings()) {
      throw StateError(
          'Không mở được cài đặt. Mở Cài đặt → Ứng dụng → Quyền camera.');
    }
  }

  @override
  Future<void> initialize() async {
    final access = await permission(request: true);
    if (access != CameraAccess.granted) {
      throw StateError(access == CameraAccess.permanentlyDenied
          ? 'Camera bị chặn. Mở Quyền camera → Cài đặt ứng dụng để cấp lại.'
          : 'Chưa được cấp quyền camera. Mở Quyền camera để thử lại.');
    }
    if (!detector.isInitialized) await detector.initialize();
    if (!camera.isInitialized) await camera.initializeCamera();
  }

  @override
  @override
  Future<void> start(DetectionCallback onResult) async {
    _useCameraLightFallback = false;
    // Reset trạng thái khi bắt đầu phiên quét mới.
    _lastDebugPrint = null;
    _classificationPauseUntil = null;
    _lastGuidanceStatus = null;
    _sameGuidanceFrames = 0;

    // Reset bộ đếm thiếu sáng và trạng thái tự bật flash.
    _consecutiveDarkFrames = 0;
    _flashAttempted = false;

    _currentLux = null; 
    _luxBrightSince = null;
    _torchStartedAt = null;

// Hủy subscription cũ nếu có.
    await _luxSubscription?.cancel();
    _luxSubscription = null;

    try {
      final hasSensor = await LightSensor.hasSensor();

      debugPrint('[LUX] Có cảm biến ánh sáng: $hasSensor');

      if (hasSensor) {
        _luxSubscription = LightSensor.luxStream().listen(
          (lux) {
            if (lux < 0) return;

            _currentLux = lux;

            // Tạm thời in từng giá trị để kiểm tra cảm biến.
            debugPrint(
              '[LUX_TEST] lux=$lux | '
              'torch=${camera.isTorchEnabled}',
            );
          },
          onError: (Object error) {
            debugPrint('[LUX_ERROR] $error');
            _currentLux = null;
          },
        );
      } else {
        debugPrint('[LUX] Dùng cơ chế camera dự phòng');
      }
    } catch (error) {
      debugPrint('[LUX] Không khởi tạo được cảm biến: $error');
      _currentLux = null;
    }

    _nextLightProbeAt = null;
    _lightProbeStartedAt = null;
    _lightProbeActive = false;
    _brightProbeFrames = 0;

    final controller = camera.controller;

    // Theo dõi lỗi xảy ra trong quá trình sử dụng camera.
    if (controller != null) {
      _listenedCamera = controller;

      _errorListener = () {
        if (controller.value.hasError) {
          onResult(
            DetectionResult.error(
              controller.value.errorDescription ??
                  'Camera gặp lỗi khi nhận ảnh.',
            ),
          );
        }
      };

      controller.addListener(_errorListener!);
    }

    // Bắt đầu nhận và xử lý từng frame từ camera.
    
await camera.startStream((image, rotation) async {
final pausedUntil = _classificationPauseUntil;
final now = DateTime.now();

final needLightingCheck = camera.isTorchEnabled &&
    (_useCameraLightFallback ||
        _lightProbeActive ||
        (_currentLux != null && _currentLux! >= 100));

if (pausedUntil != null &&
    now.isBefore(pausedUntil) &&
    !needLightingCheck) {
  return;
}

  try {
    // Phần nhận diện YOLO hiện tại của bạn.
    final result = await detector.detectFrame(
      image,
      sensorOrientation: rotation,
    );

    // Giữ nguyên GUIDANCE_DEBUG,
    // FLASH_CHECK, AUTO_FLASH và code phía dưới.


        // 2. DEBUG: Theo dõi kết quả YOLO mỗi 700ms.
        if (kDebugMode) {
          final now = DateTime.now();

          if (_lastDebugPrint == null ||
              now.difference(_lastDebugPrint!) >=
                  const Duration(milliseconds: 700)) {
            _lastDebugPrint = now;

            final box = result.boxes.isNotEmpty ? result.boxes.first : null;

            final boxInfo = box == null
                ? 'box=NONE'
                : 'area=${box.areaRatio.toStringAsFixed(3)} '
                    'centerX=${box.centerX.toStringAsFixed(2)} '
                    'centerY=${box.centerY.toStringAsFixed(2)} '
                    'x1=${box.x1.toStringAsFixed(2)} '
                    'y1=${box.y1.toStringAsFixed(2)} '
                    'x2=${box.x2.toStringAsFixed(2)} '
                    'y2=${box.y2.toStringAsFixed(2)}';

            debugPrint(
              '[GUIDANCE_DEBUG] '
              'status=${result.status.name} | '
              'confidence=${result.confidence.toStringAsFixed(2)} | '
              'boxes=${result.boxes.length} | '
              '$boxInfo',
            );
          }
        }

        // 3. AUTO FLASH: Kiểm tra môi trường thiếu sáng.
        // Điều khiển tự bật/tắt flash theo độ sáng.
// Debug tạm thời: kiểm tra dữ liệu đưa vào Auto Flash.
        debugPrint(
          '[FLASH_CHECK] lux=$_currentLux | '
          'torch=${camera.isTorchEnabled} | '
          'status=${result.status.name}',
        );
        final skipResult = await _handleAutoFlash(result);

        if (skipResult) {
          return;
        }

// Nếu flash đang bật và ảnh vẫn quá sáng,
// diễn đạt rõ vấn đề để người dùng dễ điều chỉnh.
        final effectiveResult =
            camera.isTorchEnabled && result.status == DetectionStatus.tooBright
                ? DetectionResult(
                    status: DetectionStatus.tooBright,
                    message: 'Đèn flash làm ảnh quá sáng. '
                        'Hãy đưa tờ tiền ra xa hoặc nghiêng nhẹ.',
                    brightness: result.brightness,
                    inferenceTimeMs: result.inferenceTimeMs,
                    isMock: result.isMock,
                  )
                : result;

        onResult(effectiveResult);

        // 5. Giữ nguyên cơ chế tạm nghỉ sau các cảnh báo.
        if (_needsCorrection(result.status)) {
          if (_lastGuidanceStatus == result.status) {
            _sameGuidanceFrames++;
          } else {
            _lastGuidanceStatus = result.status;
            _sameGuidanceFrames = 1;
          }

          if (_sameGuidanceFrames >= 3) {
            _classificationPauseUntil = DateTime.now().add(
              const Duration(milliseconds: 3500),
            );

            _sameGuidanceFrames = 0;
            _lastGuidanceStatus = null;
          }
        } else {
          _sameGuidanceFrames = 0;
          _lastGuidanceStatus = null;
        }
      } catch (error) {
        onResult(
          DetectionResult.error(
            'Lỗi xử lý khung hình: $error',
          ),
        );
      }
    });
  }

  bool _needsCorrection(DetectionStatus status) => switch (status) {
        DetectionStatus.lowConfidence ||
        DetectionStatus.multipleNotes ||
        DetectionStatus.tooClose ||
        DetectionStatus.tooFar ||
        DetectionStatus.tooDark ||
        DetectionStatus.tooBright =>
          true,
        _ => false,
      };

  Future<bool> _handleAutoFlash(DetectionResult result) async {
    final now = DateTime.now();
    
  final lux = _currentLux;

  // Nếu cảm biến nhận thấy phòng đã sáng, ưu tiên Lux trở lại.
  if (lux != null && lux >= 100) {
    _useCameraLightFallback = false;
  }

  // Nếu flash bật lâu nhưng Lux vẫn rất thấp,
  // chuyển sang kiểm tra ánh sáng bằng camera.
  if (!_useCameraLightFallback &&
      camera.isTorchEnabled &&
      _torchStartedAt != null &&
      now.difference(_torchStartedAt!) >=
          const Duration(seconds: 5) &&
      (lux == null || lux < 100)) {
    _useCameraLightFallback = true;

    // Chuẩn bị kiểm tra ánh sáng phòng sau 2 giây.
    _nextLightProbeAt = now.add(
      const Duration(seconds: 2),
    );

    debugPrint(
      '[AUTO_FLASH] Lux không đủ để quyết định tắt đèn. '
      'Chuyển sang kiểm tra bằng camera.',
    );
  }




    if (lux != null && !_useCameraLightFallback) {
      // Không sử dụng cơ chế tắt flash 15 giây để thử sáng nữa.
      _lightProbeActive = false;
      _lightProbeStartedAt = null;
      _brightProbeFrames = 0;
      _nextLightProbeAt = null;

      // TRƯỜNG HỢP A: Flash đang bật.
      if (camera.isTorchEnabled) {
        // Ngưỡng thử nghiệm: từ 100 lux trở lên được xem là
        // môi trường đã đủ sáng để thử tắt flash.
        if (lux >= 100) {
          _luxBrightSince ??= now;

          // Chỉ tắt khi ánh sáng đủ cao trong ít nhất 1,2 giây.
          if (now.difference(_luxBrightSince!) >=
              const Duration(milliseconds: 1200)) {
            final success = await camera.setTorchEnabled(false);

            if (success) {
              debugPrint(
                '[AUTO_FLASH] Phòng đủ sáng ($lux lx), '
                'tự tắt flash',
              );

              _luxBrightSince = null;
              _torchStartedAt = null;
              _flashAttempted = false;
              _consecutiveDarkFrames = 0;

              // Reset trạng thái cảnh báo của backend.
              _classificationPauseUntil = null;
              _sameGuidanceFrames = 0;
              _lastGuidanceStatus = null;

              // Không dùng kết quả frame vừa chụp với flash.
              return true;
            }
          }
        } else {
          // Lux giảm trở lại thì phải xác nhận từ đầu.
          _luxBrightSince = null;
        }

        // Camera cần thời gian tự điều chỉnh phơi sáng
        // sau khi đèn vừa bật.
        if (result.status == DetectionStatus.tooBright &&
            _torchStartedAt != null &&
            now.difference(_torchStartedAt!) <
                const Duration(milliseconds: 1200)) {
          debugPrint(
            '[AUTO_FLASH] Chờ camera ổn định ánh sáng',
          );

          return true;
        }

        return false;
      }

      // TRƯỜNG HỢP B: Flash đang tắt.
      _luxBrightSince = null;

      // Kết hợp cảnh báo tối của camera với Lux.
      if (result.status == DetectionStatus.tooDark && lux < 60) {
        _consecutiveDarkFrames++;

        if (_consecutiveDarkFrames >= 3 && !_flashAttempted) {
          _flashAttempted = true;

          final enabled = await camera.setTorchEnabled(true);

          if (enabled) {
            _torchStartedAt = DateTime.now();
            _consecutiveDarkFrames = 0;

            _classificationPauseUntil = null;
            _sameGuidanceFrames = 0;
            _lastGuidanceStatus = null;

            debugPrint(
              '[AUTO_FLASH] Phòng tối ($lux lx), tự bật flash',
            );

            // Bỏ qua kết quả cũ để xử lý frame có flash.
            return true;
          }

          debugPrint('[AUTO_FLASH] Không bật được flash');
        }
      } else {
        _consecutiveDarkFrames = 0;
      }

      return false;
    }

// Nếu chưa có dữ liệu Lux, phần xử lý
// kiểm tra ánh sáng bằng camera cũ bên dưới vẫn chạy.

    // 1. Đang kiểm tra ánh sáng phòng khi flash tạm tắt.
    if (_lightProbeActive) {
      // Không che giấu lỗi model.
      if (result.status == DetectionStatus.modelError) {
        _lightProbeActive = false;
        return false;
      }

      final startedAt = _lightProbeStartedAt!;

      // Chờ camera tự điều chỉnh độ phơi sáng.
      if (now.difference(startedAt) < const Duration(milliseconds: 900)) {
        return true;
      }

      final brightness = result.brightness;

      // Chỉ xác nhận đủ sáng khi có 2 frame liên tiếp.
      if (brightness != null && brightness.isFinite && brightness >= 55.0) {
        _brightProbeFrames++;
      } else {
        _brightProbeFrames = 0;
      }

      if (kDebugMode) {
        debugPrint(
          '[AUTO_FLASH] Đo ánh sáng phòng: '
          '${brightness?.toStringAsFixed(1) ?? "không có dữ liệu"}',
        );
      }

      if (_brightProbeFrames >= 2) {
        // Phòng đã đủ sáng, giữ flash tắt.
        _lightProbeActive = false;
        _lightProbeStartedAt = null;
        _nextLightProbeAt = null;
        _brightProbeFrames = 0;
        _consecutiveDarkFrames = 0;
        _flashAttempted = false;
        _classificationPauseUntil = null;

        debugPrint('[AUTO_FLASH] Đủ sáng, flash tự tắt');
        return true;
      }

      // Nếu vẫn tối hoặc chưa đo được đủ sáng sau 3 giây,
      // bật lại flash để tiếp tục hỗ trợ nhận diện.
      if (now.difference(startedAt) >= const Duration(seconds: 3)) {
        final restored = await camera.setTorchEnabled(true);
        if (restored) {
          _torchStartedAt = DateTime.now();
        }

        _lightProbeActive = false;
        _lightProbeStartedAt = null;
        _brightProbeFrames = 0;
        _consecutiveDarkFrames = 0;
        _flashAttempted = restored;

        _nextLightProbeAt = DateTime.now().add(
          const Duration(seconds: 15),
        );

        debugPrint(
          restored
              ? '[AUTO_FLASH] Vẫn thiếu sáng, bật lại flash'
              : '[AUTO_FLASH] Không bật lại được flash',
        );
      }

      return true;
    }

    // 2. Flash đang bật: đến hạn thì tạm tắt để đo sáng.
    if (camera.isTorchEnabled) {
      if (_nextLightProbeAt != null && !now.isBefore(_nextLightProbeAt!)) {
        final switchedOff = await camera.setTorchEnabled(false);

        if (switchedOff) {
          _lightProbeActive = true;
          _lightProbeStartedAt = DateTime.now();
          _brightProbeFrames = 0;

          // Bỏ thời gian nghỉ cũ để kiểm tra ánh sáng.
          _classificationPauseUntil = null;
          _sameGuidanceFrames = 0;
          _lastGuidanceStatus = null;

          debugPrint(
            '[AUTO_FLASH] Tạm tắt flash để kiểm tra ánh sáng',
          );
        } else {
          _nextLightProbeAt = DateTime.now().add(
            const Duration(seconds: 15),
          );
        }

        return true;
      }

      return false;
    }

    // 3. Flash đang tắt: tự bật khi thiếu sáng liên tiếp.
    if (result.status == DetectionStatus.tooDark) {
      _consecutiveDarkFrames++;

      if (_consecutiveDarkFrames >= 3 && !_flashAttempted) {
        _flashAttempted = true;

        final enabled = await camera.setTorchEnabled(true);

        if (enabled) {
          _torchStartedAt = DateTime.now();
          _consecutiveDarkFrames = 0;
          _classificationPauseUntil = null;
          _sameGuidanceFrames = 0;
          _lastGuidanceStatus = null;

          // Sau 15 giây sẽ kiểm tra xem phòng đã sáng chưa.
          _nextLightProbeAt = DateTime.now().add(
            const Duration(seconds: 15),
          );

          debugPrint('[AUTO_FLASH] Thiếu sáng, tự bật flash');
          return true;
        }

        debugPrint(
          '[AUTO_FLASH] Không bật được flash, '
          'tiếp tục hướng dẫn người dùng',
        );
      }
    } else {
      _consecutiveDarkFrames = 0;
    }

    return false;
  }

  @override
  Future<void> stop({bool releaseCamera = false}) async {
    _useCameraLightFallback = false;
    await _luxSubscription?.cancel();
    _luxSubscription = null;
    _currentLux = null;
    _luxBrightSince = null;
    _torchStartedAt = null;

    if (_errorListener != null)
      _listenedCamera?.removeListener(_errorListener!);
    _listenedCamera = null;
    _errorListener = null;
    try {
      await camera.stopStream();
    } finally {
      if (releaseCamera) await camera.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await stop(releaseCamera: true);
    } finally {
      await detector.dispose();
    }
  }
}
