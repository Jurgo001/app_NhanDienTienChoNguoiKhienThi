import 'dart:math' as math;
import '../models/detection_result.dart';

/// Keep normal scans responsive while reducing inference frequency when there
/// is no note, a result is already announced, or guidance remains unchanged.
class FramePacing {
  FramePacing({this.activeIntervalMs = 120});
  final int activeIntervalMs;
  int _emptyFrames = 0, _correctionFrames = 0;
  bool _locked = false;
  int _intervalMs = 0;

  int get intervalMs => _locked
      ? math.max(activeIntervalMs, 240)
      : math.max(activeIntervalMs, _intervalMs);

  void reset({bool locked = false}) {
    _emptyFrames = 0;
    _correctionFrames = 0;
    _intervalMs = activeIntervalMs;
    _locked = locked;
  }

  void setLocked(bool value) {
    if (_locked == value) return;
    reset(locked: value);
  }

  int update(DetectionStatus status) {
    if (status == DetectionStatus.skippedBusy) return intervalMs;
    if (status == DetectionStatus.noMoney) {
      _correctionFrames = 0;
      _emptyFrames++;
      _intervalMs = _emptyFrames >= 3 ? 300 : activeIntervalMs;
    } else if (switch (status) {
      DetectionStatus.lowConfidence ||
      DetectionStatus.multipleNotes ||
      DetectionStatus.tooClose ||
      DetectionStatus.tooFar ||
      DetectionStatus.tooDark ||
      DetectionStatus.tooBright =>
        true,
      _ => false,
    }) {
      _emptyFrames = 0;
      _correctionFrames++;
      _intervalMs = _correctionFrames >= 3 ? 240 : activeIntervalMs;
    } else {
      _emptyFrames = 0;
      _correctionFrames = 0;
      _intervalMs = activeIntervalMs;
    }
    return intervalMs;
  }
}
