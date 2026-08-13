import 'package:flutter/material.dart';

const double bucketPercentageTolerance = 0.01;

class AppPalette {
  static const Color background = Color(0xFFFFFBF2);
  static const Color backgroundTint = Color(0xFFE4F7FF);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3FAFF);
  static const Color surfaceDisabled = Color(0xFFF6F7F9);
  static const Color border = Color(0xFFD7E8F5);

  static const Color primary = Color(0xFF1F6FA8);
  static const Color primaryDark = Color(0xFF1C628F);
  static const Color accent = Color(0xFF39C5A4);
  static const Color accentSoft = Color(0xFFDDF9F1);
  static const Color warmAccent = Color(0xFFFFC85C);

  static const Color textPrimary = Color(0xFF2D4B66);
  static const Color textSecondary = Color(0xFF5F758A);
  static const Color textMuted = Color(0xFFA7BBCB);

  static const Color success = Color(0xFF2FBB6C);
  static const Color successLight = Color(0xFF8CDEAF);
  static const Color danger = Color(0xFFF0726B);
  static const Color warning = Color(0xFFF6BC4B);
  static const Color info = Color(0xFF62B7E8);

  static const Color badgeStart = Color(0xFFFFD76C);
  static const Color badgeEnd = Color(0xFFFFB85A);
  static const Color chartSlate = Color(0xFF7FAEE0);
  static const Color chartWarm = Color(0xFFFF9E7A);
  static const Color chartNeutral = Color(0xFF90A6BA);

  static const List<Color> backgroundGradient = [backgroundTint, background];
  static const List<Color> heroGradient = [
    Color(0xFF1F6FA8),
    Color(0xFF197F8A),
  ];
  static const List<Color> badgeGradient = [badgeStart, badgeEnd];
  static const List<Color> lineChartGradient = [primary, info, accent];
  static const List<Color> goalCompleteGradient = [success, successLight];
  static const List<Color> categoryChartColors = [
    primary,
    accent,
    successLight,
    warmAccent,
    chartWarm,
    chartSlate,
    chartNeutral,
  ];
}

const String bucketConfigurationIncompleteText = 'Pos keuangan belum 100%';
const String bucketConfigurationIncompleteMessage =
    'Pos keuangan belum 100%. Selesaikan dulu di halaman Pos Keuangan.';
const String insufficientBalanceMessage = 'Saldo anda kurang';
const String internalTransferCategory = 'Transfer Internal';

const String homeBalanceSourceTypePreferenceKey = 'homeBalanceSourceType';
const String homeBalanceSourceIdPreferenceKey = 'homeBalanceSourceId';
const String homeBalanceVisibilityHiddenPreferenceKey =
    'homeBalanceVisibilityHidden';
const String bucketSystemEnabledPreferenceKey = 'bucketSystemEnabled';

const String reminderEnabledPreferenceKey = 'reminderEnabled';
const String reminderHourPreferenceKey = 'reminderHour';
const String reminderEveningStartHourPreferenceKey = 'reminderEveningStartHour';
const String reminderLastAppOpenedAtPreferenceKey = 'reminderLastAppOpenedAt';
const String reminderLastFinancialActivityAtPreferenceKey =
    'reminderLastFinancialActivityAt';
