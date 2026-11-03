import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/philippine_phone_input_formatter.dart';

void main() {
  group('PhilippinePhoneInputFormatter Tests', () {
    late PhilippinePhoneInputFormatter formatter;
    bool zeroStrippedFired = false;

    setUp(() {
      zeroStrippedFired = false;
      formatter = PhilippinePhoneInputFormatter(
        onZeroStripped: () {
          zeroStrippedFired = true;
        },
      );
    });

    test('accepts empty text', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue.empty;
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '');
      expect(zeroStrippedFired, isFalse);
    });

    test('blocks non-digits (letters/symbols)', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, ''); // blocked, returns oldValue
      expect(zeroStrippedFired, isFalse);
    });

    test('blocks non-9 starting digits (e.g. 1, 2, 8)', () {
      const oldValue = TextEditingValue.empty;
      for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8']) {
        final newValue = TextEditingValue(
          text: digit,
          selection: const TextSelection.collapsed(offset: 1),
        );
        final result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '', reason: 'Digit $digit should be blocked');
      }
      expect(zeroStrippedFired, isFalse);
    });

    test('allows temporary leading 0', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '0');
      expect(result.selection.end, 1);
      expect(zeroStrippedFired, isFalse);
    });

    test('blocks non-9 digit following temporary 0 (e.g. 01, 08)', () {
      const oldValue = TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
      const newValue = TextEditingValue(
        text: '01',
        selection: TextSelection.collapsed(offset: 2),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '0'); // returns oldValue
      expect(zeroStrippedFired, isFalse);
    });

    test('strips 0 when 09 is typed, keeps 9, and fires onZeroStripped', () {
      const oldValue = TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
      const newValue = TextEditingValue(
        text: '09',
        selection: TextSelection.collapsed(offset: 2),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '9');
      expect(result.selection.end, 1);
      expect(zeroStrippedFired, isTrue);
    });

    test('strips leading 0 when 09171234567 is pasted, formats properly, and fires callback', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '09171234567',
        selection: TextSelection.collapsed(offset: 11),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '917 123 4567');
      expect(zeroStrippedFired, isTrue);
    });

    test('accepts directly starting with 9 without triggering zeroStripped', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '9',
        selection: TextSelection.collapsed(offset: 1),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '9');
      expect(zeroStrippedFired, isFalse);
    });

    test('formats progressively as 9XX XXX XXXX', () {
      var current = TextEditingValue.empty;

      // 9
      current = formatter.formatEditUpdate(
        current,
        const TextEditingValue(text: '9', selection: TextSelection.collapsed(offset: 1)),
      );
      expect(current.text, '9');

      // 917
      current = formatter.formatEditUpdate(
        current,
        const TextEditingValue(text: '917', selection: TextSelection.collapsed(offset: 3)),
      );
      expect(current.text, '917');

      // 9171 -> 917 1
      current = formatter.formatEditUpdate(
        current,
        const TextEditingValue(text: '9171', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(current.text, '917 1');

      // 917123 -> 917 123
      current = formatter.formatEditUpdate(
        current,
        const TextEditingValue(text: '917 123', selection: TextSelection.collapsed(offset: 7)),
      );
      expect(current.text, '917 123');

      // 9171234 -> 917 123 4
      current = formatter.formatEditUpdate(
        current,
        const TextEditingValue(text: '917 1234', selection: TextSelection.collapsed(offset: 8)),
      );
      expect(current.text, '917 123 4');

      // 10 digits -> 917 123 4567
      current = formatter.formatEditUpdate(
        current,
        const TextEditingValue(
          text: '917 123 4567',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );
      expect(current.text, '917 123 4567');
    });

    test('caps at exactly 10 digits when 11th digit is entered', () {
      const oldValue = TextEditingValue(
        text: '917 123 4567',
        selection: TextSelection.collapsed(offset: 12),
      );
      const newValue = TextEditingValue(
        text: '917 123 45678',
        selection: TextSelection.collapsed(offset: 13),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '917 123 4567');
      expect(result.text.replaceAll(' ', '').length, 10);
    });

    test('handles pasted string with +63 prefix', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '+63 912 345 6789',
        selection: TextSelection.collapsed(offset: 16),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '912 345 6789');
    });
  });
}
