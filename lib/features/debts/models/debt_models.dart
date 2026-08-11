class Debt {
  final int? id;
  final String type;
  final String personName;
  final double principalAmount;
  final double remainingAmount;
  final DateTime borrowedDate;
  final DateTime? dueDate;
  final String recordingMode;
  final int? walletId;
  final int? bucketId;
  final String? note;
  final String status;
  final DateTime createdDate;
  final DateTime updatedDate;

  Debt({
    this.id,
    required this.type,
    required this.personName,
    required this.principalAmount,
    required this.remainingAmount,
    required this.borrowedDate,
    this.dueDate,
    required this.recordingMode,
    this.walletId,
    this.bucketId,
    this.note,
    this.status = 'active',
    required this.createdDate,
    required this.updatedDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'personName': personName,
        'principalAmount': principalAmount,
        'remainingAmount': remainingAmount,
        'borrowedDate': borrowedDate.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'recordingMode': recordingMode,
        'walletId': walletId,
        'bucketId': bucketId,
        'note': note,
        'status': status,
        'createdDate': createdDate.millisecondsSinceEpoch,
        'updatedDate': updatedDate.millisecondsSinceEpoch,
      };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'],
        type: map['type'],
        personName: map['personName'],
        principalAmount: map['principalAmount'],
        remainingAmount: map['remainingAmount'],
        borrowedDate: DateTime.fromMillisecondsSinceEpoch(map['borrowedDate']),
        dueDate: map['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
            : null,
        recordingMode: map['recordingMode'],
        walletId: map['walletId'],
        bucketId: map['bucketId'],
        note: map['note'],
        status: map['status'] ?? 'active',
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
        updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updatedDate']),
      );

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      remainingAmount > 0 &&
      status == 'active';

  double get progressFraction => principalAmount > 0
      ? ((principalAmount - remainingAmount) / principalAmount).clamp(0.0, 1.0)
      : 0.0;
}

class DebtPayment {
  final int? id;
  final int debtId;
  final double amount;
  final DateTime paymentDate;
  final String recordingMode;
  final int? walletId;
  final int? bucketId;
  final String? note;
  final DateTime createdDate;

  DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    required this.recordingMode,
    this.walletId,
    this.bucketId,
    this.note,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'debtId': debtId,
        'amount': amount,
        'paymentDate': paymentDate.millisecondsSinceEpoch,
        'recordingMode': recordingMode,
        'walletId': walletId,
        'bucketId': bucketId,
        'note': note,
        'createdDate': createdDate.millisecondsSinceEpoch,
      };

  factory DebtPayment.fromMap(Map<String, dynamic> map) => DebtPayment(
        id: map['id'],
        debtId: map['debtId'],
        amount: map['amount'],
        paymentDate: DateTime.fromMillisecondsSinceEpoch(map['paymentDate']),
        recordingMode: map['recordingMode'],
        walletId: map['walletId'],
        bucketId: map['bucketId'],
        note: map['note'],
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      );
}
