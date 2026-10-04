import 'package:cashflow/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
      'OPS02 real bundled Poppins weights load with network fetching disabled',
      (tester) async {
    await tester
        .pumpWidget(const CashflowApp(home: Scaffold(body: Text('Cashflow'))));
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    await tester.runAsync(() async {
      for (final entry in {
        FontWeight.w400: 'Regular',
        FontWeight.w500: 'Medium',
        FontWeight.w600: 'SemiBold',
        FontWeight.w700: 'Bold',
      }.entries) {
        final bytes =
            await rootBundle.load('assets/fonts/Poppins-${entry.value}.ttf');
        expect(bytes.lengthInBytes, greaterThan(100000));
        expect(bytes.getUint32(0), 0x00010000);
        final style = GoogleFonts.poppins(fontWeight: entry.key);
        await GoogleFonts.pendingFonts([style]);
      }
      final license = await rootBundle.loadString('assets/fonts/OFL.txt');
      expect(license, contains('Copyright 2020 The Poppins Project Authors'));
      expect(license, contains('SIL OPEN FONT LICENSE Version 1.1'));
      final registered = await LicenseRegistry.licenses
          .where((entry) => entry.packages.contains('Poppins'))
          .toList();
      expect(registered, hasLength(1));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
