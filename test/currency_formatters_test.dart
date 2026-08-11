import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/core/formatters/currency_formatters.dart';

void main() {
  group('CurrencyInputFormatter', () {
    test('format menambahkan pemisah ribuan', () {
      expect(CurrencyInputFormatter.format(0), '0');
      expect(CurrencyInputFormatter.format(12000), '12.000');
      expect(CurrencyInputFormatter.format(1250000), '1.250.000');
    });

    test(
        'formatEditUpdate hanya menyisakan digit dan menggeser cursor ke akhir',
        () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '12a34',
        selection: TextSelection.collapsed(offset: 5),
      );

      final result = CurrencyInputFormatter().formatEditUpdate(
        oldValue,
        newValue,
      );

      expect(result.text, '1.234');
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('Rupiah parser dan formatter', () {
    test('tryParseCurrencyInput mengembalikan null bila tidak ada digit', () {
      expect(tryParseCurrencyInput(''), isNull);
      expect(tryParseCurrencyInput('Rp -'), isNull);
    });

    test('parseCurrencyInput fallback ke nol untuk input kosong', () {
      expect(parseCurrencyInput(''), 0);
      expect(parseCurrencyInput('Rp -'), 0);
    });

    test('parser dan formatter rupiah konsisten', () {
      expect(tryParseCurrencyInput('Rp 1.250.000'), 1250000);
      expect(formatRupiahValue(200000), '200.000');
      expect(formatRupiah(200000), 'Rp 200.000');
      expect(formatRupiah(1250000), 'Rp 1.250.000');
    });
  });
}
