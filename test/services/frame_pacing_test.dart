import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/frame_pacing.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/models/detection_result.dart';

void main() {
  test('Idle backoff resets as soon as a note is detected', () {
    final pacing = FramePacing()..reset();
    expect(pacing.update(DetectionStatus.noMoney), 120);
    expect(pacing.update(DetectionStatus.noMoney), 120);
    expect(pacing.update(DetectionStatus.noMoney), 300);
    expect(pacing.update(DetectionStatus.detected), 120);
  });
  test('Guidance backoff keeps scanning rather than pausing for 3.5 seconds',
      () {
    final pacing = FramePacing()..reset();
    for (var i = 0; i < 3; i++) {
      pacing.update(DetectionStatus.tooFar);
    }
    expect(pacing.intervalMs, 240);
    expect(pacing.update(DetectionStatus.detected), 120);
  });
  test('Locked result is paced until the next turn starts', () {
    final pacing = FramePacing()..reset();
    pacing.setLocked(true);
    for (var i = 0; i < 4; i++) {
      pacing.update(DetectionStatus.noMoney);
    }
    expect(pacing.intervalMs, 240);
    pacing.setLocked(false);
    expect(pacing.intervalMs, 120);
  });
  test('A custom camera minimum is never exceeded', () {
    final pacing = FramePacing(activeIntervalMs: 500)..reset();
    for (var i = 0; i < 3; i++) {
      pacing.update(DetectionStatus.noMoney);
    }
    expect(pacing.intervalMs, 500);
    pacing.setLocked(true);
    expect(pacing.intervalMs, 500);
  });
}
