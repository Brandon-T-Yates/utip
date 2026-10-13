import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utip/widgets/bill_input_formatter.dart';

void main() {
  const previous = TextEditingValue(
    text: '25.75',
    selection: TextSelection.collapsed(offset: 5),
  );

  test('Preserves complete valid pastes and their cursor position', () {
    for (final text in ['.50', '12,50', r'$1,234.56', r' $ 12.50 ']) {
      final next = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      final formatter = BillInputFormatter();
      expect(formatter.formatEditUpdate(previous, next), next);
    }
  });

  test('Rejects invalid pastes in full and supplies clear feedback', () {
    final messages = <String>[];
    final formatter = BillInputFormatter(onInvalidInput: messages.add);
    for (final text in ['-5', '12abc', '12.345', '1,234', r'$12.345']) {
      final result = formatter.formatEditUpdate(
        previous,
        TextEditingValue(text: text),
      );
      expect(result.text, previous.text);
      expect(result.selection, previous.selection);
    }
    expect(messages, hasLength(5));
    expect(messages.every((message) => message.isNotEmpty), isTrue);
  });

  test('Can type a leading decimal and delete back to an empty field', () {
    final formatter = BillInputFormatter();
    var value = TextEditingValue.empty;
    for (final text in ['.', '.5', '.50', '.5', '.', '']) {
      value = formatter.formatEditUpdate(value, TextEditingValue(text: text));
      expect(value.text, text);
    }
  });

  test('Rejects a third decimal digit without truncating a pasted amount', () {
    final formatter = BillInputFormatter();
    final next = formatter.formatEditUpdate(
      previous,
      const TextEditingValue(text: '25.759'),
    );
    expect(next.text, '25.75');
    expect(
      formatter
          .formatEditUpdate(previous, const TextEditingValue(text: '1.239'))
          .text,
      '25.75',
    );
  });

  test('Defers IME composition and restores the last accepted edit if invalid',
      () {
    final messages = <String>[];
    final formatter = BillInputFormatter(onInvalidInput: messages.add);
    const composing = TextEditingValue(
      text: '25.x',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 3, end: 4),
    );
    expect(formatter.formatEditUpdate(previous, composing), composing);
    expect(messages, isEmpty);
    final committed = composing.copyWith(composing: TextRange.empty);
    expect(formatter.formatEditUpdate(composing, committed).text, '25.75');
    expect(messages, hasLength(1));
  });

  test('Accepts committed valid IME text without losing its selection', () {
    final formatter = BillInputFormatter();
    const composing = TextEditingValue(
      text: '12.50',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 3, end: 5),
    );
    formatter.formatEditUpdate(previous, composing);
    final committed = composing.copyWith(composing: TextRange.empty);
    expect(formatter.formatEditUpdate(composing, committed), committed);
  });
}
