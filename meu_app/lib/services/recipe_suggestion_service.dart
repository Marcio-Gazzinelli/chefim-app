part of '../main.dart';

class RecipeSuggestionService {
  RecipeSuggestionService._();

  static final RecipeSuggestionService instance = RecipeSuggestionService._();

  /// Ingredientes básicos não precisam estar cadastrados na despensa.
  static const Set<String> _basicIngredients = {'agua', 'sal', 'oleo'};

  /// Compara receitas já geradas com os produtos da despensa.
  ///
  /// Nesta primeira versão, a comparação considera a presença do
  /// ingrediente. A conversão entre kg, g, L e mL poderá ser
  /// adicionada posteriormente.
  List<RecipeSuggestion> rank({
    required List<Recipe> recipes,
    required List<Product> products,
    int expiryWarningDays = 3,
  }) {
    final usableProducts = products
        .where((product) {
          final days = product.days;

          return product.quantity > 0 && (days == null || days >= 0);
        })
        .toList(growable: false);

    final suggestions = recipes
        .map(
          (recipe) => _analyze(
            recipe: recipe,
            products: usableProducts,
            expiryWarningDays: expiryWarningDays,
          ),
        )
        .toList();

    suggestions.sort(_compareSuggestions);

    return suggestions;
  }

  RecipeSuggestion _analyze({
    required Recipe recipe,
    required List<Product> products,
    required int expiryWarningDays,
  }) {
    final matched = <RecipeIngredient>[];
    final missing = <RecipeIngredient>[];
    final expiring = <Product>[];

    var requiredCount = 0;
    var matchedRequiredCount = 0;

    for (final ingredient in recipe.ingredients) {
      final isBasic = _isBasicIngredient(ingredient.name);
      final isRequired = !ingredient.optional && !isBasic;

      if (isRequired) {
        requiredCount++;
      }

      if (isBasic) {
        continue;
      }

      final product = _findMatchingProduct(
        products: products,
        ingredient: ingredient,
      );

      if (product == null) {
        if (isRequired) {
          missing.add(ingredient);
        }

        continue;
      }

      matched.add(ingredient);

      if (isRequired) {
        matchedRequiredCount++;
      }

      final days = product.days;

      if (days != null &&
          days >= 0 &&
          days <= expiryWarningDays &&
          !expiring.contains(product)) {
        expiring.add(product);
      }
    }

    final compatibility = requiredCount == 0
        ? 1.0
        : matchedRequiredCount / requiredCount;

    var score = compatibility * 100;

    score += expiring.length * 15;
    score -= missing.length * 8;

    if (missing.isEmpty) {
      score += 40;
    }

    return RecipeSuggestion(
      recipe: recipe,
      matchedIngredients: List.unmodifiable(matched),
      missingIngredients: List.unmodifiable(missing),
      expiringProducts: List.unmodifiable(expiring),
      requiredIngredientCount: requiredCount,
      matchedRequiredIngredientCount: matchedRequiredCount,
      score: score,
    );
  }

  Product? _findMatchingProduct({
    required List<Product> products,
    required RecipeIngredient ingredient,
  }) {
    for (final product in products) {
      for (final term in ingredient.searchTerms) {
        if (_matches(product.name, term)) {
          return product;
        }
      }
    }

    return null;
  }

  bool _matches(String productName, String ingredientName) {
    final product = _normalize(productName);
    final ingredient = _normalize(ingredientName);

    if (product.isEmpty || ingredient.isEmpty) {
      return false;
    }

    if (product == ingredient) {
      return true;
    }

    final productWithBoundaries = ' $product ';

    return productWithBoundaries.contains(' $ingredient ');
  }

  bool _isBasicIngredient(String value) {
    return _basicIngredients.contains(_normalize(value));
  }

  int _compareSuggestions(RecipeSuggestion first, RecipeSuggestion second) {
    if (first.canPrepare != second.canPrepare) {
      return first.canPrepare ? -1 : 1;
    }

    final scoreComparison = second.score.compareTo(first.score);

    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final missingComparison = first.missingIngredients.length.compareTo(
      second.missingIngredients.length,
    );

    if (missingComparison != 0) {
      return missingComparison;
    }

    final timeComparison = first.recipe.preparationMinutes.compareTo(
      second.recipe.preparationMinutes,
    );

    if (timeComparison != 0) {
      return timeComparison;
    }

    return first.recipe.name.compareTo(second.recipe.name);
  }

  String _normalize(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map(_singularizeToken)
        .join(' ');
  }

  String _singularizeToken(String token) {
    const irregular = {
      'acucares': 'acucar',
      'paes': 'pao',
      'meloes': 'melao',
      'limoes': 'limao',
      'graos': 'grao',
    };

    final irregularValue = irregular[token];

    if (irregularValue != null) {
      return irregularValue;
    }

    if (token.endsWith('oes') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}ao';
    }

    if (token.endsWith('ais') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}al';
    }

    if (token.endsWith('s') && token.length > 3) {
      return token.substring(0, token.length - 1);
    }

    return token;
  }
}
