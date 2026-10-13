import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utip/main.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
}

void main() {
  for (final dark in [false, true]) {
    for (final scaling in [(1.0, false), (2.0, true), (3.2, true)]) {
      testWidgets(
        'Floating percentage is readable during dragging: dark=$dark scaling=$scaling',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          tester.platformDispatcher.textScaleFactorTestValue = scaling.$1;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          SharedPreferences.setMockInitialValues({
            'isDarkMode': dark,
            'isLargeText': scaling.$2,
          });
          await tester.pumpWidget(const UtipApp());
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byKey(const ValueKey('billInput')), '25.75');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          final slider = find.byType(Slider);
          await tester.ensureVisible(slider);
          await tester.pumpAndSettle();

          // Inspect Flutter's resolved slider theme, including activeColor
          // precedence, rather than only checking our theme configuration.
          final dynamic renderSlider = tester.renderObject(
            find.descendant(
              of: slider,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget.runtimeType.toString() ==
                    '_SliderRenderObjectWidget',
              ),
            ),
          );
          final SliderThemeData resolved = renderSlider.sliderTheme;
          expect(resolved.showValueIndicator, ShowValueIndicator.onDrag);
          expect(resolved.valueIndicatorColor,
              dark ? const Color(0xFF99DB8F) : Colors.black);
          expect(resolved.valueIndicatorTextStyle!.color,
              dark ? const Color(0xFF102015) : Colors.white);
          expect(
              _contrast(resolved.valueIndicatorTextStyle!.color!,
                  resolved.valueIndicatorColor!),
              greaterThan(4.5));

          final RenderBox box = renderSlider;
          final track = resolved.trackShape!.getPreferredRect(
            parentBox: box,
            sliderTheme: resolved,
            isEnabled: true,
            isDiscrete: true,
          );
          final dynamic sliderState = tester.state(slider);
          expect(sliderState.valueIndicatorController.value, 0);
          final gesture = await tester.startGesture(box.localToGlobal(
              Offset(track.left + track.width * 0.5, track.center.dy)));
          await tester.pumpAndSettle();
          expect(sliderState.valueIndicatorController.value, 1);
          // Cross the drag threshold before applying the measured value change.
          await gesture.moveBy(const Offset(30, 0));
          await gesture.moveBy(Offset(track.width * 0.2, 0));
          await tester.pump(const Duration(milliseconds: 250));

          expect(tester.widget<Slider>(slider).value, 21);
          expect(renderSlider.label, '21%');
          expect(renderSlider.value, closeTo(0.7, 0.001));
          // Material 3 limits its floating indicator's scale to 1.3. Keep that
          // native behavior, while the main percentage uses the full scaler.
          final expectedScale = scaling.$1 * (scaling.$2 ? 1.3 : 1);
          expect(renderSlider.textScaleFactor,
              closeTo(expectedScale.clamp(0, 1.3), 0.001));
          expect(
              MediaQuery.textScalerOf(tester
                      .element(find.byKey(const ValueKey('tipPercentage'))))
                  .scale(18),
              closeTo(18 * expectedScale, 0.001));
          expect(
              tester
                  .widget<Text>(find.byKey(const ValueKey('tipPercentage')))
                  .data,
              '21%');
          expect(
              tester
                  .widget<Text>(find.byKey(const ValueKey('totalAmount')))
                  .data,
              r'$31.16');
          expect(tester.takeException(), isNull);

          await gesture.up();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(sliderState.valueIndicatorController.value, 0);
          expect(tester.widget<Slider>(slider).label, '21%');
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
