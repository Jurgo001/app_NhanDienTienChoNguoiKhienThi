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
import 'services/touch_exploration_service.dart';
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
  late final TouchExplorationService _touchExploration;
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
  bool _waitingCameraReady = false;
  String? _modeTalkBackAnnouncement;
  bool _resetDialogOpen = false;
  int _routeDepth = 0;
  String? _serviceNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = widget.speechService ?? SpeechService();
    _touchExploration = TouchExplorationService();
    _touchExploration.addListener(_onTouchExplorationChanged);
    _haptic = widget.hapticService ?? HapticService();
    _backend = widget.backend ?? createScanBackend();
    final storage = widget.settingsService ?? SettingsService();
    _settings = SettingsController(storage);
    _moneyCounter = MoneyCountingController(
      storage: storage,
      onStorageError: (error) {
        if (mounted) {
          setState(() => _serviceNotice = 'Không lưu được phiên đếm: $error');
        }
      },
    );
    _volumeShortcuts = HardwareVolumeShortcuts(onAction: _onHardwareHold);
    _volumeShortcuts.register();
    _recognition = RecognitionController(
      speechService: _speech,
      isTouchExplorationEnabled: () => _touchExploration.enabled,
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
      // Restore count before the camera can resume scanning.
      await _moneyCounter.initialize();
    } catch (error) {
      errors.add(
          'Không khôi phục được phiên đếm đã lưu: ${_describeError(error)}');
    }
    try {
      await _speech.initialize();
    } catch (error) {
      errors.add('Giọng nói chưa sẵn sàng: ${_describeError(error)}');
    }
    // Query accessibility BEFORE starting the camera / startup narration.
    _touchExploration.updateFallback(
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .accessibleNavigation,
    );
    // Native Android normally returns this almost immediately. On widget tests,
    // the MethodChannel can have no native reply; do NOT block app initialization.
    // A delayed result can still update the screen-reader mode afterward.
    try {
      await _touchExploration.initialize().timeout(
        const Duration(milliseconds: 700),
        onTimeout: () {
          debugPrint('Touch exploration query timed out; using Flutter hint.');
          _touchExploration.updateFallback(
            WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
                .accessibleNavigation,
          );
        },
      );
    } catch (error) {
      // Accessibility checks must never prevent opening the camera.
      debugPrint('Touch exploration initialization failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _serviceNotice = errors.isEmpty ? null : errors.join('\n');
    });
    _syncShortcutCapture();
    _start();
  }

  void _onTouchExplorationChanged() {
    if (!mounted) return;
    // If the screen reader was enabled while a Settings/Guide utterance was
    // active, stop that UI utterance. Never stop a denomination on camera.
    if (_touchExploration.enabled && _routeDepth > 0) {
      _run(_speech.stop());
    }
    _syncShortcutCapture();
  }

  @override
  void didChangeAccessibilityFeatures() {
    // Native channel is authoritative on Android. General Flutter hint is a
    // fallback for platforms without the channel, never a TalkBack identifier.
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
        _changingMode ||
        _resetDialogOpen ||
        !_settings.settings.hardwareShortcutsEnabled ||
        _touchExploration.enabled) {
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
      _initialized &&
          _foreground &&
          _routeDepth == 0 &&
          !_resetDialogOpen &&
          _settings.settings.hardwareShortcutsEnabled &&
          !_touchExploration.enabled,
      countingMode: _countingMode,
    ));
  }

  Future<void> _switchMode() async {
    if (_changingMode || !_initialized || !_foreground || _routeDepth != 0) {
      return;
    }
    _changingMode = true;

    final talkBackMode = _touchExploration.enabled;
    debugPrint('[MODE_A11Y] touch exploration: $talkBackMode');
    if (mounted) setState(() => _modeTalkBackAnnouncement = null);
    // Hide preview until the first real AI frame has completed. The preview
    // opening alone does not prove that the detector can accept a banknote.
    if (mounted) setState(() => _waitingCameraReady = true);
    try {
      // Phase 1: stop the previous image stream; no frame can enter a new
      // counting session while the mode announcement is still speaking.
      debugPrint('[MODE_READY] stopping old camera stream');
      await _session.setVisible(false, releaseCamera: false);
      await _quietFeedback();
      if (!mounted || !_foreground || _routeDepth != 0) return;

      final enterCounting = !_countingMode;
      setState(() => _countingMode = enterCounting);
      _syncShortcutCapture();
      _recognition.startScanning(
        isMock: _backend.isMock,
        // Entering Counting accepts the first visible note after readiness.
        // Existing lockedAnnounced state still prevents counting that note twice.
        requireClearBeforeAccept: false,
      );
      _recognition.suppressNextScanningPrompt();

      const firstNoteInstruction = 'Có thể đặt sẵn một tờ tiền trước camera. '
          'Vui lòng chờ camera sẵn sàng để bắt đầu đếm.';
      final announcement = enterCounting
          ? (_moneyCounter.hasCounted
              ? 'Đã chuyển sang chế độ đếm tiền. Tiếp tục phiên trước. '
                  'Đã đếm ${_moneyCounter.noteCount} tờ. '
                  'Tổng hiện tại ${_moneyCounter.totalSpeech}. '
                  '$firstNoteInstruction'
              : 'Đã chuyển sang chế độ đếm tiền. Tổng hiện tại không đồng. '
                  '$firstNoteInstruction')
          : 'Đã chuyển sang chế độ nhận diện tiền. '
              'Tổng tiền phiên đếm vẫn được giữ lại. '
              'Vui lòng chờ thông báo camera sẵn sàng.';

      // With TalkBack, the screen reader owns navigation feedback. Never
      // play the same mode announcement using a second TTS engine.
      // Without TalkBack, finish the full app speech before starting camera.
      // Both TalkBack-on and TalkBack-off users hear this through app TTS.
      // TalkBack remains responsible only for controls the user explores.
      // Absolutely no camera stream starts before this await completes.
      try {
        debugPrint('[MODE_READY] speaking mode announcement');
        await _speech.speak(
          announcement,
          rate: _settings.settings.speechRate,
          priority: SpeechPriority.result,
        );
      } catch (error) {
        debugPrint('[MODE_READY] mode speech error: $error');
      }
      if (!mounted || !_foreground || _routeDepth != 0) return;

      // Phase 3: restart the camera and wait for an actual processed frame.
      // Tests/injected backends do not have a real CameraController and are
      // deliberately not blocked on the native camera readiness signal.
      final realCamera = widget.backend == null && !_backend.isMock;
      // The detector may warm up, but callbacks must NOT reach recognition,
      // counting or result TTS until the ready announcement is over.
      _session.setModeFeedbackSpeechActive(true);
      if (realCamera) _session.armCameraReadiness();
      debugPrint('[MODE_READY] starting camera after announcement');
      await _session.setVisible(true);
      if (!mounted || !_foreground || _routeDepth != 0) return;

      if (realCamera) {
        final ready = _backend.cameraController != null &&
            (await _session.waitForCameraReadiness(
              timeout: const Duration(seconds: 8),
            ));
        if (!mounted || !_foreground || _routeDepth != 0) return;
        if (!ready) {
          final needsClear = _recognition.waitingForClearBeforeCounting;
          final problem = needsClear
              ? 'Camera đang chờ bạn đưa tờ tiền cũ ra khỏi khung để tránh cộng trùng.'
              : 'Camera chưa xử lý được khung hình đầu tiên. Hãy thử mở lại camera.';
          debugPrint('[MODE_READY] not ready: $problem');
          setState(() => _serviceNotice = problem);
          try {
            await _speech.speak(
              problem,
              rate: _settings.settings.speechRate,
              priority: SpeechPriority.instruction,
            );
          } catch (error) {
            debugPrint('[MODE_READY] readiness error TTS: $error');
          }
          return;
        }
        if (_serviceNotice?.startsWith('Camera chưa xử lý') == true ||
            _serviceNotice?.startsWith('Camera đang chờ') == true) {
          setState(() => _serviceNotice = null);
        }
        debugPrint('[MODE_READY] first AI frame processed');
        // The image stream can warm up during this narration, but the session
        // gate prevents any result/counting TTS from interrupting it.
        try {
          debugPrint('[MODE_READY] speaking camera ready');
          await _speech.speak(
            enterCounting
                ? 'Camera đã sẵn sàng. Bắt đầu đếm tiền.'
                : 'Camera đã sẵn sàng. Hãy đưa một tờ tiền vào để nhận diện.',
            rate: _settings.settings.speechRate,
            priority: SpeechPriority.guidance,
          );
        } catch (error) {
          debugPrint('[MODE_READY] ready announcement error: $error');
        }
        if (mounted) setState(() => _waitingCameraReady = false);
      }
    } finally {
      _session.setModeFeedbackSpeechActive(false);
      debugPrint('[MODE_READY] recognition results enabled');
      if (mounted && _waitingCameraReady) {
        setState(() => _waitingCameraReady = false);
      }
      _changingMode = false;
    }
  }

  Future<void> _confirmCountingReset() async {
    if (!mounted ||
        !_initialized ||
        !_foreground ||
        !_countingMode ||
        _changingMode ||
        _routeDepth != 0 ||
        _resetDialogOpen) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    _resetDialogOpen = true;
    _syncShortcutCapture();
    // Tam ngung NHAN KET QUA, khong dung hoac dispose camera.
    _session.setResultsSuspended(true);
    try {
      await _quietFeedback();
      if (!mounted || !_foreground || _routeDepth != 0) return;
      final decision = showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bắt đầu phiên đếm mới?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tổng hiện tại ${_moneyCounter.totalSpeech}, '
                  'đã đếm ${_moneyCounter.noteCount} tờ. '
                  'Xác nhận xóa phiên sẽ đưa tổng tiền về không.'),
              const SizedBox(height: 24),
              OutlinedButton(
                key: const Key('cancel_count_reset_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 72),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Hủy'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('confirm_count_reset_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 72),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Xác nhận xóa phiên'),
              ),
            ],
          ),
        ),
      );
      if (!_touchExploration.enabled) {
        _run(_speech.speak(
          'Bắt đầu phiên đếm mới? Tổng hiện tại '
          '${_moneyCounter.totalSpeech}. '
          'Chọn xác nhận xóa phiên để đưa tổng về không, '
          'hoặc chọn Hủy để giữ tổng tiền.',
          rate: _settings.settings.speechRate,
          priority: SpeechPriority.instruction,
        ));
      }
      final shouldReset = await decision;
      if (!mounted || !_foreground || _routeDepth != 0) return;
      if (shouldReset == true) await _startNewCountingSession();
    } finally {
      _session.setResultsSuspended(false);
      _resetDialogOpen = false;
      _syncShortcutCapture();
    }
  }

  Future<void> _readCountingTotal() async {
    if (!mounted ||
        !_initialized ||
        !_foreground ||
        !_countingMode ||
        _routeDepth != 0 ||
        _changingMode ||
        _touchExploration.enabled) return;
    final message = _moneyCounter.hasCounted
        ? 'Tổng hiện tại ${_moneyCounter.totalSpeech}. '
            'Đã đếm ${_moneyCounter.noteCount} tờ.'
        : 'Chưa đếm tờ tiền nào. Tổng hiện tại không đồng.';
    await _speech.speak(
      message,
      rate: _settings.settings.speechRate,
      priority: SpeechPriority.result,
    );
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
    try {
      // Reset nhanh qua phim cung: khong hien dialog, khong dung camera.
      await _quietFeedback();
      if (!mounted || !_foreground || _routeDepth != 0) return;
      final hadRecognizedNote = _recognition.state.hasResult;
      final previousCount = _moneyCounter.noteCount;
      final previousTotal = _moneyCounter.totalSpeech;
      _moneyCounter.startNewSession();
      _recognition.startScanning(
        isMock: _backend.isMock,
        requireClearBeforeAccept: hadRecognizedNote,
      );
      _backend.setRecognitionLocked(false);

      final firstNoteInstruction = hadRecognizedNote
          ? 'Hãy đưa tờ tiền đang ở trước camera ra ngoài, '
              'chờ camera xác nhận trống rồi đưa vào lại.'
          : 'Đưa tờ tiền đầu tiên vào camera.';
      final announcement = previousCount == 0
          ? 'Đã bắt đầu phiên đếm mới. Tổng hiện tại không đồng. '
              '$firstNoteInstruction'
          : 'Đã kết thúc phiên đếm trước. Đã đếm $previousCount tờ. '
              'Tổng $previousTotal. Đã bắt đầu phiên đếm mới. '
              'Tổng hiện tại không đồng. $firstNoteInstruction';
      // Cho camera xu ly ngay, khong doi TTS doc het.
      _run(_speech.speak(
        announcement,
        rate: _settings.settings.speechRate,
        priority: SpeechPriority.result,
      ));
    } finally {
      _changingMode = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncShortcutCapture();
    if (!_foreground) unawaited(_quietFeedback());
    _run(_session
        .setVisible(_foreground && _routeDepth == 0 && !_waitingCameraReady));
  }

  Future<void> _push(BuildContext context, WidgetBuilder builder) async {
    _routeDepth++;
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
    _touchExploration.removeListener(_onTouchExplorationChanged);
    _touchExploration.dispose();
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
                      animation: Listenable.merge([
                        _recognition,
                        _session,
                        _moneyCounter,
                        _touchExploration
                      ]),
                      builder: (_, child) {
                        final camera = _backend.cameraController;
                        return RecognitionScreen(
                          state: _recognition.state,
                          isMockBackend: _backend.isMock,
                          serviceNotice: _serviceNotice,
                          onRetryServices: () => _run(_initializeServices()),
                          onOpenSettings: () => _openSettings(routeContext),
                          onSwitchMode: () => _run(_switchMode()),
                          onNewCountingSession: () =>
                              _run(_confirmCountingReset()),
                          onReadCountingTotal: () => _run(_readCountingTotal()),
                          screenReaderActive: _touchExploration.enabled,
                          modeTalkBackAnnouncement: _modeTalkBackAnnouncement,
                          onRecoverCamera: () =>
                              _run(_openPermissionRecovery()),
                          cameraPermissionMissing: _cameraPermissionMissing,
                          isMoneyCounting: _countingMode,
                          totalVnd: _moneyCounter.totalVnd,
                          noteCount: _moneyCounter.noteCount,
                          preparingCamera: _waitingCameraReady,
                          cameraPreview: !_waitingCameraReady &&
                                  camera != null &&
                                  camera.value.isInitialized
                              ? Center(child: CameraPreview(camera))
                              : null,
                        );
                      },
                    )),
      );

  // Setting feedback follows the most recent tap, not a FIFO queue. This
  // intentionally keeps the recognition/camera TTS priority rules unchanged.
  Future<void>? _settingsSpeechActive;
  bool _settingsNavigationBusy = false;

  Future<void> _speakSettingsConfirmation(
      String message, SpeechRateOption rate) {
    // SpeechService.speak() invalidates the preceding utterance when text or
    // rate changes. Only the newest utterance is tracked for navigation.
    final speaking = _speech.speak(
      message,
      rate: rate,
      priority: SpeechPriority.instruction,
    );
    _settingsSpeechActive = speaking;
    return speaking.whenComplete(() {
      if (identical(_settingsSpeechActive, speaking)) {
        _settingsSpeechActive = null;
      }
    });
  }

  Future<void> _changeHardwareShortcuts(bool enabled) async {
    if (_settingsNavigationBusy || _routeDepth == 0) return;
    final saving = _settings.setHardwareShortcuts(enabled);
    _syncShortcutCapture();
    if (_touchExploration.enabled) {
      await saving;
      return;
    }
    final speaking = _speakSettingsConfirmation(
      enabled
          ? 'Đã bật phím tắt âm lượng. Giữ phím tăng ba giây để đổi chế độ. '
              'Giữ phím giảm ba giây để xóa phiên đếm ngay, không hỏi lại. '
              'Nhấn giữ để chỉnh âm lượng liên tục sẽ bị hạn chế.'
          : 'Đã tắt phím tắt âm lượng. Giữ phím để chỉnh âm lượng liên tục.',
      _settings.settings.speechRate,
    );
    try {
      await speaking;
    } finally {
      await saving;
    }
  }

  Future<void> _changeVibration(bool enabled) async {
    if (_settingsNavigationBusy || _routeDepth == 0) return;
    // Update visible state and persist immediately, without waiting for TTS.
    final saving = _settings.setVibration(enabled);
    if (_touchExploration.enabled) {
      await saving;
      return;
    }
    final speaking = _speakSettingsConfirmation(
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
    if (_settingsNavigationBusy || _routeDepth == 0) return;
    final saving = _settings.setSpeechRate(rate);
    if (_touchExploration.enabled) {
      await saving;
      return;
    }
    final label = switch (rate) {
      SpeechRateOption.slow => 'chậm',
      SpeechRateOption.normal => 'vừa',
      SpeechRateOption.fast => 'nhanh',
    };
    final speaking = _speakSettingsConfirmation(
      'Đã chọn tốc độ $label. Đây là tốc độ đọc hiện tại.',
      rate,
    );
    try {
      await speaking;
    } finally {
      await saving;
    }
  }

  // Leaving Settings is different from changing a setting: keep the current
  // confirmation audible until its completion. Never wait for superseded ones.
  Future<void> _finishCurrentSettingsConfirmation() async {
    final active = _settingsSpeechActive;
    if (active == null) return;
    try {
      await active.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      // The TTS engine may occasionally hang: do not trap a blind user forever.
      await _speech.stop().catchError((Object error) {
        debugPrint('Settings TTS timeout: $error');
      });
    } catch (error) {
      debugPrint('Settings TTS completed with error: $error');
    }
  }

  // Both the in-app button and Android Back reach this method. Finish the
  // confirmation, speak the destination, then pop the route.
  Future<void> _announceBackAndPop(
      BuildContext pageContext, String destination) async {
    if (_settingsNavigationBusy || !pageContext.mounted) return;
    _settingsNavigationBusy = true;
    try {
      await _finishCurrentSettingsConfirmation();
      if (!pageContext.mounted || !_foreground) return;
      try {
        if (!_touchExploration.enabled) {
          await _speech.speak(
            'Đang quay lại $destination.',
            rate: _settings.settings.speechRate,
            priority: SpeechPriority.instruction,
          );
        }
      } catch (error) {
        debugPrint('Back navigation TTS: $error');
      }
      if (pageContext.mounted && Navigator.of(pageContext).canPop()) {
        Navigator.of(pageContext).pop();
      }
    } finally {
      _settingsNavigationBusy = false;
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
                onHardwareShortcutsChanged: (value) =>
                    _run(_changeHardwareShortcuts(value)),
              ),
            )));
  }

  // Do not open Guide while Settings is still saying its latest selection.
  // When it finishes, _push() starts Guide's normal auto-read narration.
  void _openGuide(BuildContext context) {
    if (_settingsNavigationBusy || !context.mounted) return;
    _settingsNavigationBusy = true;
    _run(_openGuideAfterSettingsSpeech(context));
  }

  Future<void> _openGuideAfterSettingsSpeech(BuildContext context) async {
    try {
      await _finishCurrentSettingsConfirmation();
      if (!mounted || !context.mounted || !_foreground) return;
      _run(_push(
        context,
        (guideContext) => GuideScreen(
          screenReaderActive: _touchExploration.enabled,
          onBack: () =>
              _run(_announceBackAndPop(guideContext, 'màn hình Tùy chọn')),
          onAutoRead: () => _touchExploration.enabled
              ? Future<void>.value()
              : _speech.speak(
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
    } finally {
      _settingsNavigationBusy = false;
    }
  }
}
