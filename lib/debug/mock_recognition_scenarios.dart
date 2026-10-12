import '../core/constants/app_strings.dart';
import '../core/models/recognition_ui_state.dart';

/// Dữ liệu giả chỉ phục vụ kiểm tra giao diện ở bản debug.
abstract final class MockRecognitionScenarios {
  static const recognized = RecognitionUiState(
    status: RecognitionUiStatus.recognized,
    denomination: AppStrings.mockDenomination,
  );

  static const unclear = RecognitionUiState(
    status: RecognitionUiStatus.unclear,
  );

  static const error = RecognitionUiState(
    status: RecognitionUiStatus.error,
  );
}
