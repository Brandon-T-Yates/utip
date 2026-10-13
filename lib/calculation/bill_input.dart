import 'tip_calculation.dart';

class BillInputResult {
  const BillInputResult.valid(int this.cents, {this.isComplete = true})
      : error = null;

  const BillInputResult.invalid(String this.error)
      : cents = null,
        isComplete = false;

  final int? cents;
  final String? error;
  final bool isComplete;

  bool get isValid => cents != null;
}

final _decimal = RegExp(r'^(?:[0-9]+(?:\.[0-9]{0,2})?|\.[0-9]{0,2})$');
final _decimalComma = RegExp(r'^(?:[0-9]+(?:,[0-9]{0,2})?|,[0-9]{0,2})$');
final _groupedDollars = RegExp(r'^[0-9]{1,3}(?:,[0-9]{3})+\.[0-9]{0,2}$');

/// Accepts decimal dots or unambiguous decimal commas and optional dollar signs.
/// Comma grouping requires an explicit decimal dot (1,234.00), so a paste like
/// 1,234 cannot be mistaken for a decimal amount or silently truncated.
/// The caller keeps the original input text, including accepted paste formatting.
BillInputResult parseBillInput(String text) {
  if (text.contains('\n') || text.contains('\r')) {
    return const BillInputResult.invalid(
      'Enter one bill amount on a single line.',
    );
  }
  var amount = text.trim();
  if (amount.startsWith(r'$')) amount = amount.substring(1).trimLeft();
  if (amount.isEmpty || amount == '.' || amount == ',') {
    return const BillInputResult.valid(0, isComplete: false);
  }
  if (amount.contains('-')) {
    return const BillInputResult.invalid('The bill cannot be negative.');
  }
  if (RegExp(r'[^0-9.,]').hasMatch(amount)) {
    return const BillInputResult.invalid(
      'Enter a bill amount, optionally beginning with a dollar sign.',
    );
  }

  if (amount.contains(',') && amount.contains('.')) {
    if (!_groupedDollars.hasMatch(amount)) {
      return const BillInputResult.invalid(
        'Use comma groups of three and up to two decimals, e.g. 1,234.56.',
      );
    }
    amount = amount.replaceAll(',', '');
  } else if (amount.contains(',')) {
    if (!_decimalComma.hasMatch(amount)) {
      return const BillInputResult.invalid(
        'Use up to two decimals. For grouped amounts, enter 1234 or 1,234.00.',
      );
    }
    amount = amount.replaceAll(',', '.');
  } else if (!_decimal.hasMatch(amount)) {
    return const BillInputResult.invalid('Use up to two decimal places.');
  }

  final parts = amount.split('.');
  final whole = parts.first.replaceFirst(RegExp(r'^0+'), '');
  if (whole.length > (maxBillCents ~/ 100).toString().length) {
    return const BillInputResult.invalid(
      'The maximum bill is \$9,999,999,999.99.',
    );
  }
  final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  final cents =
      (whole.isEmpty ? 0 : int.parse(whole)) * 100 + int.parse(fraction);
  return BillInputResult.valid(cents);
}
