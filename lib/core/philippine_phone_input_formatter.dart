import 'package:flutter/services.dart';

/// Custom [TextInputFormatter] for Philippine mobile numbers.
///
/// Rules enforced:
/// 1. Only digits are accepted. Non-digit characters (except formatting spaces) are rejected.
/// 2. Non-9 starting digits (other than a temporary 0 leading to 09) are blocked.
/// 3. A temporary leading '0' is permitted when entering 09.
/// 4. As soon as '09' is entered (either typed or pasted), the leading '0' is stripped,
///    leaving '9' and triggering [onZeroStripped].
/// 5. Total number of digits is strictly capped at 10 digits starting with 9.
/// 6. Formatted display follows '9XX XXX XXXX' (3-3-4 group spacing).
class PhilippinePhoneInputFormatter extends TextInputFormatter {
  PhilippinePhoneInputFormatter({this.onZeroStripped});

  /// Callback fired when a leading '0' is automatically stripped upon entering '09'.
  final VoidCallback? onZeroStripped;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;

    // 1. If text is cleared, allow empty
    if (newText.isEmpty) {
      return newValue;
    }

    // 2. Disallow any non-digit input characters (reject if user typed letters/symbols)
    final hasDisallowedChars = RegExp(r'[^\d\s\+\-\(\)]').hasMatch(newText);
    if (hasDisallowedChars) {
      return oldValue;
    }

    // 3. Extract pure digits
    String digits = newText.replaceAll(RegExp(r'\D'), '');

    // If no digits remain, allow empty
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // If pasted with country code +63 or 63, strip 63
    if (digits.startsWith('63') && digits.length > 2) {
      digits = digits.substring(2);
    }

    // 4. Handle temporary single '0'
    if (digits == '0') {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    // 5. Handle '09' entry (typed or pasted)
    bool zeroStripped = false;
    if (digits.startsWith('09')) {
      digits = digits.substring(1);
      zeroStripped = true;
    } else if (digits.startsWith('0')) {
      // Any 0 followed by something other than 9 is blocked
      return oldValue;
    }

    // 6. Strict enforcement: first digit MUST be 9
    if (!digits.startsWith('9')) {
      return oldValue;
    }

    // 7. Strict 10-digit capping
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (zeroStripped) {
      onZeroStripped?.call();
    }

    // 8. Format as 9XX XXX XXXX
    final formatted = formatDigits(digits);

    // 9. Calculate cursor position
    final selectionOffset = _calculateCursorOffset(
      newValue: newValue,
      digits: digits,
      formatted: formatted,
      zeroStripped: zeroStripped,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }

  /// Formats raw digits (1 to 10 characters) as 9XX XXX XXXX.
  static String formatDigits(String digits) {
    final pure = digits.replaceAll(RegExp(r'\D'), '');
    if (pure.length <= 3) {
      return pure;
    } else if (pure.length <= 6) {
      return '${pure.substring(0, 3)} ${pure.substring(3)}';
    } else {
      final capped = pure.length > 10 ? pure.substring(0, 10) : pure;
      return '${capped.substring(0, 3)} ${capped.substring(3, 6)} ${capped.substring(6)}';
    }
  }

  /// Calculates the corresponding cursor offset in [formatted] string.
  static int _calculateCursorOffset({
    required TextEditingValue newValue,
    required String digits,
    required String formatted,
    required bool zeroStripped,
  }) {
    final targetEnd = newValue.selection.end.clamp(0, newValue.text.length);
    int digitsBeforeCursor = 0;
    for (int i = 0; i < targetEnd; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    if (zeroStripped && digitsBeforeCursor > 0) {
      digitsBeforeCursor--;
    }

    digitsBeforeCursor = digitsBeforeCursor.clamp(0, digits.length);

    int countedDigits = 0;
    int formattedOffset = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (countedDigits == digitsBeforeCursor) {
        formattedOffset = i;
        break;
      }
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        countedDigits++;
      }
      formattedOffset = i + 1;
    }

    return formattedOffset.clamp(0, formatted.length);
  }
}
