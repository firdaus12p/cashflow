import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_constants.dart';

class CashflowApp extends StatelessWidget {
  const CashflowApp({super.key, required this.home});

  final Widget home;
  static bool _fontLicenseRegistered = false;

  @override
  Widget build(BuildContext context) {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (!_fontLicenseRegistered) {
      LicenseRegistry.addLicense(() async* {
        final license = await rootBundle.loadString('assets/fonts/OFL.txt');
        yield LicenseEntryWithLineBreaks(['Poppins'], license);
      });
      _fontLicenseRegistered = true;
    }
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      secondary: AppPalette.accent,
      onSecondary: Colors.white,
      surface: AppPalette.surface,
      onSurface: AppPalette.textPrimary,
      error: AppPalette.danger,
      onError: Colors.white,
      outline: AppPalette.border,
    );

    return MaterialApp(
      title: 'cashflow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        primaryColor: AppPalette.primary,
        fontFamily: GoogleFonts.poppins().fontFamily,
        scaffoldBackgroundColor: AppPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardColor: AppPalette.surface,
        dialogTheme: DialogThemeData(
          backgroundColor: AppPalette.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppPalette.surface,
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppPalette.primaryDark,
          contentTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.surfaceMuted,
          hintStyle: GoogleFonts.poppins(color: AppPalette.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppPalette.primary, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppPalette.surface,
          selectedColor: AppPalette.primary,
          secondarySelectedColor: AppPalette.primary,
          disabledColor: AppPalette.surfaceDisabled,
          labelStyle: GoogleFonts.poppins(color: AppPalette.textPrimary),
          secondaryLabelStyle: GoogleFonts.poppins(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.border),
          ),
        ),
      ),
      home: home,
    );
  }
}
