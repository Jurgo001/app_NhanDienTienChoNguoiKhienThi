import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/haptic_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/settings_service.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/speech_service.dart';

class MemorySettings extends SettingsService {
  AppSettings saved = const AppSettings();
  @override
  Future<AppSettings> loadSettings() async => saved;
  @override
  Future<void> saveSettings(AppSettings settings) async {
    saved = settings;
  }
}

class TestSpeech extends SpeechService {
  final spoken = <String>[];
  final rates = <SpeechRateOption>[];
  int stops = 0;
  Object? initializeError;
  @override
  Future<void> initialize() async {
    if (initializeError != null) throw initializeError!;
  }

  @override
  Future<void> speak(String text,
      {SpeechRateOption rate = SpeechRateOption.normal}) async {
    spoken.add(text);
    rates.add(rate);
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class TestHaptic extends HapticService {
  int successes = 0, errors = 0, stops = 0;
  @override
  Future<void> vibrateSuccess() async {
    successes++;
  }

  @override
  Future<void> vibrateError() async {
    errors++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class TestBackend extends ScanBackend {
  TestBackend({this.isMock = false});
  @override
  final bool isMock;
  CameraAccess access = CameraAccess.granted;
  CameraAccess requestedAccess = CameraAccess.granted;
  int initializations = 0,
      stops = 0,
      releases = 0,
      disposals = 0,
      settingsOpened = 0;
  Completer<void>? initializeGate;
  Object? initializeError;
  final callbacks = <DetectionCallback>[];
  @override
  Future<CameraAccess> permission({bool request = false}) async {
    if (request) access = requestedAccess;
    return access;
  }

  @override
  Future<void> openPermissionSettings() async {
    settingsOpened++;
  }

  @override
  Future<void> initialize() async {
    initializations++;
    await initializeGate?.future;
    if (initializeError != null) throw initializeError!;
    if (access != CameraAccess.granted && !isMock) {
      throw StateError('Chưa được cấp quyền camera.');
    }
  }

  @override
  Future<void> start(DetectionCallback onResult) async {
    callbacks.add(onResult);
  }

  @override
  Future<void> stop({bool releaseCamera = false}) async {
    stops++;
    if (releaseCamera) releases++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  void emit(DetectionResult result) => callbacks.last(result);
  void recognize([Denomination denomination = Denomination.vnd100000]) {
    for (var i = 0; i < 3; i++) {
      emit(DetectionResult(
          status: DetectionStatus.detected,
          denomination: denomination,
          confidence: .95,
          isMock: isMock));
    }
  }
}

class AppHarness {
  final backend = TestBackend();
  final speech = TestSpeech();
  final haptic = TestHaptic();
  final settings = MemorySettings();
  MoneyRecognitionApp get app => MoneyRecognitionApp(
        backend: backend,
        speechService: speech,
        hapticService: haptic,
        settingsService: settings,
      );
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  final messenger = find.byType(ScaffoldMessenger);
  if (messenger.evaluate().isNotEmpty) {
    tester
        .state<ScaffoldMessengerState>(messenger.first)
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
