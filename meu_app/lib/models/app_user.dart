part of '../main.dart';

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    this.id,
  });

  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email.trim().toLowerCase(),
      'password_hash': passwordHash,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory AppUser.fromMap(Map<String, Object?> map) {
    final idValue = map['id'];

    return AppUser(
      id: idValue == null ? null : (idValue as num).toInt(),
      name: map['name'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}
