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
    final formatted = CurrencyInputFormatter.format(int.parse(digits));
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
  return double.tryParse(digits);
}

final NumberFormat _rupiahNumberFormatter =
    NumberFormat.decimalPattern('id_ID');

String formatRupiahValue(num amount) {
  return _rupiahNumberFormatter.format(amount.round());
}

String formatRupiah(num amount) {
  return 'Rp ${formatRupiahValue(amount)}';
}
