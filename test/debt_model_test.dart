import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/debts/models/debt_models.dart';

void main() {
  final now = DateTime(2026);

  Debt debt({
    int? id,
    String type = 'debt',
    String person = 'Budi',
    double principal = 500000,
    double remaining = 500000,
    String mode = 'note',
    String status = 'active',
    DateTime? due,
  }) =>
      Debt(
        id: id,
        type: type,
        personName: person,
        principalAmount: principal,
        remainingAmount: remaining,
        borrowedDate: now,
        dueDate: due,
        recordingMode: mode,
        status: status,
        createdDate: now,
        updatedDate: now,
      );

  group('Debt model computed properties', () {
    test('isOverdue true bila dueDate sudah lewat dan masih active', () {
      final item = debt(
        due: DateTime(2025, 1, 1),
        remaining: 100000,
        status: 'active',
      );
      expect(item.isOverdue, isTrue);
    });

    test('isOverdue false bila sudah settled', () {
      final item = debt(
        due: DateTime(2025, 1, 1),
        remaining: 0,
        status: 'settled',
      );
      expect(item.isOverdue, isFalse);
    });

    test('isOverdue false bila tidak ada dueDate', () {
      expect(debt().isOverdue, isFalse);
    });

    test('isOverdue false bila dueDate belum lewat', () {
      final item = debt(due: DateTime(2099, 12, 31), remaining: 100000);
      expect(item.isOverdue, isFalse);
    });

    test('progressFraction 0 saat baru dibuat', () {
      final item = debt(principal: 500000, remaining: 500000);
      expect(item.progressFraction, closeTo(0.0, 0.001));
    });

    test('progressFraction 0.6 saat 60% sudah dibayar', () {
      final item = debt(principal: 500000, remaining: 200000);
      expect(item.progressFraction, closeTo(0.6, 0.001));
    });

    test('progressFraction 1.0 saat lunas', () {
      final item = debt(principal: 500000, remaining: 0);
      expect(item.progressFraction, closeTo(1.0, 0.001));
    });
  });
}
