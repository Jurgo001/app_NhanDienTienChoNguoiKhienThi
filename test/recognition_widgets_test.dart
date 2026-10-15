import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/recognition_ui_state.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/recognition/recognition_screen.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/widgets/accessible_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen(RecognitionUiState state) {
  return MaterialApp(
    home: RecognitionScreen(
      state: state,
      onStartScanning: () {},
      onReplayResult: () {},
      onResetScan: () {},
      onOpenSettings: () {},
      onOpenGuide: () {},
      onOpenPermission: () {},
    ),
  );
}

void main() {
  testWidgets('Chưa có kết quả thật hay giả khi vừa mở màn hình',
      (tester) async {
    await tester.pumpWidget(
      _screen(const RecognitionUiState(status: RecognitionUiStatus.ready)),
    );

    expect(find.text(AppStrings.cameraPlaceholder), findsOneWidget);
    expect(find.text(AppStrings.noResult), findsOneWidget);
    expect(find.text(AppStrings.mockDenomination), findsNothing);
    expect(
      tester
          .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Kết quả demo có nhãn semantics và bật Đọc lại', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _screen(
        const RecognitionUiState(
          status: RecognitionUiStatus.recognized,
          denomination: AppStrings.mockDenomination,
        ),
      ),
    );

    expect(find.text(AppStrings.mockResultLabel), findsOneWidget);
    expect(find.text(AppStrings.mockDenomination), findsOneWidget);
    expect(
      tester
          .widget<AccessibleButton>(find.byKey(const Key('replay_button')))
          .onPressed,
      isNotNull,
    );
    expect(
      find.bySemanticsLabel(
        '${AppStrings.mockResultLabel}: ${AppStrings.mockDenomination}',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(AppStrings.replay), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Cảnh báo chưa rõ và lỗi dùng chữ, không giữ mệnh giá', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(const RecognitionUiState(status: RecognitionUiStatus.unclear)),
    );
    expect(find.text(AppStrings.unclearTitle), findsOneWidget);
    expect(find.text(AppStrings.unclearMessage), findsOneWidget);
    expect(find.text(AppStrings.mockDenomination), findsNothing);

    await tester.pumpWidget(
      _screen(const RecognitionUiState(status: RecognitionUiStatus.error)),
    );
    expect(find.text(AppStrings.errorTitle), findsOneWidget);
    expect(find.text(AppStrings.errorMessage), findsOneWidget);
    expect(find.text(AppStrings.mockDenomination), findsNothing);
  });

  testWidgets('Dữ liệu thật dùng câu trạng thái không gắn nhãn mô phỏng', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        const RecognitionUiState(
          status: RecognitionUiStatus.scanning,
          isMock: false,
        ),
      ),
    );
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            (widget.properties.label
                    ?.contains(AppStrings.scanningRealMessage) ??
                false)),
        findsOneWidget);
    expect(find.text(AppStrings.scanningNoResultReal), findsOneWidget);
    expect(find.text(AppStrings.simulationBanner), findsNothing);

    await tester.pumpWidget(
      _screen(
        const RecognitionUiState(
          status: RecognitionUiStatus.recognized,
          denomination: AppStrings.mockDenomination,
          isMock: false,
        ),
      ),
    );
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            (widget.properties.label
                    ?.contains(AppStrings.recognizedRealMessage) ??
                false)),
        findsOneWidget);
    expect(find.text(AppStrings.mockResultLabel), findsNothing);
  });

  testWidgets('Màn nhỏ và chữ gấp đôi vẫn cuộn, không tràn bố cục', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      _screen(
        const RecognitionUiState(
          status: RecognitionUiStatus.recognized,
          denomination: AppStrings.mockDenomination,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('replay_button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
