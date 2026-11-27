part of '../main.dart';

class SavedRecipe {
  const SavedRecipe({
    this.id,
    required this.userId,
    required this.recipe,
    required this.createdAt,
  });

  final int? id;
  final int? userId;
  final AiGeneratedRecipe recipe;
  final DateTime createdAt;

  factory SavedRecipe.fromMap(Map<String, Object?> map) {
    final decodedRecipe = jsonDecode(map['recipe_json'] as String);

    if (decodedRecipe is! Map) {
      throw const FormatException('Receita salva em formato inválido.');
    }

    return SavedRecipe(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num?)?.toInt(),
      recipe: AiGeneratedRecipe.fromJson(
        Map<String, dynamic>.from(decodedRecipe),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': recipe.name.trim(),
      'recipe_json': jsonEncode(recipe.toJson()),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  SavedRecipe copyWith({
    int? id,
    int? userId,
    AiGeneratedRecipe? recipe,
    DateTime? createdAt,
  }) {
    return SavedRecipe(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipe: recipe ?? this.recipe,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
