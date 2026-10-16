import 'scan_backend.dart';
import 'scan_backend_web.dart' if (dart.library.io) 'scan_backend_native.dart'
    as platform;

ScanBackend createScanBackend() => platform.createScanBackend();
