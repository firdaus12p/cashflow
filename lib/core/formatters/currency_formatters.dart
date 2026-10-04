import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  static String format(int value) {
    final reversed = value.toString().split('').reversed.toList();
    final result = <String>[];
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) result.add('.');
      result.add(reversed[i]);
    }
    return result.reversed.join();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final amount = tryParseCurrencyInput(digits);
    if (amount == null) return oldValue;
    final formatted = CurrencyInputFormatter.format(amount.toInt());
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

double parseCurrencyInput(String input) {
  return tryParseCurrencyInput(input) ?? 0;
}

double? tryParseCurrencyInput(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return null;
  final significant = digits.replaceFirst(RegExp(r'^0+'), '');
  if (significant.isEmpty) return 0;
  // SQLite REAL and Dart double preserve integer rupiah exactly up to 2^53 - 1.
  if (significant.length > 16) return null;
  final amount = int.tryParse(significant);
  if (amount == null || amount > 9007199254740991) return null;
  return amount.toDouble();
}

int rupiahUnits(num amount) {
  if (!amount.isFinite) return 0;
  return amount.round();
}

double normalizeRupiahAmount(num amount) {
  return rupiahUnits(amount).toDouble();
}

int compareRupiahAmount(num left, num right) {
  return rupiahUnits(left).compareTo(rupiahUnits(right));
}

bool hasSufficientRupiahBalance(num balance, num amount) {
  return compareRupiahAmount(balance, amount) >= 0;
}

final NumberFormat _rupiahNumberFormatter =
    NumberFormat.decimalPattern('id_ID');

String formatRupiahValue(num amount) {
  return _rupiahNumberFormatter.format(rupiahUnits(amount));
}

String formatRupiah(num amount) {
  return 'Rp ${formatRupiahValue(amount)}';
}
