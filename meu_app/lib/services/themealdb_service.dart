part of '../main.dart';

class TheMealDbSummary {
  const TheMealDbSummary({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;
  final String? imageUrl;
}

class TheMealDbService {
  TheMealDbService._();

  static final TheMealDbService instance = TheMealDbService._();

  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Busca receitas que contêm um ingrediente.
  ///
  /// A API V1 aceita um ingrediente por consulta.
  Future<List<TheMealDbSummary>> searchByIngredient(String ingredient) async {
    final search = ingredient.trim();

    if (search.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$_baseUrl/filter.php')
        .replace(queryParameters: {'i': search});

    final data = await _getJson(uri);
    final meals = data['meals'];

    if (meals == null) {
      return [];
    }

    if (meals is! List) {
      throw const FormatException('Lista de receitas em formato inválido.');
    }

    return meals
        .whereType<Map>()
        .map((meal) {
          return TheMealDbSummary(
            id: (meal['idMeal'] ?? '').toString(),
            name: (meal['strMeal'] ?? '').toString(),
            imageUrl: meal['strMealThumb']?.toString(),
          );
        })
        .where((meal) {
          return meal.id.isNotEmpty && meal.name.isNotEmpty;
        })
        .toList(growable: false);
  }

  /// Obtém os detalhes de uma receita pelo ID.
  Future<Recipe?> getRecipeById(String id) async {
    final mealId = id.trim();

    if (mealId.isEmpty) {
      throw ArgumentError('O ID da receita não pode ser vazio.');
    }

    final uri = Uri.parse('$_baseUrl/lookup.php')
        .replace(queryParameters: {'i': mealId});

    final data = await _getJson(uri);
    final meals = data['meals'];

    if (meals == null || meals is List && meals.isEmpty) {
      return null;
    }

    if (meals is! List || meals.first is! Map) {
      throw const FormatException('Detalhes da receita em formato inválido.');
    }

    final meal = meals.first as Map;

    final ingredients = <RecipeIngredient>[];

    for (var i = 1; i <= 20; i++) {
      final name = (meal['strIngredient$i'] ?? '').toString().trim();
      final measure = (meal['strMeasure$i'] ?? '').toString().trim();

      if (name.isEmpty) {
        continue;
      }

      // A medida original fica preservada temporariamente.
      // A conversão para g, ml e unidades será feita
      // posteriormente pelo normalizador culinário.
      ingredients.add(RecipeIngredient(name: name, unit: measure));
    }

    final instructions = (meal['strInstructions'] ?? '').toString().trim();

    final steps = instructions
        .split(RegExp(r'\r?\n'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList(growable: false);

    return Recipe(
      id: 'themealdb_${meal['idMeal'] ?? mealId}',
      name: (meal['strMeal'] ?? 'Receita').toString(),
      servings: 0, // Rendimento original não informado.
      preparationMinutes: 0, // Tempo não informado.
      ingredients: ingredients,
      steps: steps,
      source: 'TheMealDB',
    );
  }

  /// Busca receitas para vários ingredientes,
  /// removendo resultados repetidos pelo ID.
  Future<List<TheMealDbSummary>> searchByIngredients(
    List<String> ingredients,
  ) async {
    final uniqueIngredients = ingredients
        .map((ingredient) => ingredient.trim().toLowerCase())
        .where((ingredient) => ingredient.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueIngredients.isEmpty) {
      return [];
    }

    // As consultas são executadas concorrentemente.
    final results = await Future.wait(
      uniqueIngredients.map(searchByIngredient),
    );

    // Um mesmo ID deve aparecer apenas uma vez.
    final uniqueRecipes = <String, TheMealDbSummary>{};

    for (final recipes in results) {
      for (final recipe in recipes) {
        uniqueRecipes.putIfAbsent(recipe.id, () => recipe);
      }
    }

    return uniqueRecipes.values.toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Erro na TheMealDB: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida da TheMealDB.');
    }

    return decoded;
  }

  // Cache temporário de pesquisas e detalhes de receitas.
  final Map<String, Future<List<TheMealDbSummary>>> _ingredientSearchCache = {};

  final Map<String, Future<Recipe?>> _recipeDetailsCache = {};

  /// Pesquisa ingredientes reutilizando resultados anteriores.
  Future<List<TheMealDbSummary>> searchByIngredientsCached(
    List<String> ingredients,
  ) async {
    final normalizedTerms =
        ingredients
            .map((term) => term.trim().toLowerCase())
            .where((term) => term.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (normalizedTerms.isEmpty) {
      return [];
    }

    final cacheKey = normalizedTerms.join('|');

    final cached = _ingredientSearchCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final request = searchByIngredients(normalizedTerms);

    _ingredientSearchCache[cacheKey] = request;

    try {
      return await request;
    } catch (_) {
      // Não armazena uma requisição que falhou.
      if (identical(_ingredientSearchCache[cacheKey], request)) {
        _ingredientSearchCache.remove(cacheKey);
      }
      rethrow;
    }
  }

  /// Consulta os detalhes de uma receita,
  /// evitando repetir requisições para o mesmo ID.
  Future<Recipe?> getRecipeByIdCached(String id) async {
    final recipeId = id.trim();

    if (recipeId.isEmpty) {
      return null;
    }

    final cached = _recipeDetailsCache[recipeId];

    if (cached != null) {
      return cached;
    }

    final request = getRecipeById(recipeId);

    _recipeDetailsCache[recipeId] = request;

    try {
      final recipe = await request;

      // Se a API não encontrou a receita, permitimos
      // que uma próxima pesquisa tente novamente.
      if (recipe == null && identical(_recipeDetailsCache[recipeId], request)) {
        _recipeDetailsCache.remove(recipeId);
      }

      return recipe;
    } catch (_) {
      // Erros e timeouts não ficam armazenados.
      if (identical(_recipeDetailsCache[recipeId], request)) {
        _recipeDetailsCache.remove(recipeId);
      }
      rethrow;
    }
  }

  /// Permite limpar o cache quando necessário.
  void clearCache() {
    _ingredientSearchCache.clear();
    _recipeDetailsCache.clear();
  }
}
