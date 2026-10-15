import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_strings.dart';
import 'core/models/app_settings.dart';
import 'core/models/recognition_ui_state.dart';
import 'core/theme/app_theme.dart';
import 'debug/mock_recognition_scenarios.dart';
import 'debug/recognition_demo_controls.dart';
import 'screens/guide/guide_screen.dart';
import 'screens/permission/camera_permission_screen.dart';
import 'screens/recognition/recognition_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/mobile_page.dart';

class MoneyRecognitionApp extends StatefulWidget {
  const MoneyRecognitionApp({super.key});

  @override
  State<MoneyRecognitionApp> createState() => _MoneyRecognitionAppState();
}

class _MoneyRecognitionAppState extends State<MoneyRecognitionApp> {
  final ValueNotifier<RecognitionUiState> _recognition = ValueNotifier(
    const RecognitionUiState(status: RecognitionUiStatus.ready),
  );
  final ValueNotifier<AppSettings> _settings =
      ValueNotifier(const AppSettings());
  final ValueNotifier<MockPermissionDecision> _permissionDecision =
      ValueNotifier(
    MockPermissionDecision.undecided,
  );

  @override
  void dispose() {
    _recognition.dispose();
    _settings.dispose();
    _permissionDecision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MobileViewport(child: child!),
      home: Builder(
        builder: (routeContext) => ValueListenableBuilder<RecognitionUiState>(
          valueListenable: _recognition,
          builder: (context, state, _) => RecognitionScreen(
            state: state,
            onStartScanning: () {
              if (!kDebugMode) {
                _showNotice(context, AppStrings.scanUnavailableNotice);
                return;
              }
              _recognition.value = const RecognitionUiState(
                status: RecognitionUiStatus.scanning,
              );
              _showNotice(context, AppStrings.scanMockNotice);
            },
            onReplayResult: () {
              if (_recognition.value.hasResult) {
                _showNotice(context, AppStrings.replayMockNotice);
              }
            },
            onResetScan: () {
              if (!kDebugMode) {
                _recognition.value = const RecognitionUiState(
                  status: RecognitionUiStatus.ready,
                );
                _showNotice(context, AppStrings.scanUnavailableNotice);
                return;
              }
              _recognition.value = const RecognitionUiState(
                status: RecognitionUiStatus.scanning,
              );
              _showNotice(context, AppStrings.resetMockNotice);
            },
            onOpenSettings: () => _openSettings(routeContext),
            onOpenGuide: () => _openGuide(routeContext: routeContext),
            onOpenPermission: () => _openPermission(routeContext),
            debugControls: kDebugMode
                ? RecognitionDemoControls(
                    onRecognized: () => _recognition.value =
                        MockRecognitionScenarios.recognized,
                    onUnclear: () =>
                        _recognition.value = MockRecognitionScenarios.unclear,
                    onError: () =>
                        _recognition.value = MockRecognitionScenarios.error,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<AppSettings>(
          valueListenable: _settings,
          builder: (context, settings, _) => SettingsScreen(
            settings: settings,
            onOpenGuide: () => _openGuide(routeContext: context),
            onOpenPermission: () => _openPermission(context),
            onAutoReadChanged: (value) => _settings.value =
                _settings.value.copyWith(autoReadEnabled: value),
            onVibrationChanged: (value) => _settings.value =
                _settings.value.copyWith(vibrationEnabled: value),
            onSpeechRateChanged: (value) =>
                _settings.value = _settings.value.copyWith(speechRate: value),
          ),
        ),
      ),
    );
  }

  void _openGuide({required BuildContext routeContext}) {
    Navigator.of(routeContext).push(
      MaterialPageRoute<void>(
        builder: (guideContext) => GuideScreen(
          onListen: () => _showNotice(
            guideContext,
            AppStrings.listenGuideMockNotice,
          ),
          onStartRecognition: () =>
              Navigator.of(guideContext).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  void _openPermission(BuildContext context) {
    _permissionDecision.value = MockPermissionDecision.undecided;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (permissionContext) =>
            ValueListenableBuilder<MockPermissionDecision>(
          valueListenable: _permissionDecision,
          builder: (_, decision, __) => CameraPermissionScreen(
            decision: decision,
            onApproveMock: () {
              _permissionDecision.value = MockPermissionDecision.approved;
              Navigator.of(permissionContext).pop();
              _showNotice(context, AppStrings.permissionApprovedMockNotice);
            },
            onDenyMock: () {
              _permissionDecision.value = MockPermissionDecision.denied;
            },
            onContinueMock: () => Navigator.of(permissionContext).pop(),
          ),
        ),
      ),
    );
  }

  void _showNotice(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
