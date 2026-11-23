part of '../main.dart';

class TheMealDbRankedRecipe {
  const TheMealDbRankedRecipe({
    required this.recipe,
    required this.matchedIngredients,
    required this.extraIngredients,
    required this.score,
    this.exactMatches = 0,
    this.substitutions = const [],
  });

  final Recipe recipe;
  final List<String> matchedIngredients;
  final List<String> extraIngredients;
  final int score;
  final int exactMatches;
  final List<String> substitutions;

  int get matchedCount => matchedIngredients.length;
  int get extraCount => extraIngredients.length;
}

class TheMealDbRankingService {
  TheMealDbRankingService._();

  static final instance = TheMealDbRankingService._();

  final IngredientNormalizerService _normalizer =
      IngredientNormalizerService.instance;

  static const Set<String> _basicIngredients = {
    'water',
    'salt',
    'pepper',
    'black pepper',
    'ground black pepper',
    'oil',
    'vegetable oil',
    'olive oil',
  };

  /// Recebe produtos reais da despensa e busca
  /// referências culinárias na TheMealDB.
  Future<List<TheMealDbRankedRecipe>> searchAndRankProducts({
    required List<Product> products,
  }) async {
    // Considera apenas produtos com estoque positivo
    // e que não estejam vencidos.
    final usableProducts = products
        .where((product) {
          final days = product.days;

          return product.quantity > 0 &&
              product.quantity.isFinite &&
              (days == null || days >= 0);
        })
        .toList(growable: false);

    if (usableProducts.isEmpty) {
      return [];
    }

    // O normalizador reconhecerá ingredientes
    // dentro dos nomes comerciais.
    final productNames = usableProducts
        .map((product) => product.name)
        .toList(growable: false);

    return searchAndRank(productNames: productNames);
  }

  /// Recebe nomes de produtos da despensa,
  /// identifica os ingredientes e busca referências.
  Future<List<TheMealDbRankedRecipe>> searchAndRank({
    required List<String> productNames,
  }) async {
    final selectedIngredients = _normalizer.identifyAll(productNames);

    if (selectedIngredients.isEmpty) {
      return [];
    }

    final searchTerms = _normalizer.searchTermsFor(productNames);

    final service = TheMealDbService.instance;

    final candidates = await service.searchByIngredientsCached(searchTerms);
    final recipes = <Recipe>[];

    // Consultas em pequenos lotes.
    const batchSize = 5;

    for (var start = 0; start < candidates.length; start += batchSize) {
      final end = (start + batchSize < candidates.length)
          ? start + batchSize
          : candidates.length;

      final batch = candidates.sublist(start, end);

      final results = await Future.wait(
        batch.map((candidate) async {
          try {
            return await service.getRecipeByIdCached(candidate.id);
          } catch (error) {
            debugPrint(
              'TheMealDB: falha ao carregar receita '
              '${candidate.id}: $error',
            );
            return null;
          }
        }),
      );

      recipes.addAll(results.whereType<Recipe>());
    }

    return rankRecipes(
      recipes,
      selectedIngredients: selectedIngredients,
      productNames: productNames,
    );
  }

  /// Classifica receitas considerando os ingredientes selecionados
  /// e as variedades dos produtos disponíveis na despensa.
  List<TheMealDbRankedRecipe> rankRecipes(
    List<Recipe> recipes, {
    required List<NormalizedIngredient> selectedIngredients,
    List<String> productNames = const [],
  }) {
    final selectedKeys = selectedIngredients
        .map((ingredient) => ingredient.key)
        .toSet();

    final ranking = recipes
        .map((recipe) => _evaluate(recipe, selectedKeys, productNames))
        .toList();

    ranking.sort((a, b) {
      // Primeiro: maior número de categorias encontradas.
      final matchedComparison = b.matchedCount.compareTo(a.matchedCount);

      if (matchedComparison != 0) {
        return matchedComparison;
      }

      // Segundo: maior pontuação, incluindo o bônus
      // por variedades exatamente correspondentes.
      final scoreComparison = b.score.compareTo(a.score);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      // Terceiro: ordenação alfabética para desempate.
      return a.recipe.name.compareTo(b.recipe.name);
    });

    return ranking;
  }

  TheMealDbRankedRecipe _evaluate(
    Recipe recipe,
    Set<String> selectedKeys,
    List<String> productNames,
  ) {
    final matched = <String>[];
    final extras = <String>[];
    final substitutions = <String>[];
    final foundKeys = <String>{};

    var exactMatches = 0;

    for (final ingredient in recipe.ingredients) {
      final identified = _normalizer.identifyDetailed(ingredient.name);

      if (identified != null && selectedKeys.contains(identified.categoryKey)) {
        if (!foundKeys.add(identified.categoryKey)) {
          continue;
        }

        matched.add(identified.categoryName);

        IngredientMatch? bestMatch;
        String? bestProduct;
        var bestPriority = 0;

        for (final productName in productNames) {
          final comparison = _normalizer.compareIngredients(
            pantryProductName: productName,
            recipeIngredientName: ingredient.name,
          );

          final priority = switch (comparison.type) {
            IngredientMatchType.exact => 3,
            IngredientMatchType.sameCategory => 2,
            IngredientMatchType.differentVariety => 1,
            _ => 0,
          };

          if (priority > bestPriority) {
            bestPriority = priority;
            bestMatch = comparison;
            bestProduct = productName;
          }
        }

        if (bestMatch?.type == IngredientMatchType.exact) {
          exactMatches++;
        }

        if (bestMatch?.requiresAdaptation == true && bestProduct != null) {
          final target = bestMatch!.pantryIngredient!;

          substitutions.add(
            '${ingredient.name} -> '
            '${target.varietyName ?? target.categoryName}',
          );
        }

        continue;
      }

      final normalizedName = _normalizer.normalizeText(ingredient.name);

      if (!_basicIngredients.contains(normalizedName)) {
        extras.add(ingredient.name);
      }
    }

    // Mantém o critério original e acrescenta
    // um bônus pequeno para variedades exatas.
    final score = matched.length * 10 + exactMatches * 2 - extras.length;

    return TheMealDbRankedRecipe(
      recipe: recipe,
      matchedIngredients: List.unmodifiable(matched),
      extraIngredients: List.unmodifiable(extras),
      exactMatches: exactMatches,
      substitutions: List.unmodifiable(substitutions),
      score: score,
    );
  }
}
