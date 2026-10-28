enum RecognitionUiStatus {
  ready,
  scanning,
  recognized,
  lockedAnnounced,
  unclear,
  error,
}

class RecognitionUiState {
  const RecognitionUiState({
    required this.status,
    this.denomination,
    this.spokenDenomination,
    this.guidance,
    this.isMock = true,
  });
  final RecognitionUiStatus status;
  final String? denomination, spokenDenomination, guidance;
  final bool isMock;
  bool get hasResult =>
      (status == RecognitionUiStatus.recognized ||
          status == RecognitionUiStatus.lockedAnnounced) &&
      denomination != null &&
      denomination!.isNotEmpty;
}
