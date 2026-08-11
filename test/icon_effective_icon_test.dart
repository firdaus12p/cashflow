import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/badges/models/user_badge.dart';
import 'package:cashflow/features/goals/models/saving_goal.dart';
import 'package:cashflow/features/wishlist/models/wishlist_item.dart';

void main() {
  group('SavingGoal.effectiveIcon fallback', () {
    test('returns iconKey when set', () {
      final goal = SavingGoal(
        name: 'Liburan',
        targetAmount: 5000000,
        emoji: '✈️',
        iconKey: 'flight',
        createdDate: DateTime(2026, 1, 1),
      );

      expect(goal.effectiveIcon, 'flight');
    });

    test('falls back to emoji when iconKey is null', () {
      final goal = SavingGoal(
        name: 'Liburan',
        targetAmount: 5000000,
        emoji: '✈️',
        createdDate: DateTime(2026, 1, 1),
      );

      expect(goal.effectiveIcon, '✈️');
    });

    test('fromMap with null iconKey falls back to emoji', () {
      final map = {
        'id': 1,
        'name': 'Dana Darurat',
        'targetAmount': 10000000.0,
        'currentAmount': 2000000.0,
        'emoji': '🛡️',
        'iconKey': null,
        'createdDate': DateTime(2025, 6, 1).millisecondsSinceEpoch,
        'targetDate': null,
      };
      final goal = SavingGoal.fromMap(map);

      expect(goal.effectiveIcon, '🛡️');
    });

    test('fromMap with iconKey set returns iconKey', () {
      final map = {
        'id': 2,
        'name': 'Rumah',
        'targetAmount': 500000000.0,
        'currentAmount': 0.0,
        'emoji': '🏠',
        'iconKey': 'home',
        'createdDate': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'targetDate': null,
      };
      final goal = SavingGoal.fromMap(map);

      expect(goal.effectiveIcon, 'home');
    });
  });

  group('WishlistItem.effectiveIcon fallback', () {
    test('returns iconKey when set', () {
      final item = WishlistItem(
        name: 'Laptop',
        price: 15000000,
        emoji: '💻',
        iconKey: 'laptop',
        createdDate: DateTime(2026, 1, 1),
      );

      expect(item.effectiveIcon, 'laptop');
    });

    test('falls back to emoji when iconKey is null', () {
      final item = WishlistItem(
        name: 'Sepatu',
        price: 500000,
        emoji: '👟',
        createdDate: DateTime(2026, 1, 1),
      );

      expect(item.effectiveIcon, '👟');
    });

    test('fromMap with null iconKey falls back to emoji', () {
      final map = {
        'id': 1,
        'name': 'Tas',
        'price': 800000.0,
        'emoji': '👜',
        'iconKey': null,
        'priority': 'high',
        'createdDate': DateTime(2025, 9, 1).millisecondsSinceEpoch,
      };
      final item = WishlistItem.fromMap(map);

      expect(item.effectiveIcon, '👜');
    });
  });

  group('UserBadge.effectiveIcon fallback', () {
    test('returns iconKey when set', () {
      final badge = UserBadge(
        name: 'Hemat Bulan Ini',
        description: 'Berhasil hemat',
        emoji: '🏆',
        iconKey: 'emoji_events',
        earnedDate: DateTime(2026, 1, 1),
        type: 'saving',
      );

      expect(badge.effectiveIcon, 'emoji_events');
    });

    test('falls back to emoji when iconKey is null', () {
      final badge = UserBadge(
        name: 'Hemat',
        description: 'Hemat',
        emoji: '🏆',
        earnedDate: DateTime(2026, 1, 1),
        type: 'saving',
      );

      expect(badge.effectiveIcon, '🏆');
    });

    test('fromMap with null iconKey falls back to emoji', () {
      final map = {
        'id': 1,
        'name': 'Juara Hemat',
        'description': 'Berhasil',
        'emoji': '⭐',
        'iconKey': null,
        'earnedDate': DateTime(2025, 8, 1).millisecondsSinceEpoch,
        'type': 'saving',
      };
      final badge = UserBadge.fromMap(map);

      expect(badge.effectiveIcon, '⭐');
    });
  });
}
