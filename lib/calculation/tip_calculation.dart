/// Supports the original input's ten whole-dollar digits, plus exact cents.
const int maxBillCents = 999999999999;

/// Formats nonnegative cents without floating-point currency conversion.
String formatCents(int cents) {
  RangeError.checkNotNegative(cents, 'cents');
  return '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

/// An immutable calculation. The slider selection remains independent of the
/// effective tip created by whole-dollar rounding.
class TipCalculation {
  const TipCalculation._({
    required this.billCents,
    required this.tipCents,
    required this.selectedTipPercent,
    this.isRounded = false,
  });

  factory TipCalculation.calculate({
    required int billCents,
    int tipPercent = 15,
  }) {
    RangeError.checkValueInInterval(billCents, 0, maxBillCents, 'billCents');
    RangeError.checkValueInInterval(tipPercent, 0, 30, 'tipPercent');
    // Round a fractional cent half up, then derive the total from that tip.
    final tipCents = (billCents * tipPercent + 50) ~/ 100;
    return TipCalculation._(
      billCents: billCents,
      tipCents: tipCents,
      selectedTipPercent: tipPercent,
    );
  }

  final int billCents;
  final int tipCents;
  final int selectedTipPercent;
  final bool isRounded;

  int get totalCents => billCents + tipCents;

  /// Percentage rounded half up to two decimal places using integer arithmetic.
  /// This is presentation only; it is never used to recalculate the money.
  String get effectiveTipPercent {
    if (billCents == 0) return '0.00';
    final hundredths = (tipCents * 10000 + billCents ~/ 2) ~/ billCents;
    return formatCents(hundredths);
  }

  bool get exceedsSliderRange => tipCents * 100 > billCents * 30;

  TipCalculation roundUp() {
    if (billCents == 0) return this;
    return _withTotal(((totalCents + 99) ~/ 100) * 100);
  }

  /// Returns null when the lower whole dollar would reduce the original bill.
  /// The caller can retain this result and explain why rounding is unavailable.
  TipCalculation? roundDown() {
    if (billCents == 0) return this;
    final roundedTotal = (totalCents ~/ 100) * 100;
    if (roundedTotal < billCents) return null;
    return _withTotal(roundedTotal);
  }

  TipCalculation _withTotal(int total) => TipCalculation._(
        billCents: billCents,
        tipCents: total - billCents,
        selectedTipPercent: selectedTipPercent,
        isRounded: true,
      );
}
