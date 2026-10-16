import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/denomination_mapper.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/model_contract.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/yolo_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Asset TFLite và metadata có đủ 18 nhãn đúng thứ tự', () {
    final bytes = File('assets/models/best_float32.tflite').readAsBytesSync();
    expect(ascii.decode(bytes.sublist(4, 8)), 'TFL3');
    final archive = ZipDecoder().decodeBytes(bytes);
    final metadata = archive.findFile('metadata.json')!;
    final json = jsonDecode(utf8.decode(metadata.content)) as Map;
    final names = json['names'] as Map;
    expect([for (var i = 0; i < 18; i++) names['$i']],
        DenominationMapper.classLabels);
  });
  test('Chấp nhận model hiện tại, từ chối sai kênh hoặc sai batch', () {
    ModelContract.validate([1, 3, 416, 416], [1, 22, 3549]);
    ModelContract.validate([1, 416, 416, 3], [1, 3549, 22]);
    expect(() => ModelContract.validate([2, 3, 416, 416], [1, 22, 3549]),
        throwsStateError);
    expect(() => ModelContract.validate([1, 3, 416, 416], [1, 84, 3549]),
        throwsStateError);
  });
  test('Output thiếu dữ liệu và NaN không trở thành kết quả nhận diện', () {
    expect(
        YoloDecoder.decodeOutput(
            flatOutput: [0], outputShape: [1, 22, 30], inputSize: 416),
        isEmpty);
    final data = List<double>.filled(22, 0);
    data[0] = double.nan;
    data[1] = .5;
    data[2] = .5;
    data[3] = .5;
    data[4] = .99;
    expect(
        YoloDecoder.decodeOutput(
            flatOutput: data, outputShape: [1, 22, 1], inputSize: 416),
        isEmpty);
  });
}
