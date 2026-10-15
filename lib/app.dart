import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/recognition_controller.dart';
import 'controllers/settings_controller.dart';
import 'core/constants/app_strings.dart';

import 'core/theme/app_theme.dart';

import 'debug/recognition_demo_controls.dart';
import 'models/denomination.dart';
import 'screens/guide/guide_screen.dart';
import 'screens/permission/camera_permission_screen.dart';
import 'screens/recognition/recognition_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/haptic_service.dart';
import 'services/settings_service.dart';
import 'services/speech_service.dart';
import 'widgets/mobile_page.dart';

class MoneyRecognitionApp extends StatefulWidget {
  const MoneyRecognitionApp({super.key});

  @override
  State<MoneyRecognitionApp> createState() => _MoneyRecognitionAppState();
}

class _MoneyRecognitionAppState extends State<MoneyRecognitionApp> {
  // Các service do TV3 xây dựng.
  final SpeechService _speechService = SpeechService();
  final HapticService _hapticService = HapticService();
  final SettingsService _settingsService = SettingsService();

  late final SettingsController _settingsController;
  late final RecognitionController _recognitionController;

  // Trạng thái màn hình quyền camera mô phỏng của TV1.
  final ValueNotifier<MockPermissionDecision> _permissionDecision =
      ValueNotifier(MockPermissionDecision.undecided);

  bool _initialized = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();

    // Khởi tạo controller cài đặt.
    _settingsController = SettingsController(_settingsService);

    // Khởi tạo controller nhận diện.
    _recognitionController = RecognitionController(
      speechService: _speechService,
      hapticService: _hapticService,
      getSettings: () => _settingsController.settings,
    );

    // Tải cài đặt và khởi tạo giọng nói.
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _settingsController.initialize();
      await _speechService.initialize();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _initializationError = error.toString();
      });
    }
  }

  // Xử lý Future để lỗi không làm mất phản hồi của UI.
  void _runSafely(Future<void> future) {
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        debugPrint('TV3 operation error: $error');
      }),
    );
  }

  @override
  void dispose() {
    _recognitionController.dispose();
    _settingsController.dispose();
    _permissionDecision.dispose();

    unawaited(_speechService.stop());

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
      home: !_initialized
          ? Scaffold(
              body: Center(
                child: _initializationError == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Không thể khởi tạo ứng dụng:\n'
                          '$_initializationError',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            )
          : Builder(
              builder: (routeContext) => AnimatedBuilder(
                animation: _recognitionController,
                builder: (context, _) {
                  final state = _recognitionController.state;

                  return RecognitionScreen(
                    state: state,

                    // Bắt đầu quét mô phỏng.
                    onStartScanning: () {
                      if (!kDebugMode) {
                        _showNotice(
                          context,
                          AppStrings.scanUnavailableNotice,
                        );
                        return;
                      }

                      _recognitionController.startScanning();

                      _showNotice(
                        context,
                        AppStrings.scanMockNotice,
                      );
                    },

                    // Đọc lại kết quả hiện tại bằng TTS thật.
                    onReplayResult: () {
                      _runSafely(
                        _recognitionController.replayResult(),
                      );
                    },

                    // Xóa kết quả và bắt đầu phiên mới.
                    onResetScan: () {
                      if (!kDebugMode) {
                        _showNotice(
                          context,
                          AppStrings.scanUnavailableNotice,
                        );
                        return;
                      }

                      _runSafely(
                        _recognitionController.resetScan(),
                      );

                      _showNotice(
                        context,
                        AppStrings.resetMockNotice,
                      );
                    },

                    onOpenSettings: () => _openSettings(routeContext),

                    onOpenGuide: () => _openGuide(routeContext: routeContext),

                    onOpenPermission: () => _openPermission(routeContext),

                    // Chỉ bật mô phỏng khi chạy Debug.
                    debugControls: kDebugMode
                        ? RecognitionDemoControls(
                            onRecognized: () {
                              // Dữ liệu mô phỏng để test TV3.
                              _recognitionController.simulateRecognition(
                                Denomination.vnd100000,
                              );
                            },
                            onUnclear: () {
                              _recognitionController.showUnclear(
                                isMock: true,
                              );
                            },
                            onError: () {
                              _recognitionController.showError(
                                'Lỗi nhận diện mô phỏng',
                                isMock: true,
                              );
                            },
                          )
                        : null,
                  );
                },
              ),
            ),
    );
  }

  // Màn hình cài đặt của TV1 kết nối SettingsController.
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimatedBuilder(
          animation: _settingsController,
          builder: (context, _) {
            final settings = _settingsController.settings;

            return SettingsScreen(
              settings: settings,
              onOpenGuide: () => _openGuide(routeContext: context),
              onOpenPermission: () => _openPermission(context),
              onAutoReadChanged: (value) {
                _runSafely(
                  _settingsController.setAutoRead(value),
                );
              },
              onVibrationChanged: (value) {
                _runSafely(
                  _settingsController.setVibration(value),
                );
              },
              onSpeechRateChanged: (value) {
                _runSafely(
                  _settingsController.setSpeechRate(value),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Giữ nguyên màn hình hướng dẫn của TV1.
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

  // Giữ nguyên luồng quyền camera mô phỏng của TV1.
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

              _showNotice(
                context,
                AppStrings.permissionApprovedMockNotice,
              );
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

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
