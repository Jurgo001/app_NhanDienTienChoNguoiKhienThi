import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/controllers/money_counting_controller.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/denomination.dart';

void main() {
  test('Cộng ba tờ và đọc tổng tiền', () {
    final count = MoneyCountingController();
    count.recordStableRecognition(Denomination.vnd100000);
    count.recordStableRecognition(Denomination.vnd50000);
    count.recordStableRecognition(Denomination.vnd20000);
    expect(count.totalVnd, 170000);
    expect(count.noteCount, 3);
    expect(count.totalSpeech, 'một trăm bảy mươi nghìn đồng');
    count.dispose();
  });

  test('Đổi chế độ không reset tổng; chỉ phiên mới mới xóa', () {
    final count = MoneyCountingController();
    count.recordStableRecognition(Denomination.vnd500000);
    // Không reset khi người dùng rời chế độ đếm.
    expect(count.totalVnd, 500000);
    count.startNewSession();
    expect(count.totalVnd, 0);
    expect(count.noteCount, 0);
    count.dispose();
  });
}
