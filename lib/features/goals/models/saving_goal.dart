class SavingGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String emoji;
  final String? iconKey;
  final DateTime createdDate;
  final DateTime? targetDate;

  SavingGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.emoji = '💰',
    this.iconKey,
    required this.createdDate,
    this.targetDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'emoji': emoji,
      'iconKey': iconKey,
      'createdDate': createdDate.millisecondsSinceEpoch,
      'targetDate': targetDate?.millisecondsSinceEpoch,
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'],
      name: map['name'],
      targetAmount: map['targetAmount'],
      currentAmount: map['currentAmount'] ?? 0,
      emoji: map['emoji'] ?? '💰',
      iconKey: map['iconKey'],
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      targetDate: map['targetDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'])
          : null,
    );
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  String get effectiveIcon => iconKey ?? emoji;
}
