import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';

class FinancialBucket {
  final int? id;
  final String name;
  final String? iconKey;
  final int? walletId;
  final double allocationPercentage;
  final double currentBalance;
  final bool isArchived;
  final DateTime createdDate;
  final DateTime updatedDate;

  FinancialBucket({
    this.id,
    required this.name,
    this.iconKey,
    this.walletId,
    this.allocationPercentage = 0,
    this.currentBalance = 0,
    this.isArchived = false,
    required this.createdDate,
    required this.updatedDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'walletId': walletId,
        'allocationPercentage': allocationPercentage,
        'currentBalance': currentBalance,
        'isArchived': isArchived ? 1 : 0,
        'createdDate': createdDate.millisecondsSinceEpoch,
        'updatedDate': updatedDate.millisecondsSinceEpoch,
      };

  factory FinancialBucket.fromMap(Map<String, dynamic> map) => FinancialBucket(
        id: map['id'],
        name: map['name'],
        iconKey: map['iconKey'],
        walletId: map['walletId'],
        allocationPercentage: map['allocationPercentage'] ?? 0,
        currentBalance: map['currentBalance'] ?? 0,
        isArchived: (map['isArchived'] ?? 0) == 1,
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
        updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updatedDate']),
      );

  IconData get resolvedIcon => resolveBucketIcon(iconKey);
}

class TransactionBucketAllocation {
  final int? id;
  final int transactionId;
  final int bucketId;
  final double normalizedPercentage;
  final double allocatedAmount;
  final String role;
  final DateTime createdDate;

  TransactionBucketAllocation({
    this.id,
    required this.transactionId,
    required this.bucketId,
    required this.normalizedPercentage,
    required this.allocatedAmount,
    required this.role,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'transactionId': transactionId,
        'bucketId': bucketId,
        'normalizedPercentage': normalizedPercentage,
        'allocatedAmount': allocatedAmount,
        'role': role,
        'createdDate': createdDate.millisecondsSinceEpoch,
      };

  factory TransactionBucketAllocation.fromMap(Map<String, dynamic> map) =>
      TransactionBucketAllocation(
        id: map['id'],
        transactionId: map['transactionId'],
        bucketId: map['bucketId'],
        normalizedPercentage: map['normalizedPercentage'],
        allocatedAmount: map['allocatedAmount'],
        role: map['role'],
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      );
}

class BucketTransfer {
  final int? id;
  final int fromBucketId;
  final int toBucketId;
  final int? fromWalletIdSnapshot;
  final int? toWalletIdSnapshot;
  final double amount;
  final String? note;
  final DateTime transferDate;
  final DateTime createdDate;

  BucketTransfer({
    this.id,
    required this.fromBucketId,
    required this.toBucketId,
    this.fromWalletIdSnapshot,
    this.toWalletIdSnapshot,
    required this.amount,
    this.note,
    required this.transferDate,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromBucketId': fromBucketId,
        'toBucketId': toBucketId,
        'fromWalletIdSnapshot': fromWalletIdSnapshot,
        'toWalletIdSnapshot': toWalletIdSnapshot,
        'amount': amount,
        'note': note,
        'transferDate': transferDate.millisecondsSinceEpoch,
        'createdDate': createdDate.millisecondsSinceEpoch,
      };

  factory BucketTransfer.fromMap(Map<String, dynamic> map) => BucketTransfer(
        id: map['id'],
        fromBucketId: map['fromBucketId'],
        toBucketId: map['toBucketId'],
        fromWalletIdSnapshot: map['fromWalletIdSnapshot'],
        toWalletIdSnapshot: map['toWalletIdSnapshot'],
        amount: map['amount'],
        note: map['note'],
        transferDate: DateTime.fromMillisecondsSinceEpoch(map['transferDate']),
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      );
}
