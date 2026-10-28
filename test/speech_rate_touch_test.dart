import 'package:app_ho_tro_nguoi_khiem_thi/core/constants/app_strings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/models/app_settings.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/core/theme/app_theme.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Ba vùng tốc độ nhận chạm sát cạnh, rộng $width, cỡ chữ $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final semantics = tester.ensureSemantics();
          try {
            var settings = const AppSettings();
            SpeechRateOption? lastSelected;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: StatefulBuilder(
                  builder: (context, setState) => SettingsScreen(
                    settings: settings,
                    onVibrationChanged: (_) {},
                    onOpenGuide: () {},
                    onSpeechRateChanged: (rate) {
                      lastSelected = rate;
                      setState(() {
                        settings = settings.copyWith(speechRate: rate);
                      });
                    },
                  ),
                ),
              ),
            );
            final finders = [
              for (final rate in SpeechRateOption.values)
                find.byKey(Key('speech_rate_${rate.name}')),
            ];
            await tester.ensureVisible(finders.first);
            await tester.pumpAndSettle();
            final rects = finders.map(tester.getRect).toList();
            for (final rect in rects) {
              expect(rect.width, closeTo((width - 40) / 3, .01));
              expect(rect.height, greaterThanOrEqualTo(64));
            }
            expect(rects[0].right, closeTo(rects[1].left, .01));
            expect(rects[1].right, closeTo(rects[2].left, .01));

            for (var i = 0; i < finders.length; i++) {
              await tester.ensureVisible(finders[i]);
              await tester.pumpAndSettle();
              final rect = tester.getRect(finders[i]);
              final points = [
                Offset(rect.left + 4, rect.center.dy),
                Offset(rect.right - 4, rect.center.dy),
                Offset(rect.center.dx, rect.top + 4),
                Offset(rect.center.dx, rect.bottom - 4),
              ];
              for (final point in points) {
                lastSelected = null;
                await tester.tapAt(point);
                await tester.pumpAndSettle();
                expect(lastSelected, SpeechRateOption.values[i]);
                expect(settings.speechRate, SpeechRateOption.values[i]);
              }
            }
            expect(
              tester.getSemantics(finders.last),
              matchesSemantics(
                label: '${AppStrings.speechRate}: ${AppStrings.fast}',
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                hasSelectedState: true,
                isSelected: true,
                isInMutuallyExclusiveGroup: true,
                hasTapAction: true,
              ),
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
