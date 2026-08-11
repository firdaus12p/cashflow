class WishlistItem {
  final int? id;
  final String name;
  final double price;
  final String emoji;
  final String? iconKey;
  final String priority;
  final DateTime createdDate;

  WishlistItem({
    this.id,
    required this.name,
    required this.price,
    this.emoji = '🛍️',
    this.iconKey,
    this.priority = 'medium',
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'emoji': emoji,
      'iconKey': iconKey,
      'priority': priority,
      'createdDate': createdDate.millisecondsSinceEpoch,
    };
  }

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    return WishlistItem(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      emoji: map['emoji'] ?? '🛍️',
      iconKey: map['iconKey'],
      priority: map['priority'] ?? 'medium',
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
    );
  }

  String get effectiveIcon => iconKey ?? emoji;
}
