import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';

/// Kết quả ánh xạ từ nhãn thô của YOLO sang Mệnh giá và Mặt tờ tiền.
class MappedClassInfo {
  final int classId;
  final String rawLabel;
  final Denomination denomination;
  final BanknoteSide side;

  const MappedClassInfo({
    required this.classId,
    required this.rawLabel,
    required this.denomination,
    required this.side,
  });
}

/// Bộ ánh xạ chuẩn xác theo thứ tự `names` trong file data.yaml (18 classes).
class DenominationMapper {
  DenominationMapper._();

  /// Danh sách 18 nhãn chuẩn theo đúng thứ tự index 0 -> 17 từ data.yaml.
  static const List<String> classLabels = [
    '10000_matsau',   // 0
    '10000_mattruoc', // 1
    '1000_matsau',    // 2
    '1000_mattruoc',  // 3
    '100k_matsau',    // 4
    '100k_mattruoc',  // 5
    '20000_matsau',   // 6
    '20000_mattruoc', // 7
    '2000_matsau',    // 8
    '2000_mattruoc',  // 9
    '200k_matsau',    // 10
    '200k_mattruoc',  // 11
    '50000_matsau',   // 12
    '50000_mattruoc', // 13
    '5000_matsau',    // 14
    '5000_mattruoc',  // 15
    '500k_matsau',    // 16
    '500k_mattruoc',  // 17
  ];

  /// Lấy nhãn gốc từ chỉ số classId.
  static String getRawLabel(int classId) {
    if (classId < 0 || classId >= classLabels.length) {
      return 'unknown_$classId';
    }
    return classLabels[classId];
  }

  /// Ánh xạ từ classId (0..17) sang thông tin mệnh giá và mặt tiền.
  static MappedClassInfo? fromClassId(int classId) {
    if (classId < 0 || classId >= classLabels.length) return null;
    final raw = classLabels[classId];
    return fromRawLabel(raw, classId: classId);
  }

  /// Ánh xạ từ chuỗi nhãn (ví dụ: "100k_mattruoc" hoặc "50000_matsau").
  static MappedClassInfo? fromRawLabel(String rawLabel, {int? classId}) {
    final normalized = rawLabel.trim().toLowerCase();
    final parts = normalized.split('_');
    if (parts.isEmpty) return null;

    final prefix = parts.first;
    final Denomination? denomination = _parsePrefix(prefix);
    if (denomination == null) return null;

    BanknoteSide side = BanknoteSide.unknown;
    if (normalized.contains('mattruoc') || normalized.contains('front')) {
      side = BanknoteSide.front;
    } else if (normalized.contains('matsau') || normalized.contains('back')) {
      side = BanknoteSide.back;
    }

    final resolvedId = classId ?? classLabels.indexOf(rawLabel);

    return MappedClassInfo(
      classId: resolvedId,
      rawLabel: rawLabel,
      denomination: denomination,
      side: side,
    );
  }

  static Denomination? _parsePrefix(String prefix) {
    switch (prefix) {
      case '1000':
      case '1k':
        return Denomination.vnd1000;
      case '2000':
      case '2k':
        return Denomination.vnd2000;
      case '5000':
      case '5k':
        return Denomination.vnd5000;
      case '10000':
      case '10k':
        return Denomination.vnd10000;
      case '20000':
      case '20k':
        return Denomination.vnd20000;
      case '50000':
      case '50k':
        return Denomination.vnd50000;
      case '100000':
      case '100k':
        return Denomination.vnd100000;
      case '200000':
      case '200k':
        return Denomination.vnd200000;
      case '500000':
      case '500k':
        return Denomination.vnd500000;
      default:
        return null;
    }
  }
}