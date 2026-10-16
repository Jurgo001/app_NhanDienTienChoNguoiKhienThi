import 'dart:async';

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart' as cp;
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:app_ho_tro_nguoi_khiem_thi/controllers/recognition_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/settings_controller.dart';

import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/camera_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/haptic_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/settings_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/denomination_mapper.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/image_converter.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/nms.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/yolo_decoder.dart';

class AuditSpeech extends SpeechService {
  int count = 0;
  Completer<void>? stopGate;
  @override
  Future<void> speak(String text,
      {SpeechRateOption rate = SpeechRateOption.normal}) async {
    count++;
  }

  @override
  Future<void> stop() async {
    if (stopGate != null) await stopGate!.future;
  }
}

class AuditHaptic extends HapticService {
  int count = 0;
  @override
  Future<void> vibrateSuccess() async {
    count++;
  }

  @override
  Future<void> vibrateError() async {}
}

class GrantedCamera extends CameraService {
  @override
  Future<bool> requestCameraPermission() async => true;
}

class AuditCameraPlatform extends cp.CameraPlatform {
  int creations = 0;
  final errors = StreamController<cp.CameraErrorEvent>.broadcast();
  final orientations =
      StreamController<cp.DeviceOrientationChangedEvent>.broadcast();
  final frames = StreamController<cp.CameraImageData>.broadcast();
  @override
  Future<List<cp.CameraDescription>> availableCameras() async => [
        const cp.CameraDescription(
            name: 'audit',
            lensDirection: cp.CameraLensDirection.back,
            sensorOrientation: 90),
      ];
  @override
  Future<int> createCamera(
          cp.CameraDescription description, cp.ResolutionPreset? preset,
          {bool enableAudio = false}) async =>
      ++creations;
  @override
  Future<void> initializeCamera(int id,
      {cp.ImageFormatGroup imageFormatGroup =
          cp.ImageFormatGroup.unknown}) async {}
  @override
  Stream<cp.CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(
        cp.CameraInitializedEvent(
            id, 640, 480, cp.ExposureMode.auto, true, cp.FocusMode.auto, true),
      );
  @override
  Stream<cp.CameraErrorEvent> onCameraError(int id) => errors.stream;
  @override
  Stream<cp.DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      orientations.stream;
  @override
  Stream<cp.CameraImageData> onStreamedFrameAvailable(int id,
          {cp.CameraImageStreamOptions? options}) =>
      frames.stream;
  @override
  Future<void> dispose(int id) async {}
}

DetectionResult valid() => DetectionResult(
      status: DetectionStatus.detected,
      denomination: Denomination.vnd100000,
      confidence: .95,
      isMock: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuditSpeech speech;
  late AuditHaptic haptic;
  late RecognitionController controller;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    speech = AuditSpeech();
    haptic = AuditHaptic();
    controller = RecognitionController(
        speechService: speech,
        hapticService: haptic,
        getSettings: () => const AppSettings());
  });
  tearDown(() {
    controller.dispose();
  });

  test('decoder supports both layouts and every model class', () {
    for (var classId = 0; classId < 18; classId++) {
      for (final channelsFirst in [true, false]) {
        const anchors = 30, channels = 22;
        final values = Float32List(anchors * channels);
        int pos(int channel) => channelsFirst ? channel * anchors : channel;
        values[pos(0)] = .5;
        values[pos(1)] = .5;
        values[pos(2)] = .6;
        values[pos(3)] = .4;
        values[pos(4 + classId)] = .95;
        final boxes = YoloDecoder.decodeOutput(
          flatOutput: values,
          outputShape:
              channelsFirst ? [1, channels, anchors] : [1, anchors, channels],
          inputSize: 416,
        );
        expect(boxes, hasLength(1));
        expect(boxes.single.denomination,
            DenominationMapper.fromClassId(classId)!.denomination);
        expect(
            boxes.single.side, DenominationMapper.fromClassId(classId)!.side);
      }
    }
  });

  test('empty decoder output has no detections', () {
    expect(
        YoloDecoder.decodeOutput(
            flatOutput: Float32List(22 * 30),
            outputShape: [1, 22, 30],
            inputSize: 416),
        isEmpty);
  });

  test('NMS removes duplicates while preserving separate notes', () {
    const a = BoundingBox(
        x1: .05,
        y1: .05,
        x2: .45,
        y2: .45,
        classId: 0,
        rawLabel: 'a',
        confidence: .95);
    const duplicate = BoundingBox(
        x1: .06,
        y1: .06,
        x2: .46,
        y2: .46,
        classId: 1,
        rawLabel: 'b',
        confidence: .9);
    const separate = BoundingBox(
        x1: .55,
        y1: .55,
        x2: .95,
        y2: .95,
        classId: 2,
        rawLabel: 'c',
        confidence: .85);
    expect(NmsUtils.applyNMS([a, duplicate, separate]), hasLength(2));
  });

  test('3 real stable frames confirm once and trigger feedback', () {
    controller.startScanning();
    for (var i = 0; i < 8; i++) {
      controller.processDetection(valid());
    }
    expect(controller.state.status, RecognitionUiStatus.recognized);
    expect(controller.state.isMock, isFalse);
    expect(speech.count, 1);
    expect(haptic.count, 1);
  });

  test('skippedBusy must not erase two stable frames', () {
    controller.startScanning();
    controller.processDetection(valid());
    controller.processDetection(valid());
    controller
        .processDetection(DetectionResult(status: DetectionStatus.skippedBusy));
    controller.processDetection(valid());
    expect(controller.state.status, RecognitionUiStatus.recognized);
  });

  test('noMoney must replace stale tooDark guidance', () {
    controller.startScanning();
    controller.processDetection(
        DetectionResult(status: DetectionStatus.tooDark, message: 'tooDark'));
    final empty = DetectionResult.empty();
    controller.processDetection(empty);
    expect(controller.state.guidance, empty.message);
  });

  test('reset must clear recognized UI before awaiting TTS stop', () async {
    controller.startScanning();
    for (var i = 0; i < 3; i++) {
      controller.processDetection(valid());
    }
    speech.stopGate = Completer<void>();
    final resetting = controller.resetScan();
    final stillShowsResult = controller.state.hasResult;
    speech.stopGate!.complete();
    await resetting;
    expect(stillShowsResult, isFalse);
  });

  test('settings persist across service instances', () async {
    final settings = const AppSettings(
        autoReadEnabled: false,
        vibrationEnabled: false,
        speechRate: SpeechRateOption.fast);
    await SettingsService().saveSettings(settings);
    final loaded = await SettingsService().loadSettings();
    expect(loaded.autoReadEnabled, isFalse);
    expect(loaded.vibrationEnabled, isFalse);
    expect(loaded.speechRate, SpeechRateOption.fast);
  });

  test('concurrent settings changes must preserve both toggles', () async {
    final settingsController = SettingsController(SettingsService());
    await settingsController.initialize();
    await Future.wait([
      settingsController.setAutoRead(false),
      settingsController.setVibration(false)
    ]);
    final autoRead = settingsController.settings.autoReadEnabled;
    final vibration = settingsController.settings.vibrationEnabled;
    settingsController.dispose();
    expect(autoRead, isFalse);
    expect(vibration, isFalse);
  });

  test('camera must initialize again after inactive then resumed', () async {
    final original = cp.CameraPlatform.instance;
    final platform = AuditCameraPlatform();
    cp.CameraPlatform.instance = platform;
    final camera = GrantedCamera();
    try {
      await camera.initializeCamera();
      expect(camera.isInitialized, isTrue);
      await camera.handleAppLifecycleState(AppLifecycleState.inactive);
      expect(camera.isInitialized, isFalse);
      await camera.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(camera.isInitialized, isTrue);
      expect(platform.creations, 2);
    } finally {
      await camera.dispose();
      cp.CameraPlatform.instance = original;
    }
  });

  test('conversion at equal resolution must preserve different pixels', () {
    final image = CameraImage.fromPlatformInterface(cp.CameraImageData(
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
              255,
            ]),
            bytesPerRow: 8,
            bytesPerPixel: 4)
      ],
    ));
    final converted = ImageConverter.convertCameraImage(
        cameraImage: image,
        sensorOrientation: 0,
        targetSize: 2,
        isChannelsFirst: false);
    expect(converted.inputBuffer.toList(),
        [1.0, 0, 0, 0, 1.0, 0, 0, 0, 1.0, 1.0, 1.0, 1.0]);
  });
}
