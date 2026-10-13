import 'package:flutter_test/flutter_test.dart';
import 'package:utip/calculation/bill_input.dart';
import 'package:utip/calculation/tip_calculation.dart';

void main() {
  group('Valid bills and complete currency pastes', () {
    final fixtures = <String, int>{
      '0': 0,
      '0.00': 0,
      '0.10': 10,
      '0.50': 50,
      '.50': 50,
      ',50': 50,
      '12.50': 1250,
      '12,50': 1250,
      '12.5': 1250,
      '12,5': 1250,
      '12.': 1200,
      '12,': 1200,
      '25.75': 2575,
      '00025.75': 2575,
      r'$12.50': 1250,
      r' $ 12.50 ': 1250,
      r'$1,234.56': 123456,
      '1,234.00': 123400,
      '1,234,567.89': 123456789,
      '9999999999.99': maxBillCents,
    };
    for (final entry in fixtures.entries) {
      test('Parses "${entry.key}" exactly', () {
        final result = parseBillInput(entry.key);
        expect(result.cents, entry.value);
        expect(result.error, isNull);
        expect(result.isComplete, isTrue);
      });
    }
  });

  test('Allows intermediate edits without treating them as a completed bill',
      () {
    for (final text in ['', ' ', '.', ',', r'$', r'$.']) {
      final result = parseBillInput(text);
      expect(result.isValid, isTrue);
      expect(result.cents, 0);
      expect(result.isComplete, isFalse);
    }
  });

  group('Invalid input is rejected in full', () {
    for (final text in [
      '-12.50',
      r'$-12.50',
      '(12.50)',
      '+12.50',
      '12abc',
      r'12$50',
      r'$$12.50',
      'NaN',
      'Infinity',
      '1e3',
      '€12.50',
      '12.345',
      '.005',
      '12,345',
      '1,234',
      r'$1,234',
      '1,234,567',
      '12,34.56',
      '1,234.567',
      '1.234,56',
      '12..50',
      '1 234.56',
      '12\n50',
      '12\r50',
      '12.50\n',
      '10000000000',
      '9999999999999999999999999999999999999999',
    ]) {
      test('Rejects "$text" with feedback', () {
        final result = parseBillInput(text);
        expect(result.isValid, isFalse);
        expect(result.cents, isNull);
        expect(result.error, isNotEmpty);
      });
    }
  });
}
