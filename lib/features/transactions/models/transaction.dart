class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String wallet;
  final int? walletId;
  final String walletNameSnapshot;
  final bool affectsBalance;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.wallet = 'Cash',
    this.walletId,
    this.walletNameSnapshot = '',
    this.affectsBalance = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'wallet': wallet,
      'walletId': walletId,
      'walletNameSnapshot': walletNameSnapshot,
      'affectsBalance': affectsBalance ? 1 : 0,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      category: map['category'],
      description: map['description'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      wallet: map['wallet'] ?? 'Cash',
      walletId: map['walletId'],
      walletNameSnapshot: map['walletNameSnapshot'] ?? '',
      affectsBalance: (map['affectsBalance'] ?? 1) == 1,
    );
  }
}
