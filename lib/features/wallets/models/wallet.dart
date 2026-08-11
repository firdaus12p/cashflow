class Wallet {
  final int? id;
  final String name;
  final String? iconKey;
  final String? color;
  final bool isArchived;
  final DateTime createdDate;
  final DateTime updatedDate;

  Wallet({
    this.id,
    required this.name,
    this.iconKey,
    this.color,
    this.isArchived = false,
    required this.createdDate,
    required this.updatedDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'color': color,
        'isArchived': isArchived ? 1 : 0,
        'createdDate': createdDate.millisecondsSinceEpoch,
        'updatedDate': updatedDate.millisecondsSinceEpoch,
      };

  factory Wallet.fromMap(Map<String, dynamic> map) => Wallet(
        id: map['id'],
        name: map['name'],
        iconKey: map['iconKey'],
        color: map['color'],
        isArchived: (map['isArchived'] ?? 0) == 1,
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
        updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updatedDate']),
      );
}
