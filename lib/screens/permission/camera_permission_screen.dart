import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/scan_backend.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/mobile_page.dart';

class CameraPermissionScreen extends StatefulWidget {
  const CameraPermissionScreen({
    super.key,
    required this.backend,
    required this.onContinue,
  });
  final ScanBackend backend;
  final VoidCallback onContinue;
  @override
  State<CameraPermissionScreen> createState() => _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen>
    with WidgetsBindingObserver {
  CameraAccess? _access;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_check());
  }

  Future<void> _check({bool request = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final access = await widget.backend.permission(request: request);
      if (mounted) setState(() => _access = access);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    try {
      await widget.backend.openPermissionSettings();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final mock = widget.backend.isMock;
    final granted = _access == CameraAccess.granted;
    final blocked = _access == CameraAccess.permanentlyDenied;
    final message = mock
        ? 'Chrome dùng kết quả mô phỏng để thử giao diện và giọng nói. '
            'Chạy trên Android để nhận diện qua camera.'
        : granted
            ? 'Đã được cấp quyền camera. Về nhận diện và bấm Bắt đầu quét.'
            : blocked
                ? 'Camera đang bị chặn. Mở cài đặt ứng dụng để cấp lại quyền camera.'
                : 'Ứng dụng dùng camera sau để nhận diện một tờ tiền. '
                    'Ảnh được xử lý trên điện thoại, không gửi lên máy chủ. '
                    'Android sẽ hiển thị hộp thoại cấp quyền.';
    return MobilePage(
      background: const Color(0xFFE1E7ED),
      backLabel: 'Về nhận diện',
      children: [
        Semantics(
            header: true,
            child: Text(
              'Quyền camera',
              style: Theme.of(context).textTheme.headlineMedium,
            )),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.photo_camera_outlined,
                size: 40, color: AppColors.navy),
            const SizedBox(height: 20),
            Semantics(
                liveRegion: true,
                child: Text(
                  _error ?? message,
                  style: const TextStyle(fontSize: 18, height: 1.5),
                )),
            const SizedBox(height: 24),
            if (!mock && !granted)
              AccessibleButton(
                key: const Key('grant_camera_button'),
                label: _busy
                    ? 'Đang kiểm tra quyền…'
                    : blocked
                        ? 'Mở cài đặt ứng dụng'
                        : 'Cho phép camera',
                onPressed: _busy
                    ? null
                    : () {
                        if (blocked) {
                          unawaited(_openSettings());
                        } else {
                          unawaited(_check(request: true));
                        }
                      },
              ),
            const SizedBox(height: 12),
            AccessibleButton(
              key: const Key('continue_without_camera_button'),
              label: granted ? 'Về nhận diện' : 'Quay lại',
              primary: false,
              onPressed: widget.onContinue,
            ),
          ]),
        ),
        const Spacer(),
      ],
    );
  }
}
