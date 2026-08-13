import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';

class UserBadge {
  final int? id;
  final String name;
  final String description;
  final String emoji;
  final String? iconKey;
  final DateTime earnedDate;
  final String type;

  UserBadge({
    this.id,
    required this.name,
    required this.description,
    required this.emoji,
    this.iconKey,
    required this.earnedDate,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'iconKey': iconKey,
      'earnedDate': earnedDate.millisecondsSinceEpoch,
      'type': type,
    };
  }

  factory UserBadge.fromMap(Map<String, dynamic> map) {
    return UserBadge(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      emoji: map['emoji'],
      iconKey: map['iconKey'],
      earnedDate: DateTime.fromMillisecondsSinceEpoch(map['earnedDate']),
      type: map['type'],
    );
  }

  String get effectiveIcon => iconKey ?? emoji;

  IconData get resolvedIcon => resolveBadgeIcon(iconKey);
}
