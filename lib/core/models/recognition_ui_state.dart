enum RecognitionUiStatus { ready, scanning, recognized, unclear, error }

class RecognitionUiState {
  const RecognitionUiState({
    required this.status,
    this.denomination,
    this.guidance,
    this.isMock = true,
  });

  final RecognitionUiStatus status;
  final String? denomination;
  final String? guidance;
  final bool isMock;

  bool get hasResult =>
      status == RecognitionUiStatus.recognized &&
      denomination != null &&
      denomination!.isNotEmpty;
}
