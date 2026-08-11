import 'package:flutter/material.dart';

const Map<String, IconData> availableWalletIcons = {
  'cash': Icons.payments_outlined,
  'e_wallet': Icons.phone_android_outlined,
  'bank': Icons.account_balance_outlined,
  'savings': Icons.savings_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'card': Icons.credit_card_outlined,
};

const Map<String, IconData> availableBucketIcons = {
  'savings': Icons.savings_outlined,
  'giving': Icons.volunteer_activism_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'health': Icons.health_and_safety_outlined,
  'home': Icons.home_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'chart': Icons.pie_chart_outline,
};

IconData resolveWalletIcon(String? iconKey, String fallbackName) {
  if (iconKey != null && availableWalletIcons.containsKey(iconKey)) {
    return availableWalletIcons[iconKey]!;
  }

  switch (fallbackName) {
    case 'Cash':
      return Icons.payments_outlined;
    case 'E-Wallet':
      return Icons.phone_android_outlined;
    case 'Bank':
      return Icons.account_balance_outlined;
    case 'Tabungan':
      return Icons.savings_outlined;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

IconData resolveBucketIcon(String? iconKey) {
  if (iconKey != null && availableBucketIcons.containsKey(iconKey)) {
    return availableBucketIcons[iconKey]!;
  }
  return Icons.pie_chart_outline;
}
