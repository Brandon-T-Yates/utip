import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utip/main.dart';

final _bill = find.byKey(const ValueKey('billInput'));
final _up = find.widgetWithText(ElevatedButton, 'Round up to nearest dollar');
final _down =
    find.widgetWithText(ElevatedButton, 'Round down to nearest dollar');

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
}) async {
  // Behavior tests use enough space for the existing layout and test font.
  // Phone/keyboard layout improvements remain a separate increment.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(const UtipApp());
  await tester.pumpAndSettle();
}

Future<void> _enterBill(WidgetTester tester, String text) async {
  await tester.enterText(_bill, text);
  await tester.pump();
}

Future<void> _pasteBill(WidgetTester tester, String text) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    if (call.method == 'Clipboard.hasStrings') return {'value': true};
    return null;
  });
  addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  await tester.showKeyboard(_bill);
  final editable = tester.state<EditableTextState>(find.byType(EditableText));
  editable.widget.controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: editable.widget.controller.text.length,
  );
  await editable.pasteText(SelectionChangedCause.toolbar);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Rejects a multiline clipboard paste without joining separate amounts',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '25.75');
    await _pasteBill(tester, '12\n50');
    expect(tester.widget<TextField>(_bill).controller!.text, '25.75');
    expect(_text(tester, 'totalAmount'), r'$29.61');
    expect(find.textContaining('single line'), findsOneWidget);
  });

  testWidgets('Rounding waits for keyboard composition to finish',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '25.75');
    await tester.showKeyboard(_bill);
    const composing = TextEditingValue(
      text: '12.50',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 3, end: 5),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    for (final action in [_up, _down]) {
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(_text(tester, 'totalAmount'), r'$29.61');
      expect(find.text('Finish entering the bill before rounding.'),
          findsOneWidget);
    }
    tester.testTextInput
        .updateEditingValue(composing.copyWith(composing: TextRange.empty));
    await tester.pumpAndSettle();
    expect(_text(tester, 'totalAmount'), r'$14.38');
  });

  testWidgets('Correcting input clears queued validation messages',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '25.75');
    for (final text in ['12abc', '-5', '12.345']) {
      await _enterBill(tester, text);
    }
    await _enterBill(tester, '12.50');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(_text(tester, 'totalAmount'), r'$14.38');
  });

  testWidgets(
      'Committed keyboard composition updates the bill even when only the composing range changes',
      (tester) async {
    await _pumpApp(tester);
    await tester.showKeyboard(_bill);
    const composing = TextEditingValue(
      text: '12.50',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 3, end: 5),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    expect(_text(tester, 'totalAmount'), r'$0.00');
    tester.testTextInput
        .updateEditingValue(composing.copyWith(composing: TextRange.empty));
    await tester.pump();
    expect(_text(tester, 'tipAmount'), r'$1.88');
    expect(_text(tester, 'totalAmount'), r'$14.38');
  });

  testWidgets(
      'Invalid committed composition restores the bill without clearing a rounded result',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '.50');
    await tester.tap(_up);
    await tester.pumpAndSettle();
    await tester.showKeyboard(_bill);
    const composing = TextEditingValue(
      text: '.5x',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 2, end: 3),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    tester.testTextInput
        .updateEditingValue(composing.copyWith(composing: TextRange.empty));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_bill).controller!.text, '.50');
    expect(_text(tester, 'totalAmount'), r'$1.00');
    expect(_text(tester, 'tipPercentage'), '100.00%');
    expect(find.textContaining('Enter a bill amount'), findsOneWidget);
  });

  testWidgets('Starts at zero with the existing 15% and 0–30% slider',
      (tester) async {
    await _pumpApp(tester);
    expect(_text(tester, 'tipAmount'), r'$0.00');
    expect(_text(tester, 'totalAmount'), r'$0.00');
    expect(_text(tester, 'tipPercentage'), '15%');
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 15);
    expect(slider.min, 0);
    expect(slider.max, 30);
    expect(slider.divisions, 30);
    expect(tester.widget<TextField>(_bill).keyboardType,
        const TextInputType.numberWithOptions(decimal: true));
    expect(
        tester.widget<TextField>(_bill).textInputAction, TextInputAction.done);
    await tester.tap(_up);
    await tester.tap(_down);
    await tester.pumpAndSettle();
    expect(_text(tester, 'tipPercentage'), '15%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Displayed cents reconcile for small and normal bills',
      (tester) async {
    await _pumpApp(tester);
    for (final fixture in [
      ('0.10', r'$0.02', r'$0.12'),
      ('.50', r'$0.08', r'$0.58'),
      ('25.75', r'$3.86', r'$29.61'),
    ]) {
      await _enterBill(tester, fixture.$1);
      expect(_text(tester, 'tipAmount'), fixture.$2);
      expect(_text(tester, 'totalAmount'), fixture.$3);
    }
  });

  testWidgets('Actual slider gestures calculate 0% and 30% in cents',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '25.75');
    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tipPercentage'), '0%');
    expect(_text(tester, 'tipAmount'), r'$0.00');
    expect(_text(tester, 'totalAmount'), r'$25.75');
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tipPercentage'), '30%');
    expect(_text(tester, 'tipAmount'), r'$7.73');
    expect(_text(tester, 'totalAmount'), r'$33.48');
  });

  testWidgets('Round up can exceed 30% while the slider remains in range',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '.50');
    await tester.tap(_up);
    await tester.pumpAndSettle();
    expect(_text(tester, 'tipAmount'), r'$0.50');
    expect(_text(tester, 'totalAmount'), r'$1.00');
    expect(_text(tester, 'tipPercentage'), '100.00%');
    expect(tester.widget<Slider>(find.byType(Slider)).value, 15);
    expect(find.textContaining('Adjust the slider to return to a regular tip.'),
        findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Effective rounded tip percentage'),
        findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rounding down never reduces a small bill and explains why',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '0.50');
    await tester.tap(_down);
    await tester.pumpAndSettle();
    expect(_text(tester, 'tipAmount'), r'$0.08');
    expect(_text(tester, 'totalAmount'), r'$0.58');
    expect(_text(tester, 'tipPercentage'), '15%');
    expect(find.textContaining('Total left unchanged.'), findsOneWidget);
  });

  testWidgets('Round down and repeated operations preserve exact whole totals',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '25.75');
    await tester.tap(_down);
    await tester.pumpAndSettle();
    expect(_text(tester, 'totalAmount'), r'$29.00');
    expect(_text(tester, 'tipAmount'), r'$3.25');
    expect(_text(tester, 'tipPercentage'), '12.62%');
    for (final action in [_down, _up, _up]) {
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(_text(tester, 'totalAmount'), r'$29.00');
    }
  });

  testWidgets('Changing the bill clears rounded money and effective percentage',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '.50');
    await tester.tap(_up);
    await tester.pumpAndSettle();
    await _enterBill(tester, '25.75');
    expect(_text(tester, 'tipAmount'), r'$3.86');
    expect(_text(tester, 'totalAmount'), r'$29.61');
    expect(_text(tester, 'tipPercentage'), '15%');
    await _enterBill(tester, '');
    expect(_text(tester, 'totalAmount'), r'$0.00');
    expect(_text(tester, 'tipPercentage'), '15%');
  });

  testWidgets('Moving the slider clears rounding, including a tip above 30%',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '.50');
    await tester.tap(_up);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tipPercentage'), '30%');
    expect(_text(tester, 'tipAmount'), r'$0.15');
    expect(_text(tester, 'totalAmount'), r'$0.65');
  });

  testWidgets(
      'Accepts decimal commas and preserves a full clipboard currency paste',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '12,50');
    expect(tester.widget<TextField>(_bill).controller!.text, '12,50');
    expect(_text(tester, 'tipAmount'), r'$1.88');
    expect(_text(tester, 'totalAmount'), r'$14.38');
    await _pasteBill(tester, r'$1,234.56');
    expect(tester.widget<TextField>(_bill).controller!.text, r'$1,234.56');
    expect(tester.widget<TextField>(_bill).decoration!.prefixText, isNull);
    expect(_text(tester, 'tipAmount'), r'$185.18');
    expect(_text(tester, 'totalAmount'), r'$1419.74');
  });

  testWidgets('Rejects an ambiguous clipboard paste without changing the bill',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '25.75');
    await _pasteBill(tester, '1,234');
    expect(tester.widget<TextField>(_bill).controller!.text, '25.75');
    expect(_text(tester, 'totalAmount'), r'$29.61');
    expect(find.textContaining('enter 1234 or 1,234.00'), findsOneWidget);
  });

  testWidgets('Invalid edits keep the current rounded result and give feedback',
      (tester) async {
    await _pumpApp(tester);
    await _enterBill(tester, '.50');
    await tester.tap(_up);
    await tester.pumpAndSettle();
    for (final text in ['-12.50', '12.345', '12abc']) {
      await _enterBill(tester, text);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_bill).controller!.text, '.50');
      expect(_text(tester, 'totalAmount'), r'$1.00');
      expect(_text(tester, 'tipPercentage'), '100.00%');
      expect(find.byType(SnackBar), findsOneWidget);
    }
  });

  testWidgets(
      'Dark mode and text-size preferences survive calculation and rounding',
      (tester) async {
    await _pumpApp(tester,
        preferences: {'isDarkMode': true, 'isLargeText': true});
    var calculator = tester.widget<TipCalculator>(find.byType(TipCalculator));
    expect(calculator.isDarkMode, isTrue);
    expect(calculator.isLargeText, isTrue);
    await _enterBill(tester, '25.75');
    await tester.tap(_up);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.tap(find.byTooltip('Reduce text size'));
    await tester.pumpAndSettle();
    calculator = tester.widget<TipCalculator>(find.byType(TipCalculator));
    expect(calculator.isDarkMode, isFalse);
    expect(calculator.isLargeText, isFalse);
    expect(_text(tester, 'totalAmount'), r'$30.00');
    expect(_text(tester, 'tipPercentage'), '16.50%');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isDarkMode'), isFalse);
    expect(prefs.getBool('isLargeText'), isFalse);
  });
}
