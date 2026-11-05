import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'controllers/recognition_controller.dart';
import 'services/hardware_volume_shortcuts.dart';
import 'controllers/money_counting_controller.dart';
import 'controllers/scan_session.dart';
import 'controllers/settings_controller.dart';
import 'core/constants/app_strings.dart';
import 'core/models/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'screens/guide/guide_screen.dart';
import 'screens/permission/camera_permission_screen.dart';
import 'screens/recognition/recognition_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/haptic_service.dart';
import 'services/scan_backend.dart';
import 'services/scan_backend_factory.dart';
import 'services/settings_service.dart';
import 'services/speech_service.dart';
import 'widgets/mobile_page.dart';

class MoneyRecognitionApp extends StatefulWidget {
  const MoneyRecognitionApp({
    super.key,
    this.backend,
    this.speechService,
    this.hapticService,
    this.settingsService,
  });
  final ScanBackend? backend;
  final SpeechService? speechService;
  final HapticService? hapticService;
  final SettingsService? settingsService;
  @override
  State<MoneyRecognitionApp> createState() => _MoneyRecognitionAppState();
}

class _MoneyRecognitionAppState extends State<MoneyRecognitionApp>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _permissionRecoveryOpen = false;
  bool _cameraPermissionMissing = false;
  late final SpeechService _speech;
  late final HapticService _haptic;
  late final ScanBackend _backend;
  late final SettingsController _settings;
  late final RecognitionController _recognition;
  late final MoneyCountingController _moneyCounter;
  late final HardwareVolumeShortcuts _volumeShortcuts;
  late final ScanSession _session;
  bool _initialized = false, _foreground = true;
  bool _countingMode = false;
  bool _changingMode = false;
  int _routeDepth = 0;
  String? _serviceNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = widget.speechService ?? SpeechService();
    _haptic = widget.hapticService ?? HapticService();
    _backend = widget.backend ?? createScanBackend();
    _settings = SettingsController(widget.settingsService ?? SettingsService());
    _moneyCounter = MoneyCountingController();
    _volumeShortcuts = HardwareVolumeShortcuts(onAction: _onHardwareHold);
    _volumeShortcuts.register();
    _recognition = RecognitionController(
      speechService: _speech,
      hapticService: _haptic,
      getSettings: () => _settings.settings,
      isMoneyCounting: () => _countingMode,
      onStableDenomination: (denomination) => _countingMode
          ? _moneyCounter.recordStableRecognition(denomination)
          : null,
      onFeedbackError: (error) {
        if (mounted)
          setState(() => _serviceNotice =
              'Phản hồi âm thanh/rung: ${_describeError(error)}');
      },
    );

    // Khi backend thông báo flash, Controller sẽ phát giọng nói.
    _backend.onFlashAnnouncement = _recognition.announceFlashStatus;

    _session = ScanSession(
      backend: _backend,
      recognition: _recognition,
      beforeStart: _quietFeedback,
    );
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    final errors = <String>[];
    try {
      await _settings.initialize();
    } catch (error) {
      errors.add('Không tải được cài đặt đã lưu: ${_describeError(error)}');
    }
    try {
      await _speech.initialize();
    } catch (error) {
      errors.add('Giọng nói chưa sẵn sàng: ${_describeError(error)}');
    }
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _serviceNotice = errors.isEmpty ? null : errors.join('\n');
    });
    _syncShortcutCapture();
    _start();
  }

  Future<void> _quietFeedback() async {
    await Future.wait([
      _speech.stop().catchError((Object error) {
        debugPrint('Stop speech: $error');
      }),
      _haptic.stop().catchError((Object error) {
        debugPrint('Stop vibration: $error');
      }),
    ]);
  }

  String _describeError(Object error) =>
      error is StateError ? error.message.toString() : error.toString();

  void _run(Future<void> action) {
    unawaited(action.catchError((Object error) {
      if (!mounted) return;
      _messenger.currentState
          ?.showSnackBar(SnackBar(content: Text(_describeError(error))));
    }));
  }

  void _start() => _run(_startWithPermission());

  Future<void> _startWithPermission() async {
    if (!_backend.isMock) {
      final access = await _backend.permission(request: true);
      // Permission may return while Android temporarily marks the app inactive.
      // Still register the scan request; ScanSession defers opening the camera
      // until its visible state becomes true on resume.
      if (!mounted) return;
      if (!_foreground) {
        debugPrint('[CAMERA_START] Permission returned while inactive; '
            'queuing scan for resume.');
      }
      if (access != CameraAccess.granted) {
        setState(() => _cameraPermissionMissing = true);
        _recognition.showError(
          'Camera chưa được cấp quyền. Vui lòng cấp quyền để tiếp tục.',
          isMock: false,
        );
        _schedulePermissionRecovery();
        return;
      }
    }
    if (_cameraPermissionMissing && mounted) {
      setState(() => _cameraPermissionMissing = false);
    }
    await _session.start();
  }

  void _schedulePermissionRecovery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _foreground &&
          !_permissionRecoveryOpen &&
          _routeDepth == 0) {
        _run(_openPermissionRecovery());
      }
    });
  }

  Future<void> _openPermissionRecovery() async {
    if (!mounted ||
        !_foreground ||
        _permissionRecoveryOpen ||
        _routeDepth != 0 ||
        _backend.isMock) return;
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _permissionRecoveryOpen = true;
    try {
      await _push(
          navigatorContext,
          (permissionContext) => CameraPermissionScreen(
                backend: _backend,
                onContinue: () => _run(_announceBackAndPop(
                    permissionContext, 'màn hình nhận diện tiền')),
              ));
      if (!mounted || !_foreground) return;
      final access = await _backend.permission(request: false);
      if (access == CameraAccess.granted) {
        setState(() => _cameraPermissionMissing = false);
        await _session.start();
      } else {
        setState(() => _cameraPermissionMissing = true);
        _recognition.showError(
          'Camera chưa được cấp quyền. Hãy mở Cài đặt ứng dụng để cấp quyền.',
          isMock: false,
        );
        try {
          await _speech.speak(
            'Camera chưa được cấp quyền. Hãy mở cài đặt ứng dụng để cấp quyền.',
            rate: _settings.settings.speechRate,
            priority: SpeechPriority.instruction,
          );
        } catch (error) {
          debugPrint('Không đọc được thông báo quyền camera: $error');
        }
      }
    } finally {
      _permissionRecoveryOpen = false;
    }
  }

  /// Chỉ nhận thao tác phần cứng khi ứng dụng ở màn camera và đang hoạt động.
  Future<void> _onHardwareHold(VolumeHoldAction action) async {
    if (!mounted ||
        !_initialized ||
        !_foreground ||
        _routeDepth != 0 ||
        _changingMode) {
      return;
    }
    try {
      switch (action) {
        case VolumeHoldAction.switchMode:
          await _switchMode();
          break;
        case VolumeHoldAction.newSession:
          if (_countingMode) await _startNewCountingSession();
          break;
      }
    } catch (error) {
      if (!mounted) return;
      _messenger.currentState?.showSnackBar(
        SnackBar(
            content: Text('Thao tác phím âm lượng: ${_describeError(error)}')),
      );
    }
  }

  void _syncShortcutCapture() {
    _run(_volumeShortcuts.setEnabled(
      _initialized && _foreground && _routeDepth == 0,
      countingMode: _countingMode,
    ));
  }

  Future<void> _switchMode() async {
    if (_changingMode || !_initialized || !_foreground || _routeDepth != 0) {
      return;
    }
    _changingMode = true;
    final hadRecognizedNote = _recognition.state.hasResult;
    try {
      // Dừng phiên camera để vô hiệu hóa callback từ chế độ cũ.
      await _session.setVisible(false);
      await _quietFeedback();
      if (!mounted || !_foreground || _routeDepth != 0) return;

      final enterCounting = !_countingMode;
      setState(() => _countingMode = enterCounting);
      _syncShortcutCapture();
      _recognition.startScanning(
        isMock: _backend.isMock,
        requireClearBeforeAccept: enterCounting && hadRecognizedNote,
      );
      _recognition.suppressNextScanningPrompt();

      // Quay lại Đếm tiền sẽ tự tiếp tục: không hiện hộp thoại hay xóa tổng.
      final firstNoteInstruction = hadRecognizedNote
          ? 'Hãy đưa tờ tiền đang ở trước camera ra ngoài, '
              'chờ camera xác nhận trống rồi đưa vào lại.'
          : 'Sau thông báo này, đưa từng tờ tiền vào camera để đếm.';
      final announcement = enterCounting
          ? (_moneyCounter.hasCounted
              ? 'Đã chuyển sang chế độ đếm tiền. Tiếp tục phiên trước. '
                  'Đã đếm ${_moneyCounter.noteCount} tờ. '
                  'Tổng hiện tại ${_moneyCounter.totalSpeech}. '
                  '$firstNoteInstruction'
              : 'Đã chuyển sang chế độ đếm tiền. Tổng hiện tại không đồng. '
                  '$firstNoteInstruction')
          : 'Đã chuyển sang chế độ nhận diện tiền. '
              'Tổng tiền phiên đếm vẫn được giữ lại.';
      try {
        await _speech.speak(
          announcement,
          rate: _settings.settings.speechRate,
          priority: SpeechPriority.result,
        );
      } catch (error) {
        debugPrint('Không đọc được thông báo chuyển chế độ: $error');
      }
    } finally {
      if (mounted && _foreground && _routeDepth == 0) {
        await _session.setVisible(true);
      }
      _changingMode = false;
    }
  }

  Future<void> _startNewCountingSession() async {
    if (_changingMode ||
        !_countingMode ||
        !_initialized ||
        !_foreground ||
        _routeDepth != 0) {
      return;
    }
    _changingMode = true;
    final hadRecognizedNote = _recognition.state.hasResult;
    try {
      await _session.setVisible(false);
      await _quietFeedback();
      if (!mounted || !_foreground || _routeDepth != 0) return;

      final previousCount = _moneyCounter.noteCount;
      final previousTotal = _moneyCounter.totalSpeech;
      _moneyCounter.startNewSession();
      _recognition.startScanning(
        isMock: _backend.isMock,
        requireClearBeforeAccept: hadRecognizedNote,
      );
      _recognition.suppressNextScanningPrompt();

      final firstNoteInstruction = hadRecognizedNote
          ? 'Hãy đưa tờ tiền đang ở trước camera ra ngoài, '
              'chờ camera xác nhận trống rồi đưa vào lại.'
          : 'Sau thông báo này, đưa tờ tiền đầu tiên vào camera.';
      final announcement = previousCount == 0
          ? 'Đã bắt đầu phiên đếm mới. Tổng hiện tại không đồng. '
              '$firstNoteInstruction'
          : 'Đã kết thúc phiên đếm trước. Đã đếm $previousCount tờ. '
              'Tổng $previousTotal. Đã bắt đầu phiên đếm mới. '
              'Tổng hiện tại không đồng. '
              '$firstNoteInstruction';
      try {
        await _speech.speak(
          announcement,
          rate: _settings.settings.speechRate,
          priority: SpeechPriority.result,
        );
      } catch (error) {
        debugPrint('Không đọc được thông báo phiên mới: $error');
      }
    } finally {
      if (mounted && _foreground && _routeDepth == 0) {
        await _session.setVisible(true);
      }
      _changingMode = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncShortcutCapture();
    if (!_foreground) unawaited(_quietFeedback());
    _run(_session.setVisible(_foreground && _routeDepth == 0));
  }

  Future<void> _push(BuildContext context, WidgetBuilder builder) async {
    _routeDepth++;
    ++_settingsSpeechEpoch; // Discard stale messages when navigating.
    _syncShortcutCapture();
    _run(_session.setVisible(false));
    await _quietFeedback();
    try {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: builder));
    } finally {
      _routeDepth--;
      _syncShortcutCapture();
      await _quietFeedback();
      if (mounted) _run(_session.setVisible(_foreground && _routeDepth == 0));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _backend.onFlashAnnouncement = null;

    _session.dispose(); // token hết hiệu lực trước khi controller bị dispose
    _recognition.dispose();
    _volumeShortcuts.dispose();
    _moneyCounter.dispose();
    _settings.dispose();
    unawaited(_quietFeedback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messenger,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (_, child) => MobileViewport(child: child!),
        home: !_initialized
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Builder(
                builder: (routeContext) => AnimatedBuilder(
                      animation: Listenable.merge(
                          [_recognition, _session, _moneyCounter]),
                      builder: (_, child) {
                        final camera = _backend.cameraController;
                        return RecognitionScreen(
                          state: _recognition.state,
                          isMockBackend: _backend.isMock,
                          serviceNotice: _serviceNotice,
                          onRetryServices: () => _run(_initializeServices()),
                          onOpenSettings: () => _openSettings(routeContext),
                          onRecoverCamera: () =>
                              _run(_openPermissionRecovery()),
                          cameraPermissionMissing: _cameraPermissionMissing,
                          isMoneyCounting: _countingMode,
                          totalVnd: _moneyCounter.totalVnd,
                          noteCount: _moneyCounter.noteCount,
                          cameraPreview:
                              camera != null && camera.value.isInitialized
                                  ? Center(child: CameraPreview(camera))
                                  : null,
                        );
                      },
                    )),
      );

  // Only configuration announcements are serialized. Recognition results retain
  // their existing priority and may interrupt camera guidance as before.
  Future<void> _settingsSpeechQueue = Future<void>.value();
  int _settingsSpeechEpoch = 0;
  bool _backNavigationBusy = false;

  Future<void> _queueSettingsSpeech(String message, SpeechRateOption rate) {
    final epoch = _settingsSpeechEpoch;
    final next = _settingsSpeechQueue.then((_) async {
      if (!mounted || epoch != _settingsSpeechEpoch || _routeDepth == 0) {
        return;
      }
      await _speech.speak(
        message,
        rate: rate,
        priority: SpeechPriority.instruction,
      );
    });
    // A failed TTS request should not poison the next queued announcement.
    _settingsSpeechQueue = next.catchError((Object error, StackTrace stack) {
      debugPrint('Settings speech queue: $error');
    });
    return next;
  }

  Future<void> _changeVibration(bool enabled) async {
    // The controller updates immediately; persisted writes stay serialized.
    final saving = _settings.setVibration(enabled);
    final speaking = _queueSettingsSpeech(
      enabled ? 'Đã bật phản hồi rung.' : 'Đã tắt phản hồi rung.',
      _settings.settings.speechRate,
    );
    try {
      await speaking;
    } finally {
      await saving;
    }
  }

  Future<void> _changeSpeechRate(SpeechRateOption rate) async {
    final saving = _settings.setSpeechRate(rate);
    final label = switch (rate) {
      SpeechRateOption.slow => 'chậm',
      SpeechRateOption.normal => 'vừa',
      SpeechRateOption.fast => 'nhanh',
    };
    final speaking = _queueSettingsSpeech(
      'Đã chọn tốc độ $label. Đây là tốc độ đọc hiện tại.',
      rate,
    );
    try {
      await speaking;
    } finally {
      await saving;
    }
  }

  // A deliberate back action supersedes pending settings announcements.
  // Wait for the brief back message before closing the route; _push stops
  // audio when a route is popped.
  Future<void> _announceBackAndPop(
      BuildContext pageContext, String destination) async {
    if (_backNavigationBusy || !pageContext.mounted) return;
    _backNavigationBusy = true;
    ++_settingsSpeechEpoch;
    try {
      await _speech.speak(
        'Đang quay lại $destination.',
        rate: _settings.settings.speechRate,
        priority: SpeechPriority.instruction,
      );
    } catch (error) {
      debugPrint('Back navigation TTS: $error');
    } finally {
      if (pageContext.mounted && Navigator.of(pageContext).canPop()) {
        Navigator.of(pageContext).pop();
      }
      _backNavigationBusy = false;
    }
  }

  void _openSettings(BuildContext context) {
    _run(_push(
        context,
        (settingsContext) => AnimatedBuilder(
              animation: _settings,
              builder: (_, child) => SettingsScreen(
                settings: _settings.settings,
                onOpenGuide: () => _openGuide(settingsContext),
                onBack: () => _run(_announceBackAndPop(
                    settingsContext, 'màn hình nhận diện tiền')),
                onVibrationChanged: (value) => _run(_changeVibration(value)),
                onSpeechRateChanged: (value) => _run(_changeSpeechRate(value)),
              ),
            )));
  }

  void _openGuide(BuildContext context) {
    _run(_push(
      context,
      (guideContext) => GuideScreen(
        onBack: () =>
            _run(_announceBackAndPop(guideContext, 'màn hình Tùy chọn')),
        onAutoRead: () => _speech.speak(
          AppStrings.spokenGuide,
          rate: _settings.settings.speechRate,
          priority: SpeechPriority.instruction,
        ),
        onReadCompleted: () {
          if (guideContext.mounted) {
            Navigator.of(guideContext).popUntil((route) => route.isFirst);
          }
        },
      ),
    ));
  }
}
