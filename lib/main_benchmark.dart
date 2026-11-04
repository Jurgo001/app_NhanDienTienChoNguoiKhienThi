import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart' as cp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'services/money_detector.dart';
import 'models/detection_result.dart';

const _label =
    String.fromEnvironment('BENCHMARK_LABEL', defaultValue: 'manual');
const _runId =
    String.fromEnvironment('BENCHMARK_RUN_ID', defaultValue: 'manual');

CameraImage _fixture() {
  const width = 640, height = 480;
  return CameraImage.fromPlatformInterface(cp.CameraImageData(
    format: const cp.CameraImageFormat(cp.ImageFormatGroup.yuv420, raw: 35),
    width: width,
    height: height,
    planes: [
      cp.CameraImagePlane(
        bytes: Uint8List.fromList(List.generate(
            width * height, (i) => 80 + ((i % width + i ~/ width) % 100))),
        bytesPerRow: width,
        bytesPerPixel: 1,
      ),
      cp.CameraImagePlane(
        bytes: Uint8List.fromList(List.filled(width * height ~/ 4, 128)),
        bytesPerRow: width ~/ 2,
        bytesPerPixel: 1,
      ),
      cp.CameraImagePlane(
        bytes: Uint8List.fromList(List.filled(width * height ~/ 4, 128)),
        bytesPerRow: width ~/ 2,
        bytesPerPixel: 1,
      ),
    ],
  ));
}

double _percentile(List<double> values, double quantile) {
  final sorted = [...values]..sort();
  return sorted[(quantile * sorted.length).ceil().clamp(1, sorted.length) - 1];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
        body: Center(child: Text('Đang đo hiệu năng với ảnh cố định…'))),
  ));
  final detector = MoneyDetector();
  try {
    final frame = _fixture();
    final loading = Stopwatch()..start();
    await detector.initialize();
    final initializeMs = loading.elapsedMicroseconds / 1000;
    for (var i = 0; i < 5; i++) {
      final warmup =
          await detector.detectFrame(frame, sensorOrientation: i % 4 * 90);
      if (warmup.status == DetectionStatus.modelError) {
        throw StateError(warmup.message ?? 'Inference failed');
      }
    }
    final rounds = <Map<String, Object?>>[];
    final signatures = <Map<String, Object?>>[];
    for (var round = 0; round < 3; round++) {
      final times = <double>[];
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        final clock = Stopwatch()..start();
        final result =
            await detector.detectFrame(frame, sensorOrientation: i % 4 * 90);
        times.add(clock.elapsedMicroseconds / 1000);
        if (result.status == DetectionStatus.modelError ||
            result.status == DetectionStatus.skippedBusy) {
          throw StateError(result.message ?? result.status.name);
        }
        signatures.add({
          'rotation': i % 4 * 90,
          'status': result.status.name,
          'confidence': result.confidence.toStringAsFixed(6),
          'brightness': result.brightness?.toStringAsFixed(6),
          'boxes': [
            for (final b in result.boxes)
              [b.classId, b.x1, b.y1, b.x2, b.y2, b.confidence]
                  .map((v) => v.toStringAsFixed(6))
                  .toList()
          ],
        });
      }
      rounds.add({
        'round': round + 1,
        'samples': times,
        'median_ms': _percentile(times, .5),
        'p95_ms': _percentile(times, .95),
        'rss_bytes': ProcessInfo.currentRss,
      });
    }
    final output = {
      'label': _label,
      'run_id': _runId,
      'captured_at_utc': DateTime.now().toUtc().toIso8601String(),
      'mode': kReleaseMode
          ? 'release'
          : kProfileMode
              ? 'profile'
              : 'debug',
      'platform': Platform.operatingSystem,
      'fixture': 'deterministic YUV420 640x480; Y=80+((x+y)%100), U=V=128',
      'warmup_frames': 5,
      'rounds': rounds,
      'model': detector.modelInfo,
      'initialize_ms': initializeMs,
      'signatures': signatures,
      'limitations':
          'Synthetic fixture; not an accuracy, camera, TTS or battery benchmark.',
    };
    await detector.dispose();
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/benchmark_${_label}_$_runId.json';
    await File(path).writeAsString(jsonEncode(output), flush: true);
    // ignore: avoid_print
    print('BENCHMARK_SAVED $path');
    runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Đã lưu kết quả đo hiệu năng.'))),
    ));
  } catch (error, stack) {
    await detector.dispose();
    // ignore: avoid_print
    print('BENCHMARK_ERROR $error\n$stack');
    runApp(MaterialApp(
      home: Scaffold(body: Center(child: Text('Không đo được: $error'))),
    ));
  }
}
