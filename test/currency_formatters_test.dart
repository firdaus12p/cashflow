import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/core/formatters/currency_formatters.dart';

void main() {
  group('CurrencyInputFormatter', () {
    test('input terlalu besar mempertahankan nilai dan cursor sebelumnya', () {
      const previous = TextEditingValue(
        text: '12.000',
        selection: TextSelection.collapsed(offset: 2),
      );
      for (final text in ['9007199254740992', '9' * 400]) {
        expect(
          CurrencyInputFormatter().formatEditUpdate(
            previous,
            TextEditingValue(text: text),
          ),
          previous,
        );
        expect(tryParseCurrencyInput(text), isNull);
      }
    });

    test('batas integer tepat dan nol di depan ditangani konsisten', () {
      expect(tryParseCurrencyInput('9.007.199.254.740.991'), 9007199254740991);
      expect(tryParseCurrencyInput('${'0' * 30}123'), 123);
      expect(tryParseCurrencyInput('000'), 0);
    });

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

    test('formatEditUpdate mereset cursor saat semua digit terhapus', () {
      const oldValue = TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      );
      const newValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = CurrencyInputFormatter().formatEditUpdate(
        oldValue,
        newValue,
      );

      expect(result.text, '');
      expect(result.selection, const TextSelection.collapsed(offset: 0));
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

    test('validasi saldo konsisten dengan unit rupiah yang ditampilkan', () {
      expect(hasSufficientRupiahBalance(2537213.6, 2537214), isTrue);
      expect(hasSufficientRupiahBalance(2537213.4, 2537214), isFalse);
      expect(compareRupiahAmount(100.49, 100.4), 0);
      expect(normalizeRupiahAmount(999.6), 1000.0);
    });
  });
}
