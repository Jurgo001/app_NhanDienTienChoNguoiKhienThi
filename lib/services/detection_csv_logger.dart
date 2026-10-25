
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/detection_result.dart';

class DetectionCsvLogger {
  final List<String> _rows = [];

  int get count => _rows.length;

  static const String _header =
      'timestamp,model,class_id,label,denomination_vnd,'
      'side,confidence,processing_ms,status,box_count';

  String _escape(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  void add(
    DetectionResult result, {
    required String modelName,
  }) {
    if (result.status == DetectionStatus.skippedBusy ||
        result.isMock) {
      return;
    }

    if (result.boxes.isEmpty) {
      _append([
        result.timestamp.toIso8601String(),
        modelName,
        '',
        '',
        result.denomination?.value ?? '',
        result.side.name,
        result.confidence,
        result.inferenceTimeMs,
        result.status.name,
        0,
      ]);
      return;
    }

    for (final box in result.boxes) {
      _append([
        result.timestamp.toIso8601String(),
        modelName,
        box.classId,
        box.rawLabel,
        box.denomination?.value ?? '',
        box.side.name,
        box.confidence,
        result.inferenceTimeMs,
        result.status.name,
        result.boxes.length,
      ]);
    }
  }

  void _append(List<Object?> values) {
    if (_rows.length >= 10000) return;
    _rows.add(values.map(_escape).join(','));
  }

  void clear() {
    _rows.clear();
  }

  Future<void> exportCsv() async {
    if (_rows.isEmpty) {
      throw StateError('Chưa có dữ liệu để xuất.');
    }

    final directory = await getTemporaryDirectory();

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');

    final file = File(
      '${directory.path}/ai_detection_$timestamp.csv',
    );

    final content =
        '\uFEFF$_header\n${_rows.join('\n')}\n';

    await file.writeAsString(content, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Dữ liệu kiểm thử AI nhận diện tiền Việt Nam',
    );
  }
}
