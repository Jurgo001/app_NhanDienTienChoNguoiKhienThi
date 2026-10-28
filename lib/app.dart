import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'controllers/recognition_controller.dart';
import 'controllers/scan_session.dart';
import 'controllers/settings_controller.dart';
import 'core/constants/app_strings.dart';
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
  late final SpeechService _speech;
  late final HapticService _haptic;
  late final ScanBackend _backend;
  late final SettingsController _settings;
  late final RecognitionController _recognition;
  late final ScanSession _session;
  bool _initialized = false, _foreground = true;
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
    _recognition = RecognitionController(
      speechService: _speech,
      hapticService: _haptic,
      getSettings: () => _settings.settings,
      onFeedbackError: (error) {
        if (mounted)
          setState(() => _serviceNotice =
              'Phản hồi âm thanh/rung: ${_describeError(error)}');
      },
    );
    _session = ScanSession(
      backend: _backend,
      recognition: _recognition,
      beforeStart: _quietFeedback,
    );
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    final errors = <String>[];
    var speechReady = false;
    try {
      await _settings.initialize();
    } catch (error) {
      errors.add('Không tải được cài đặt đã lưu: ${_describeError(error)}');
    }
    try {
      await _speech.initialize();
      speechReady = true;
    } catch (error) {
      errors.add('Giọng nói chưa sẵn sàng: ${_describeError(error)}');
    }
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _serviceNotice = errors.isEmpty ? null : errors.join('\n');
    });
    if (speechReady) _start();
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

  void _start() => _run(_session.start());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) unawaited(_quietFeedback());
    _run(_session.setVisible(_foreground && _routeDepth == 0));
  }

  Future<void> _push(BuildContext context, WidgetBuilder builder) async {
    _routeDepth++;
    _run(_session.setVisible(false));
    unawaited(_quietFeedback());
    try {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: builder));
    } finally {
      _routeDepth--;
      await _quietFeedback();
      if (mounted) _run(_session.setVisible(_foreground && _routeDepth == 0));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose(); // token hết hiệu lực trước khi controller bị dispose
    _recognition.dispose();
    _settings.dispose();
    unawaited(_quietFeedback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messenger,
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
                      animation: Listenable.merge([_recognition, _session]),
                      builder: (_, child) {
                        final camera = _backend.cameraController;
                        return RecognitionScreen(
                          state: _recognition.state,
                          isMockBackend: _backend.isMock,
                          serviceNotice: _serviceNotice,
                          onRetryServices: () => _run(_initializeServices()),
                          onOpenSettings: () => _openSettings(routeContext),
                          onOpenGuide: () => _openGuide(routeContext),
                          onOpenPermission: () => _openPermission(routeContext),
                          cameraPreview:
                              camera != null && camera.value.isInitialized
                                  ? Center(child: CameraPreview(camera))
                                  : null,
                        );
                      },
                    )),
      );

  void _openSettings(BuildContext context) {
    _run(_push(
        context,
        (settingsContext) => AnimatedBuilder(
              animation: _settings,
              builder: (_, child) => SettingsScreen(
                settings: _settings.settings,
                onOpenGuide: () => _openGuide(settingsContext),
                onVibrationChanged: (value) =>
                    _run(_settings.setVibration(value)),
                onSpeechRateChanged: (value) =>
                    _run(_settings.setSpeechRate(value)),
              ),
            )));
  }

  void _openGuide(BuildContext context) {
    _run(_push(
        context,
        (guideContext) => GuideScreen(
              onListen: () => _run(_speech.speak(
                AppStrings.spokenGuide,
                rate: _settings.settings.speechRate,
              )),
              onStartRecognition: () {
                Navigator.of(guideContext).popUntil((route) => route.isFirst);
                _start();
              },
            )));
  }

  void _openPermission(BuildContext context) {
    _run(_push(
        context,
        (permissionContext) => CameraPermissionScreen(
              backend: _backend,
              onContinue: () => Navigator.of(permissionContext).pop(),
            )));
  }
}
