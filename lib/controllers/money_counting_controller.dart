import 'package:flutter/foundation.dart';
import '../models/denomination.dart';
import '../utils/vnd_money_text.dart';

/// Chỉ giữ tổng và số tờ trong bộ nhớ phiên ứng dụng.
class MoneyCountingController extends ChangeNotifier {
  int _totalVnd = 0;
  int _noteCount = 0;

  int get totalVnd => _totalVnd;
  int get noteCount => _noteCount;
  bool get hasCounted => _noteCount > 0;
  String get totalDisplay => '${VndMoneyText.digits(_totalVnd)} đồng';
  String get totalSpeech => VndMoneyText.spoken(_totalVnd);

  /// Chỉ RecognitionController gọi hàm này sau khi đủ 3 frame ổn định.
  String recordStableRecognition(Denomination denomination) {
    _totalVnd += denomination.value;
    _noteCount++;
    notifyListeners();
    return '${denomination.spokenText}. Tổng hiện tại $totalSpeech.';
  }

  /// Người dùng phải chủ động xác nhận tạo phiên mới từ hộp thoại chuyển chế độ.
  void startNewSession() {
    _totalVnd = 0;
    _noteCount = 0;
    notifyListeners();
  }
}
