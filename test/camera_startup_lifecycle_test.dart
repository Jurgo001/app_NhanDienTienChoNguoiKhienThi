import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/app.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/scan_backend.dart';
import 'support/app_fakes.dart';

// Simulates permission_handler returning after Android has sent inactive.
class _DeferredPermissionBackend extends TestBackend {
  final permissionGate = Completer<CameraAccess>();
  int permissionRequests = 0;

  @override
  Future<CameraAccess> permission({bool request = false}) {
    permissionRequests++;
    return permissionGate.future;
  }
}

void main() {
  testWidgets('Quyền trả về khi inactive vẫn mở camera khi resumed',
      (tester) async {
    final backend = _DeferredPermissionBackend();
    await tester.pumpWidget(MoneyRecognitionApp(
      backend: backend,
      speechService: TestSpeech(),
      hapticService: TestHaptic(),
      settingsService: MemorySettings(),
    ));
    await tester.pumpAndSettle();
    expect(backend.permissionRequests, 1);
    expect(backend.initializations, 0);

    // Camera permission dialog or Android focus changes can cause inactive.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    backend.permissionGate.complete(CameraAccess.granted);
    await tester.pumpAndSettle();
    // No camera resources should be acquired while the app is inactive.
    expect(backend.initializations, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backend.initializations, 1);
    expect(backend.callbacks, hasLength(1));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
