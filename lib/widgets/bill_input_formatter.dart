import 'package:flutter/services.dart';

import '../calculation/bill_input.dart';

/// Accepts or rejects an entire edit; never strips characters from a pasted bill.
class BillInputFormatter extends TextInputFormatter {
  BillInputFormatter({this.onInvalidInput});

  final void Function(String message)? onInvalidInput;
  TextEditingValue _lastAcceptedValue = TextEditingValue.empty;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.composing.isCollapsed &&
        parseBillInput(oldValue.text).isValid) {
      _lastAcceptedValue = oldValue;
    }
    // Let the keyboard finish composing before validating the committed text.
    if (!newValue.composing.isCollapsed) return newValue;

    final input = parseBillInput(newValue.text);
    if (input.isValid) {
      _lastAcceptedValue = newValue;
      return newValue;
    }
    onInvalidInput?.call(input.error!);
    return _lastAcceptedValue.copyWith(composing: TextRange.empty);
  }
}
