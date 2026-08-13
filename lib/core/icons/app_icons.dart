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

const Map<String, IconData> availableGoalIcons = {
  'savings': Icons.savings_outlined,
  'flag': Icons.flag_outlined,
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
  'phone': Icons.phone_iphone_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'game': Icons.sports_esports_outlined,
  'book': Icons.menu_book_outlined,
  'flight': Icons.flight_takeoff_outlined,
  'favorite': Icons.favorite_outline,
};

const Map<String, IconData> availableWishlistIcons = {
  'shopping': Icons.shopping_bag_outlined,
  'apparel': Icons.checkroom_outlined,
  'shoe': Icons.shopping_bag_outlined,
  'beauty': Icons.auto_awesome_outlined,
  'phone': Icons.phone_iphone_outlined,
  'laptop': Icons.laptop_mac_outlined,
  'game': Icons.sports_esports_outlined,
  'book': Icons.menu_book_outlined,
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
};

const Map<String, IconData> availableBadgeIcons = {
  'star': Icons.star_outline_rounded,
  'trophy': Icons.emoji_events_outlined,
  'goal': Icons.flag_outlined,
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

IconData resolveGoalIcon(String? iconKey) {
  if (iconKey != null && availableGoalIcons.containsKey(iconKey)) {
    return availableGoalIcons[iconKey]!;
  }
  return Icons.savings_outlined;
}

IconData resolveWishlistIcon(String? iconKey) {
  if (iconKey != null && availableWishlistIcons.containsKey(iconKey)) {
    return availableWishlistIcons[iconKey]!;
  }
  return Icons.shopping_bag_outlined;
}

IconData resolveBadgeIcon(String? iconKey) {
  if (iconKey != null && availableBadgeIcons.containsKey(iconKey)) {
    return availableBadgeIcons[iconKey]!;
  }
  return Icons.emoji_events_outlined;
}
