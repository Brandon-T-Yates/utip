import 'package:flutter_test/flutter_test.dart';
import 'package:utip/calculation/tip_calculation.dart';

void main() {
  group('Exact cent calculations', () {
    final fixtures = <int, Map<int, int>>{
      0: {0: 0, 15: 0, 30: 0},
      10: {0: 0, 15: 2, 30: 3},
      50: {0: 0, 15: 8, 30: 15},
      2575: {0: 0, 15: 386, 30: 773},
      10000: {0: 0, 15: 1500, 30: 3000},
    };
    for (final bill in fixtures.entries) {
      for (final tip in bill.value.entries) {
        test('${bill.key} cents at ${tip.key}%', () {
          final result = TipCalculation.calculate(
            billCents: bill.key,
            tipPercent: tip.key,
          );
          expect(result.tipCents, tip.value);
          expect(result.totalCents, bill.key + tip.value);
          expect(result.selectedTipPercent, tip.key);
          expect(result.isRounded, isFalse);
        });
      }
    }

    test('Default tip is 15%, with half cents rounded up consistently', () {
      final result = TipCalculation.calculate(billCents: 10);
      expect(result.selectedTipPercent, 15);
      expect(formatCents(result.tipCents), '0.02');
      expect(formatCents(result.totalCents), '0.12');
      expect(TipCalculation.calculate(billCents: 9).tipCents, 1);
      expect(TipCalculation.calculate(billCents: 11).tipCents, 2);
    });

    test('Formatting preserves exact cents, trailing zeros, and large amounts',
        () {
      expect(formatCents(0), '0.00');
      expect(formatCents(1), '0.01');
      expect(formatCents(10), '0.10');
      expect(formatCents(2575), '25.75');
      final result = TipCalculation.calculate(
        billCents: maxBillCents,
        tipPercent: 30,
      );
      expect(result.tipCents, 300000000000);
      expect(formatCents(result.totalCents), '12999999999.99');
    });

    test(
        'Rejects negative bills, overflow, and slider percentages outside 0–30',
        () {
      for (final cents in [-1, maxBillCents + 1]) {
        expect(
          () => TipCalculation.calculate(billCents: cents),
          throwsRangeError,
        );
      }
      for (final percent in [-1, 31]) {
        expect(
          () => TipCalculation.calculate(billCents: 100, tipPercent: percent),
          throwsRangeError,
        );
      }
      expect(() => formatCents(-1), throwsRangeError);
    });
  });

  group('Whole-dollar rounding', () {
    test('Rounds the calculated total up or down and reports the effective tip',
        () {
      final original = TipCalculation.calculate(billCents: 2575);
      final up = original.roundUp();
      expect(up.totalCents, 3000);
      expect(up.tipCents, 425);
      expect(up.effectiveTipPercent, '16.50');
      expect(up.selectedTipPercent, 15);
      final down = original.roundDown()!;
      expect(down.totalCents, 2900);
      expect(down.tipCents, 325);
      expect(down.effectiveTipPercent, '12.62');
      expect(original.totalCents, 2961);
    });

    test('A small bill can exceed 30% without clamping the money or slider',
        () {
      final rounded = TipCalculation.calculate(billCents: 50).roundUp();
      expect(rounded.totalCents, 100);
      expect(rounded.tipCents, 50);
      expect(rounded.effectiveTipPercent, '100.00');
      expect(rounded.exceedsSliderRange, isTrue);
      expect(rounded.selectedTipPercent, 15);
      final tenCents = TipCalculation.calculate(billCents: 10).roundUp();
      expect(tenCents.tipCents, 90);
      expect(tenCents.effectiveTipPercent, '900.00');
      final oneCent = TipCalculation.calculate(billCents: 1).roundUp();
      expect(oneCent.effectiveTipPercent, '9900.00');
    });

    test('Already-whole totals stay unchanged in both directions', () {
      for (final result in [
        TipCalculation.calculate(billCents: 100, tipPercent: 0),
        TipCalculation.calculate(billCents: 10000),
        TipCalculation.calculate(billCents: 10000, tipPercent: 30),
      ]) {
        expect(result.roundUp().totalCents, result.totalCents);
        expect(result.roundDown()!.totalCents, result.totalCents);
      }
    });

    test('Repeated rounding is stable, including changing direction', () {
      final result = TipCalculation.calculate(billCents: 2575);
      final up = result.roundUp();
      expect(up.roundUp().totalCents, 3000);
      expect(up.roundDown()!.totalCents, 3000);
      final down = result.roundDown()!;
      expect(down.roundDown()!.totalCents, 2900);
      expect(down.roundUp().totalCents, 2900);
    });

    test('Impossible round down leaves the immutable original available', () {
      for (final bill in [1, 10, 50, 90, 2575]) {
        final result = TipCalculation.calculate(billCents: bill, tipPercent: 0);
        expect(result.roundDown(), isNull);
        expect(result.totalCents, bill);
        expect(result.tipCents, 0);
        expect(result.isRounded, isFalse);
      }
    });

    test('Zero bills never create an effective tip or divide by zero', () {
      final result = TipCalculation.calculate(billCents: 0);
      expect(result.roundUp().totalCents, 0);
      expect(result.roundDown()!.totalCents, 0);
      expect(result.effectiveTipPercent, '0.00');
      expect(result.exceedsSliderRange, isFalse);
    });

    test(
        'Recalculation clears rounding while retaining the selected percentage',
        () {
      final rounded = TipCalculation.calculate(billCents: 50).roundUp();
      final edited = TipCalculation.calculate(
        billCents: 2575,
        tipPercent: rounded.selectedTipPercent,
      );
      expect(edited.isRounded, isFalse);
      expect(edited.tipCents, 386);
      expect(edited.totalCents, 2961);
    });

    test(
        'Cent boundaries reconcile and never produce negative or drifting totals',
        () {
      for (var bill = 1; bill <= 10000; bill += 37) {
        for (var percent = 0; percent <= 30; percent++) {
          final original = TipCalculation.calculate(
            billCents: bill,
            tipPercent: percent,
          );
          final up = original.roundUp();
          expect(original.totalCents, original.billCents + original.tipCents);
          expect(up.totalCents % 100, 0);
          expect(up.totalCents, greaterThanOrEqualTo(original.totalCents));
          expect(up.totalCents - original.totalCents, lessThan(100));
          expect(up.roundUp().totalCents, up.totalCents);
          final down = original.roundDown();
          if (down != null) {
            expect(down.totalCents % 100, 0);
            expect(down.totalCents, greaterThanOrEqualTo(bill));
            expect(down.totalCents, lessThanOrEqualTo(original.totalCents));
            expect(down.tipCents, greaterThanOrEqualTo(0));
          }
        }
      }
    });
  });
}
