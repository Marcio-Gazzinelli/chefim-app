part of '../main.dart';

/// Ingrediente informado por uma receita, independentemente de sua origem.
class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity,
    this.unit = '',
    this.optional = false,
    this.aliases = const [],
  });

  final String name;
  final double? quantity;
  final String unit;
  final bool optional;
  final List<String> aliases;

  factory RecipeIngredient.fromMap(Map<String, Object?> map) {
    return RecipeIngredient(
      name: _readText(map['nome'] ?? map['name']) ?? '',
      quantity: _readNumber(map['qtd'] ?? map['quantidade'] ?? map['quantity']),
      unit: _readText(map['un'] ?? map['unidade'] ?? map['unit']) ?? '',
      optional: _readBool(map['opcional'] ?? map['optional']),
      aliases: _readStringList(map['aliases'] ?? map['apelidos']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nome': name,
      'qtd': quantity,
      'un': unit,
      'opcional': optional,
      if (aliases.isNotEmpty) 'aliases': aliases,
    };
  }

  Iterable<String> get searchTerms sync* {
    yield name;
    yield* aliases;
  }

  String get quantityLabel {
    final value = quantity;

    if (value == null) {
      return unit.trim().isEmpty ? name : '${unit.trim()} de $name';
    }

    final amount = _formatAmount(value);
    final normalizedUnit = unit.trim();

    if (normalizedUnit.isEmpty) {
      return '$amount de $name';
    }

    return '$amount $normalizedUnit de $name';
  }

  static String? _readText(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static double? _readNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    final text = value?.toString().trim().replaceAll(',', '.');

    return text == null || text.isEmpty ? null : double.tryParse(text);
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value?.toString().trim().toLowerCase();

    return text == 'true' || text == '1' || text == 'sim' || text == 'yes';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

/// Formato único utilizado pela tela, pelas sugestões e pelo OpenRouter.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.preparationMinutes,
    required this.ingredients,
    required this.steps,
    this.description,
    this.source,
  });

  final String id;
  final String name;
  final String? description;
  final int servings;
  final int preparationMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String? source;

  /// Converte uma lista direta ou uma resposta:
  ///
  /// `{ "receitas": [...] }`
  static List<Recipe> listFromResponse(Object? value) {
    Object? rows = value;

    if (value is Map) {
      rows = value['receitas'] ?? value['recipes'];
    }

    if (rows is! List) {
      return const [];
    }

    return rows
        .whereType<Map>()
        .map((row) => Recipe.fromMap(Map<String, Object?>.from(row)))
        .where((recipe) => recipe.ingredients.isNotEmpty)
        .toList(growable: false);
  }

  factory Recipe.fromMap(Map<String, Object?> map) {
    final name = _readText(map['nome'] ?? map['name']) ?? 'Receita';

    return Recipe(
      id: _readText(map['id']) ?? _createId(name),
      name: name,
      description: _readText(map['descricao'] ?? map['description']),
      servings: _readInteger(map['porcoes'] ?? map['servings'], fallback: 1),
      preparationMinutes: _readInteger(
        map['tempo_minutos'] ??
            map['preparation_minutes'] ??
            map['preparationMinutes'],
        fallback: 0,
      ),
      ingredients: _readIngredients(map['ingredientes'] ?? map['ingredients']),
      steps: _readSteps(map['modo_preparo'] ?? map['steps'] ?? map['preparo']),
      source: _readText(map['fonte'] ?? map['source']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nome': name,
      'descricao': description,
      'porcoes': servings,
      'tempo_minutos': preparationMinutes,
      'ingredientes': ingredients
          .map((ingredient) => ingredient.toMap())
          .toList(),
      'modo_preparo': steps,
      'fonte': source,
    };
  }

  static List<RecipeIngredient> _readIngredients(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => RecipeIngredient.fromMap(Map<String, Object?>.from(item)),
        )
        .where((ingredient) => ingredient.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _readSteps(Object? value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final text = _readText(value);

    if (text == null) {
      return const [];
    }

    return text
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _readText(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static int _readInteger(Object? value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static String _createId(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return normalized.isEmpty ? 'receita' : normalized;
  }
}

/// Resultado da comparação entre uma receita e a despensa.
class RecipeSuggestion {
  const RecipeSuggestion({
    required this.recipe,
    required this.matchedIngredients,
    required this.missingIngredients,
    required this.expiringProducts,
    required this.requiredIngredientCount,
    required this.matchedRequiredIngredientCount,
    required this.score,
  });

  final Recipe recipe;
  final List<RecipeIngredient> matchedIngredients;
  final List<RecipeIngredient> missingIngredients;
  final List<Product> expiringProducts;
  final int requiredIngredientCount;
  final int matchedRequiredIngredientCount;
  final double score;

  bool get canPrepare => missingIngredients.isEmpty;

  double get compatibility {
    if (requiredIngredientCount == 0) {
      return 1;
    }

    return matchedRequiredIngredientCount / requiredIngredientCount;
  }

  int get compatibilityPercent {
    return (compatibility * 100).round();
  }
}

/// Contrato que o serviço do OpenRouter poderá implementar.
///
/// A classificação personalizada não depende do modelo de IA utilizado.
abstract interface class RecipeProvider {
  Future<List<Recipe>> generateRecipes({required List<Product> products});
}
