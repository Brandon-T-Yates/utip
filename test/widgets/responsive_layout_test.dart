import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utip/main.dart';
import 'package:utip/widgets/app_text_scaler.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

Future<void> _pumpPhone(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double systemScale = 1,
  bool largeText = false,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
  tester.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  SharedPreferences.setMockInitialValues({
    'isLargeText': largeText,
    'isDarkMode': dark,
  });
  await tester.pumpWidget(const UtipApp());
  await tester.pumpAndSettle();
}

Future<void> _openKeyboard(WidgetTester tester) async {
  await tester.showKeyboard(_key('billInput'));
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  tester.view.padding = const FakeViewPadding(top: 24);
  await tester.pumpAndSettle();
}

double _baseline(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero).dy +
      box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
}

Color _cardColor(WidgetTester tester, String key) =>
    (tester.widget<Container>(_key(key)).decoration! as BoxDecoration).color!;

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return ((first > second ? first : second) + 0.05) /
      ((first < second ? first : second) + 0.05);
}

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 18 ? fontSize * 2 : fontSize * 1.5;

  @override
  double get textScaleFactor => 2;
}

void _testPhone(
  String description,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.iOS,
}) {
  testWidgets(description, callback,
      variant: TargetPlatformVariant.only(platform));
}

void main() {
  test('App text scaler preserves nonlinear system scaling', () {
    const scaler = AppTextScaler(_NonlinearScaler());
    expect(scaler.scale(14), closeTo(36.4, 0.001));
    expect(scaler.scale(26), closeTo(50.7, 0.001));
    expect(scaler, const AppTextScaler(_NonlinearScaler()));
    expect(scaler.hashCode, const AppTextScaler(_NonlinearScaler()).hashCode);
  });

  // Exercise both platforms, both preferences, system accessibility scaling,
  // safe areas and keyboard insets at small and large phone dimensions.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final size in [
      const Size(320, 568),
      const Size(375, 667),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      for (final scale in [1.0, 2.0, 3.2]) {
        for (final largeText in [false, true]) {
          for (final dark in [false, true]) {
            _testPhone(
                '$platform $size system=$scale large=$largeText dark=$dark scrolls with keyboard',
                (tester) async {
              await _pumpPhone(
                tester,
                size: size,
                systemScale: scale,
                largeText: largeText,
                dark: dark,
              );
              final calculatorContext =
                  tester.element(find.byType(TipCalculator));
              expect(MediaQuery.textScalerOf(calculatorContext).scale(18),
                  closeTo(18 * scale * (largeText ? 1.3 : 1), 0.001));
              expect(tester.takeException(), isNull);
              await tester.enterText(_key('billInput'), '25.75');
              await _openKeyboard(tester);
              expect(_text(tester, 'totalAmount'), r'$29.61');
              expect(tester.takeException(), isNull);

              final viewport = tester.getRect(_key('calculatorScroll'));
              final keyboardTop = size.height - 300;
              expect(viewport.height, greaterThan(0));
              expect(viewport.bottom, lessThanOrEqualTo(keyboardTop));
              final position = tester
                  .state<ScrollableState>(
                    find
                        .descendant(
                          of: _key('calculatorScroll'),
                          matching: find.byType(Scrollable),
                        )
                        .first,
                  )
                  .position;
              expect(position.maxScrollExtent, greaterThanOrEqualTo(0));
              position.jumpTo(position.maxScrollExtent);
              await tester.pump();
              expect(tester.getRect(_key('roundDown')).bottom,
                  lessThanOrEqualTo(viewport.bottom));
              expect(tester.takeException(), isNull);
              if (platform == TargetPlatform.iOS) {
                final done = tester.getRect(_key('keyboardDone'));
                expect(done.bottom, lessThanOrEqualTo(keyboardTop));
                expect(done.top, greaterThanOrEqualTo(viewport.bottom));
                await tester.tap(_key('keyboardDone'));
              } else {
                expect(_key('keyboardDone'), findsNothing);
                await tester.testTextInput.receiveAction(TextInputAction.done);
              }
              await tester.pumpAndSettle();
              expect(
                  tester
                      .widget<TextField>(_key('billInput'))
                      .focusNode!
                      .hasFocus,
                  isFalse);
              expect(_key('keyboardDone'), findsNothing);
              expect(_text(tester, 'totalAmount'), r'$29.61');
              expect(tester.takeException(), isNull);
            }, platform: platform);
          }
        }
      }
    }
  }

  _testPhone(
      'Bill baseline aligns and underline grows with the available width',
      (tester) async {
    await _pumpPhone(tester, size: const Size(430, 932));
    await tester.enterText(_key('billInput'), '25.75');
    await tester.pumpAndSettle();
    expect(_baseline(tester, _key('billLabel')),
        closeTo(_baseline(tester, _key('billInput')), 0.01));
    final label = tester.getRect(_key('billLabel'));
    final field = tester.getRect(_key('billInput'));
    final card = tester.getRect(_key('billCard'));
    expect(field.left, greaterThan(label.right));
    expect(field.right, closeTo(card.right - 16, 0.01));
    expect(field.width, greaterThan(110));
    await tester.tap(find.byTooltip('Increase text size'));
    await tester.pumpAndSettle();
    // The wide test font needs a stacked field at this larger size.
    expect(tester.getRect(_key('billInput')).top,
        greaterThan(tester.getRect(_key('billLabel')).bottom));
    tester.view.physicalSize = const Size(600, 932);
    await tester.pumpAndSettle();
    expect(_baseline(tester, _key('billLabel')),
        closeTo(_baseline(tester, _key('billInput')), 0.01));
    expect(tester.takeException(), isNull);
  });

  _testPhone('Very large bill text stacks its label without clipping input',
      (tester) async {
    await _pumpPhone(tester,
        size: const Size(320, 568), systemScale: 3.2, largeText: true);
    final label = tester.getRect(_key('billLabel'));
    final field = tester.getRect(_key('billInput'));
    final card = tester.getRect(_key('billCard'));
    expect(field.top, greaterThan(label.bottom));
    expect(field.left, closeTo(card.left + 16, 0.01));
    expect(field.right, closeTo(card.right - 16, 0.01));
    expect(tester.takeException(), isNull);
  });

  _testPhone('Percentage header sits above a full-width slider',
      (tester) async {
    await _pumpPhone(tester);
    final header = tester.getRect(_key('percentageHeader'));
    final slider = tester.getRect(find.byType(Slider));
    expect(slider.top, greaterThan(header.bottom));
    expect(slider.left, header.left);
    expect(slider.right, header.right);
    expect(
        find.descendant(
            of: _key('percentageHeader'), matching: _key('tipPercentage')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _testPhone('Light theme retains green cards and white background',
      (tester) async {
    await _pumpPhone(tester);
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, isNull);
    final theme = Theme.of(tester.element(_key('billInput')));
    expect(theme.scaffoldBackgroundColor, Colors.white);
    expect(_cardColor(tester, 'billCard'), const Color(0xFF99DB8F));
    expect(_cardColor(tester, 'totalCard'), const Color(0xFF99DB8F));
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        const Color(0xFF99DB8F));
    expect(tester.widget<Text>(_key('totalAmount')).style!.color, Colors.black);
  });

  _testPhone('Dark palette has restrained cards and contrasting actions',
      (tester) async {
    await _pumpPhone(tester, dark: true);
    final theme = Theme.of(tester.element(_key('billInput')));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF101713));
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        const Color(0xFF101713));
    for (final key in ['billCard', 'totalCard']) {
      expect(_cardColor(tester, key), const Color(0xFF203128));
    }
    final textColor = tester.widget<Text>(_key('totalAmount')).style!.color!;
    expect(textColor, const Color(0xFFEDF5EF));
    expect(_contrast(textColor, _cardColor(tester, 'totalCard')),
        greaterThan(4.5));
    final up = tester.widget<ElevatedButton>(_key('roundUp')).style!;
    final down = tester.widget<ElevatedButton>(_key('roundDown')).style!;
    expect(up.backgroundColor!.resolve({}), const Color(0xFF99DB8F));
    expect(up.foregroundColor!.resolve({}), const Color(0xFF102015));
    expect(
        _contrast(
            up.foregroundColor!.resolve({})!, up.backgroundColor!.resolve({})!),
        greaterThan(4.5));
    expect(down.backgroundColor!.resolve({}), const Color(0xFF203128));
    expect(down.foregroundColor!.resolve({}), const Color(0xFFEDF5EF));
    expect(down.elevation!.resolve({}), 0);
  });

  for (final valid in [true, false]) {
    _testPhone('iOS Done validates active composition, valid=$valid',
        (tester) async {
      await _pumpPhone(tester);
      await tester.enterText(_key('billInput'), '25.75');
      await _openKeyboard(tester);
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: valid ? '12.50' : '12.x',
        selection: TextSelection.collapsed(offset: valid ? 5 : 4),
        composing: TextRange(start: 3, end: valid ? 5 : 4),
      ));
      await tester.pump();
      expect(_text(tester, 'totalAmount'), r'$29.61');
      await tester.tap(_key('keyboardDone'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_key('billInput'));
      expect(field.focusNode!.hasFocus, isFalse);
      expect(field.controller!.value.composing, TextRange.empty);
      expect(field.controller!.text, valid ? '12.50' : '25.75');
      expect(_text(tester, 'totalAmount'), valid ? r'$14.38' : r'$29.61');
      expect(tester.takeException(), isNull);
    });
  }

  _testPhone('Validation feedback leaves the iOS Done control accessible',
      (tester) async {
    await _pumpPhone(tester, size: const Size(320, 568), largeText: true);
    await tester.enterText(_key('billInput'), '25.75');
    await _openKeyboard(tester);
    await tester.enterText(_key('billInput'), '-12');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(tester.getRect(_key('keyboardDone')).top));
    await tester.tap(_key('keyboardDone'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_key('billInput')).focusNode!.hasFocus,
        isFalse);
    expect(_text(tester, 'totalAmount'), r'$29.61');
    expect(tester.takeException(), isNull);
  });

  _testPhone('Dragging the screen dismisses the numeric keyboard',
      (tester) async {
    await _pumpPhone(tester, size: const Size(375, 667), largeText: true);
    await tester.enterText(_key('billInput'), '25.75');
    await _openKeyboard(tester);
    await tester.drag(_key('calculatorScroll'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_key('billInput')).focusNode!.hasFocus,
        isFalse);
    expect(_key('keyboardDone'), findsNothing);
    expect(_text(tester, 'totalAmount'), r'$29.61');
    expect(tester.takeException(), isNull);
  });

  _testPhone('Tapping background dismisses the keyboard without changing money',
      (tester) async {
    await _pumpPhone(tester);
    await tester.enterText(_key('billInput'), '25.75');
    await _openKeyboard(tester);
    await tester.tap(_key('tipAmount'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_key('billInput')).focusNode!.hasFocus,
        isFalse);
    expect(_text(tester, 'totalAmount'), r'$29.61');
  });

  _testPhone(
      'Largest bill and rounded percentage remain readable at large scales',
      (tester) async {
    await _pumpPhone(tester,
        size: const Size(320, 568),
        systemScale: 3.2,
        largeText: true,
        dark: true);
    await tester.enterText(_key('billInput'), '9999999999.99');
    await tester.pumpAndSettle();
    expect(_text(tester, 'totalAmount'), r'$11499999999.99');
    expect(tester.takeException(), isNull);
    await tester.enterText(_key('billInput'), '0.01');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('roundUp'));
    await tester.pumpAndSettle();
    await tester.tap(_key('roundUp'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'totalAmount'), r'$1.00');
    expect(_text(tester, 'tipPercentage'), '9900.00%');
    expect(tester.takeException(), isNull);
  });

  _testPhone('Text and theme changes while typing retain focus and bill input',
      (tester) async {
    await _pumpPhone(tester, size: const Size(430, 932));
    await tester.enterText(_key('billInput'), '25.75');
    await _openKeyboard(tester);
    await tester.tap(find.byTooltip('Increase text size'));
    await tester.pumpAndSettle();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(_key('billInput'));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.text, '25.75');
    expect(_key('keyboardDone'), findsOneWidget);
    expect(_text(tester, 'totalAmount'), r'$29.61');
    expect(tester.takeException(), isNull);
    await tester.tap(_key('keyboardDone'));
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isFalse);
  });

  _testPhone('Resize, theme and app text preference preserve rounded results',
      (tester) async {
    await _pumpPhone(tester);
    await tester.enterText(_key('billInput'), '25.75');
    await tester.tap(_key('roundUp'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.tap(find.byTooltip('Increase text size'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'totalAmount'), r'$30.00');
    expect(_text(tester, 'tipPercentage'), '16.50%');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isDarkMode'), isTrue);
    expect(prefs.getBool('isLargeText'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const UtipApp());
    await tester.pumpAndSettle();
    final calculator = tester.widget<TipCalculator>(find.byType(TipCalculator));
    expect(calculator.isDarkMode, isTrue);
    expect(calculator.isLargeText, isTrue);
    expect(tester.takeException(), isNull);
  });
}
