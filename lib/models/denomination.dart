/// Mặt của tờ tiền được nhận diện từ model YOLO.
enum BanknoteSide {
  front('Mặt trước'),
  back('Mặt sau'),
  unknown('Không rõ mặt');

  final String label;
  const BanknoteSide(this.label);
}

/// Tập 9 mệnh giá tiền Việt Nam hỗ trợ nhận diện.
enum Denomination {
  vnd1000(
    value: 1000,
    displayText: '1.000 VNĐ',
    spokenText: 'Một nghìn đồng',
    shortLabel: '1.000đ',
  ),
  vnd2000(
    value: 2000,
    displayText: '2.000 VNĐ',
    spokenText: 'Hai nghìn đồng',
    shortLabel: '2.000đ',
  ),
  vnd5000(
    value: 5000,
    displayText: '5.000 VNĐ',
    spokenText: 'Năm nghìn đồng',
    shortLabel: '5.000đ',
  ),
  vnd10000(
    value: 10000,
    displayText: '10.000 VNĐ',
    spokenText: 'Mười nghìn đồng',
    shortLabel: '10.000đ',
  ),
  vnd20000(
    value: 20000,
    displayText: '20.000 VNĐ',
    spokenText: 'Hai mươi nghìn đồng',
    shortLabel: '20.000đ',
  ),
  vnd50000(
    value: 50000,
    displayText: '50.000 VNĐ',
    spokenText: 'Năm mươi nghìn đồng',
    shortLabel: '50.000đ',
  ),
  vnd100000(
    value: 100000,
    displayText: '100.000 VNĐ',
    spokenText: 'Một trăm nghìn đồng',
    shortLabel: '100.000đ',
  ),
  vnd200000(
    value: 200000,
    displayText: '200.000 VNĐ',
    spokenText: 'Hai trăm nghìn đồng',
    shortLabel: '200.000đ',
  ),
  vnd500000(
    value: 500000,
    displayText: '500.000 VNĐ',
    spokenText: 'Năm trăm nghìn đồng',
    shortLabel: '500.000đ',
  );

  /// Giá trị số nguyên của mệnh giá (ví dụ: 50000).
  final int value;

  /// Chuỗi hiển thị chuẩn trên giao diện (ví dụ: "50.000 VNĐ").
  final String displayText;

  /// Chuỗi phát âm chuẩn cho Text-To-Speech (ví dụ: "Năm mươi nghìn đồng").
  final String spokenText;

  /// Nhãn ngắn gọn phục vụ debug hoặc thẻ nhỏ.
  final String shortLabel;

  const Denomination({
    required this.value,
    required this.displayText,
    required this.spokenText,
    required this.shortLabel,
  });

  /// Tìm mệnh giá từ giá trị số nguyên (trả về null nếu không khớp).
  static Denomination? fromValue(int value) {
    for (final item in Denomination.values) {
      if (item.value == value) return item;
    }
    return null;
  }
}