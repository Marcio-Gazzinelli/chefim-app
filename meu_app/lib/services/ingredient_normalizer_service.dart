part of '../main.dart';

class NormalizedIngredient {
  const NormalizedIngredient({
    required this.key,
    required this.name,
    required this.searchTerms,
  });

  final String key;
  final String name;
  final List<String> searchTerms;
}

class IdentifiedIngredient {
  const IdentifiedIngredient({
    required this.originalName,
    required this.category,
    this.varietyKey,
    this.varietyName,
  });

  /// Nome exato do produto cadastrado.
  final String originalName;

  /// Categoria geral reconhecida.
  final NormalizedIngredient category;

  /// Identificador da variedade, quando reconhecida.
  final String? varietyKey;

  /// Nome da variedade para exibição.
  final String? varietyName;

  String get categoryKey => category.key;

  String get categoryName => category.name;

  bool get hasVariety => varietyKey != null;
}

/// Define uma variedade e suas possíveis grafias.
class IngredientVariety {
  const IngredientVariety({
    required this.key,
    required this.name,
    required this.aliases,
  });

  final String key;
  final String name;
  final List<String> aliases;
}

enum IngredientMatchType {
  exact,
  differentVariety,
  sameCategory,
  incompatible,
  unknown,
}

class IngredientMatch {
  const IngredientMatch({
    required this.type,
    this.pantryIngredient,
    this.recipeIngredient,
  });

  final IngredientMatchType type;
  final IdentifiedIngredient? pantryIngredient;
  final IdentifiedIngredient? recipeIngredient;

  bool get isCompatible =>
      type == IngredientMatchType.exact ||
      type == IngredientMatchType.differentVariety ||
      type == IngredientMatchType.sameCategory;

  bool get requiresAdaptation => type == IngredientMatchType.differentVariety;
}

class IngredientNormalizerService {
  IngredientNormalizerService._();

  static final instance = IngredientNormalizerService._();

  // Catálogo de ingredientes conhecidos.
  // Novas categorias podem ser acrescentadas aqui.
  static const List<NormalizedIngredient> _ingredients = [
    NormalizedIngredient(
      key: 'tomate',
      name: 'Tomate',
      searchTerms: ['tomato', 'tomatoes'],
    ),
    NormalizedIngredient(
      key: 'creme_de_leite',
      name: 'Creme de leite',
      searchTerms: [
        'heavy cream',
        'double cream',
        'single cream',
        'cream',
        'whipping cream',
      ],
    ),
    NormalizedIngredient(
      key: 'macarrao',
      name: 'Macarrão',
      searchTerms: [
        'spaghetti',
        'fettuccine',
        'macaroni',
        'penne',
        'fusilli',
        'linguine',
        'tagliatelle',
        'rigatoni',
        'farfalle',
        'pasta',
      ],
    ),
    NormalizedIngredient(
      key: 'frango',
      name: 'Frango',
      searchTerms: [
        'chicken',
        'chicken breast',
        'chicken thighs',
        'chicken legs',
      ],
    ),
    NormalizedIngredient(
      key: 'arroz',
      name: 'Arroz',
      searchTerms: ['rice', 'white rice', 'basmati rice', 'long grain rice'],
    ),
    NormalizedIngredient(
      key: 'batata',
      name: 'Batata',
      searchTerms: ['potatoes', 'potato'],
    ),
    NormalizedIngredient(
      key: 'cebola',
      name: 'Cebola',
      searchTerms: ['onion', 'onions', 'red onion'],
    ),
    NormalizedIngredient(
      key: 'alho',
      name: 'Alho',
      searchTerms: ['garlic', 'garlic cloves'],
    ),
    NormalizedIngredient(
      key: 'leite',
      name: 'Leite',
      searchTerms: ['milk', 'whole milk'],
    ),
    NormalizedIngredient(
      key: 'queijo',
      name: 'Queijo',
      searchTerms: ['cheese', 'cheddar cheese', 'parmesan', 'mozzarella'],
    ),
    NormalizedIngredient(key: 'ovo', name: 'Ovo', searchTerms: ['eggs', 'egg']),
    NormalizedIngredient(
      key: 'carne_bovina',
      name: 'Carne bovina',
      searchTerms: ['beef', 'minced beef', 'ground beef'],
    ),
    NormalizedIngredient(
      key: 'cenoura',
      name: 'Cenoura',
      searchTerms: ['carrots', 'carrot'],
    ),
    NormalizedIngredient(
      key: 'feijao',
      name: 'Feijão',
      searchTerms: ['beans', 'black beans', 'kidney beans'],
    ),
    NormalizedIngredient(
      key: 'manteiga',
      name: 'Manteiga',
      searchTerms: ['butter'],
    ),
    NormalizedIngredient(
      key: 'farinha_trigo',
      name: 'Farinha de trigo',
      searchTerms: ['flour', 'plain flour'],
    ),
  ];

  // Palavras ou expressões que identificam cada categoria.
  // A busca utiliza limites de palavras, não substrings.
  static const Map<String, List<String>> _aliases = {
    'tomate': [
      'tomate',
      'tomates',
      'tomato',
      'tomatoes',
      'cherry tomatoes',
      'plum tomatoes',
      'chopped tomatoes',
      'canned tomatoes',
    ],
    'creme_de_leite': [
      'creme de leite',
      'heavy cream',
      'double cream',
      'single cream',
      'whipping cream',
      'fresh cream',
      'cream',
    ],
    'macarrao': [
      'macarrao',
      'massa alimenticia',
      'espaguete',
      'spaghetti',
      'fettuccine',
      'fettucine',
      'macaroni',
      'penne',
      'fusilli',
      'linguine',
      'tagliatelle',
      'rigatoni',
      'farfalle',
      'pasta',
    ],
    'frango': [
      'frango',
      'peito de frango',
      'coxa de frango',
      'sobrecoxa',
      'chicken',
      'chicken breast',
      'chicken thighs',
      'chicken legs',
    ],
    'arroz': ['arroz', 'rice', 'white rice', 'basmati rice', 'long grain rice'],
    'batata': ['batata', 'batatas', 'potato', 'potatoes'],
    'cebola': ['cebola', 'cebolas', 'onion', 'onions', 'red onion'],
    'alho': ['alho', 'garlic', 'garlic cloves'],
    'leite': ['leite', 'milk', 'whole milk'],
    'queijo': [
      'queijo',
      'queijos',
      'mussarela',
      'mucarela',
      'mozzarella',
      'parmesao',
      'parmesan',
      'cheddar',
      'cheese',
    ],
    'ovo': ['ovo', 'ovos', 'egg', 'eggs'],
    'carne_bovina': [
      'carne bovina',
      'carne moida',
      'patinho',
      'acém',
      'acem',
      'beef',
      'minced beef',
      'ground beef',
    ],
    'cenoura': ['cenoura', 'cenouras', 'carrot', 'carrots'],
    'feijao': ['feijao', 'feijoes', 'beans', 'black beans', 'kidney beans'],
    'manteiga': ['manteiga', 'butter'],
    'farinha_trigo': [
      'farinha de trigo',
      'wheat flour',
      'plain flour',
      'flour',
    ],
  };

  // Expressões que impedem classificações equivocadas.
  static const Map<String, List<String>> _exclusions = {
    'tomate': [
      'molho de tomate',
      'extrato de tomate',
      'polpa de tomate',
      'tomato sauce',
      'tomato paste',
      'ketchup',
    ],
    'creme_de_leite': [
      'cream cheese',
      'ice cream',
      'sour cream',
      'creme de leite condensado',
    ],
    'macarrao': [
      'pasta de dente',
      'pasta de amendoim',
      'pasta de tomate',
      'pasta de alho',
    ],
    'frango': ['caldo de frango', 'chicken stock', 'chicken broth'],
    'leite': [
      'leite condensado',
      'leite de coco',
      'leite em po',
      'milk powder',
      'condensed milk',
      'coconut milk',
      'chocolate ao leite',
      'chocolate com leite',
      'doce de leite',
      'bebida lactea',
    ],
    'queijo': ['cream cheese', 'molho de queijo', 'cheese sauce'],
    'carne_bovina': ['caldo de carne', 'beef stock', 'beef broth'],
    'manteiga': ['manteiga de amendoim', 'peanut butter'],
    'farinha_trigo': [
      'farinha de mandioca',
      'farinha de milho',
      'corn flour',
      'rice flour',
    ],
  };

  static const Map<String, List<IngredientVariety>> _varieties = {
    'macarrao': [
      IngredientVariety(
        key: 'espaguete',
        name: 'Espaguete',
        aliases: ['espaguete', 'spaghetti'],
      ),
      IngredientVariety(key: 'penne', name: 'Penne', aliases: ['penne']),
      IngredientVariety(
        key: 'fettuccine',
        name: 'Fettuccine',
        aliases: ['fettuccine', 'fettucine'],
      ),
      IngredientVariety(
        key: 'fusilli',
        name: 'Fusilli',
        aliases: ['fusilli', 'parafuso'],
      ),
      IngredientVariety(
        key: 'macaroni',
        name: 'Macarrão cotovelo',
        aliases: ['macaroni', 'cotovelo'],
      ),
      IngredientVariety(
        key: 'linguine',
        name: 'Linguine',
        aliases: ['linguine'],
      ),
    ],
    'frango': [
      IngredientVariety(
        key: 'peito',
        name: 'Peito de frango',
        aliases: ['peito de frango', 'chicken breast'],
      ),
      IngredientVariety(
        key: 'sobrecoxa',
        name: 'Sobrecoxa',
        aliases: ['sobrecoxa', 'chicken thighs'],
      ),
      IngredientVariety(
        key: 'coxa',
        name: 'Coxa',
        aliases: ['coxa de frango', 'chicken legs'],
      ),
    ],
    'arroz': [
      IngredientVariety(
        key: 'branco',
        name: 'Arroz branco',
        aliases: ['arroz branco', 'white rice'],
      ),
      IngredientVariety(
        key: 'integral',
        name: 'Arroz integral',
        aliases: ['arroz integral', 'brown rice'],
      ),
      IngredientVariety(
        key: 'basmati',
        name: 'Arroz basmati',
        aliases: ['basmati'],
      ),
      IngredientVariety(
        key: 'arboreo',
        name: 'Arroz arbóreo',
        aliases: ['arboreo', 'arborio'],
      ),
    ],
    'queijo': [
      IngredientVariety(
        key: 'mussarela',
        name: 'Mussarela',
        aliases: ['mussarela', 'mucarela', 'mozzarella'],
      ),
      IngredientVariety(
        key: 'parmesao',
        name: 'Parmesão',
        aliases: ['parmesao', 'parmesan'],
      ),
      IngredientVariety(key: 'cheddar', name: 'Cheddar', aliases: ['cheddar']),
    ],
    'tomate': [
      IngredientVariety(
        key: 'italiano',
        name: 'Tomate italiano',
        aliases: ['tomate italiano'],
      ),
      IngredientVariety(
        key: 'cereja',
        name: 'Tomate-cereja',
        aliases: ['tomate cereja', 'cherry tomatoes'],
      ),
    ],
    'leite': [
      IngredientVariety(
        key: 'integral',
        name: 'Leite integral',
        aliases: ['leite integral', 'whole milk'],
      ),
      IngredientVariety(
        key: 'desnatado',
        name: 'Leite desnatado',
        aliases: ['leite desnatado', 'skimmed milk'],
      ),
      IngredientVariety(
        key: 'semidesnatado',
        name: 'Leite semidesnatado',
        aliases: ['leite semidesnatado', 'semi skimmed milk'],
      ),
    ],
    'batata': [
      IngredientVariety(
        key: 'inglesa',
        name: 'Batata inglesa',
        aliases: ['batata inglesa'],
      ),
      IngredientVariety(
        key: 'doce',
        name: 'Batata-doce',
        aliases: ['batata doce', 'sweet potato'],
      ),
    ],
  };

  NormalizedIngredient? identify(String productName) {
    final text = normalizeText(productName);

    if (text.isEmpty) return null;

    // Dá prioridade à expressão mais específica
    // quando várias categorias forem encontradas.
    NormalizedIngredient? bestMatch;
    var longestMatch = 0;

    for (final ingredient in _ingredients) {
      final excluded = _exclusions[ingredient.key] ?? [];

      if (excluded.any(
        (value) => _containsPhrase(text, normalizeText(value)),
      )) {
        continue;
      }

      final aliases = _aliases[ingredient.key] ?? [];

      for (final alias in aliases) {
        final normalizedAlias = normalizeText(alias);

        if (_containsPhrase(text, normalizedAlias) &&
            normalizedAlias.length > longestMatch) {
          longestMatch = normalizedAlias.length;
          bestMatch = ingredient;
        }
      }
    }

    return bestMatch;
  }

  /// Identifica a categoria e a variedade de um produto.
  ///
  /// Mantém o nome original sem alterações.
  IdentifiedIngredient? identifyDetailed(String productName) {
    final category = identify(productName);

    if (category == null) {
      return null;
    }

    final normalizedName = normalizeText(productName);

    final varieties = _varieties[category.key] ?? [];

    IngredientVariety? bestVariety;
    var longestMatch = 0;

    for (final variety in varieties) {
      for (final alias in variety.aliases) {
        final normalizedAlias = normalizeText(alias);

        if (_containsPhrase(normalizedName, normalizedAlias) &&
            normalizedAlias.length > longestMatch) {
          bestVariety = variety;
          longestMatch = normalizedAlias.length;
        }
      }
    }

    return IdentifiedIngredient(
      originalName: productName,
      category: category,
      varietyKey: bestVariety?.key,
      varietyName: bestVariety?.name,
    );
  }

  /// Compara um produto da despensa com um
  /// ingrediente solicitado por uma receita.
  IngredientMatch compareIngredients({
    required String pantryProductName,
    required String recipeIngredientName,
  }) {
    final pantry = identifyDetailed(pantryProductName);
    final recipe = identifyDetailed(recipeIngredientName);

    IngredientMatch result(IngredientMatchType type) {
      return IngredientMatch(
        type: type,
        pantryIngredient: pantry,
        recipeIngredient: recipe,
      );
    }

    if (pantry == null || recipe == null) {
      return result(IngredientMatchType.unknown);
    }

    if (pantry.categoryKey != recipe.categoryKey) {
      return result(IngredientMatchType.incompatible);
    }

    final pantryVariety = pantry.varietyKey;
    final recipeVariety = recipe.varietyKey;

    if (pantryVariety == null || recipeVariety == null) {
      return result(IngredientMatchType.sameCategory);
    }

    if (pantryVariety == recipeVariety) {
      return result(IngredientMatchType.exact);
    }

    return result(IngredientMatchType.differentVariety);
  }

  List<NormalizedIngredient> identifyAll(List<String> productNames) {
    final found = <String, NormalizedIngredient>{};

    for (final name in productNames) {
      final ingredient = identify(name);

      if (ingredient != null) {
        found.putIfAbsent(ingredient.key, () => ingredient);
      }
    }

    return found.values.toList(growable: false);
  }

  List<String> searchTermsFor(List<String> productNames) {
    final terms = <String>{};

    for (final ingredient in identifyAll(productNames)) {
      terms.addAll(ingredient.searchTerms);
    }

    return terms.toList(growable: false);
  }

  String normalizeText(String value) {
    var text = value.toLowerCase().trim();

    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'ê': 'e',
      'è': 'e',
      'í': 'i',
      'ì': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ü': 'u',
      'ç': 'c',
    };

    for (final entry in accents.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsPhrase(String text, String phrase) {
    if (phrase.isEmpty) return false;

    return ' $text '.contains(' $phrase ');
  }
}
