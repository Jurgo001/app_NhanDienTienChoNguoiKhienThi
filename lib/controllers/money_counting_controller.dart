import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';
import '../models/denomination.dart';
import '../utils/vnd_money_text.dart';

/// Quản lý tổng tiền và lưu trạng thái phiên đếm vào máy.
class MoneyCountingController extends ChangeNotifier {
  MoneyCountingController({SettingsService? storage, this.onStorageError})
      : _storage = storage ?? SettingsService();

  final SettingsService _storage;
  final void Function(Object error)? onStorageError;
  Future<void> _writes = Future<void>.value();
  bool _restored = false;

  Future<void> initialize() async {
    if (_restored) return;
    final saved = await _storage.loadCountingSession();
    _totalVnd = saved.totalVnd;
    _noteCount = saved.noteCount;
    _restored = true;
    notifyListeners();
  }

  // Snapshots are serialized, so rapid additions and a subsequent reset
  // cannot be written out of order on Android.
  void _persistSnapshot() {
    if (!_restored) return; // A failed restore must never erase saved data.
    final total = _totalVnd;
    final count = _noteCount;
    _writes = _writes
        .then((_) => _storage.saveCountingSession(total, count))
        .catchError((Object error, StackTrace stack) {
      debugPrint('[COUNT_SAVE_ERROR] $error\n$stack');
      onStorageError?.call(error);
    });
  }

  Future<void> flush() => _writes;

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
    _persistSnapshot();
    return '${denomination.spokenText}. Tổng hiện tại $totalSpeech.';
  }

  /// Người dùng phải chủ động xác nhận tạo phiên mới từ hộp thoại chuyển chế độ.
  void startNewSession() {
    _totalVnd = 0;
    _noteCount = 0;
    notifyListeners();
    _persistSnapshot();
  }
}
