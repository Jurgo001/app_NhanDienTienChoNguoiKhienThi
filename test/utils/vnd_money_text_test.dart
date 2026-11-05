import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/utils/vnd_money_text.dart';

void main() {
  test('Đọc tổng tiền bằng tiếng Việt', () {
    expect(VndMoneyText.spoken(0), 'không đồng');
    expect(VndMoneyText.spoken(50000), 'năm mươi nghìn đồng');
    expect(VndMoneyText.spoken(150000), 'một trăm năm mươi nghìn đồng');
    expect(VndMoneyText.spoken(105000), 'một trăm linh năm nghìn đồng');
    expect(VndMoneyText.spoken(1001000),
        'một triệu không trăm linh một nghìn đồng');
    expect(VndMoneyText.digits(170000), '170.000');
  });
}
