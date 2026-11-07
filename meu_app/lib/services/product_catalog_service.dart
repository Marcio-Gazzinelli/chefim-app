part of '../main.dart';

typedef _NutritionSelection = ({off.NutritionSet set, double multiplier});

class ProductCatalogException implements Exception {
  const ProductCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Orquestra as fontes de catálogo na seguinte ordem:
/// 1. Open Food Facts;
/// 2. catálogo próprio e revisado do Chefim no Supabase.
class ProductCatalogService {
  ProductCatalogService._();

  static final ProductCatalogService instance = ProductCatalogService._();

  Future<CatalogProduct?> findByGtin(String gtin) async {
    CatalogProduct? openFoodFactsProduct;
    Object? openFoodFactsError;

    try {
      openFoodFactsProduct = await _findOnOpenFoodFacts(gtin);
    } catch (error) {
      openFoodFactsError = error;
    }

    CatalogProduct? communityProduct;

    if (_needsComplement(openFoodFactsProduct)) {
      communityProduct = await SupabaseCatalogService.instance.findByGtin(gtin);
    }

    final result = _mergeProducts(
      primary: openFoodFactsProduct,
      fallback: communityProduct,
    );

    if (result != null) {
      return result;
    }

    if (openFoodFactsError != null) {
      throw const ProductCatalogException(
        'Não foi possível consultar os catálogos agora. '
        'Você ainda pode cadastrar o produto manualmente.',
      );
    }

    return null;
  }

  Future<CatalogProduct?> _findOnOpenFoodFacts(String gtin) async {
    final configuration = off.ProductQueryConfiguration(
      gtin,
      language: off.OpenFoodFactsLanguage.PORTUGUESE,
      fields: [
        off.ProductField.NAME,
        off.ProductField.BRANDS,
        off.ProductField.QUANTITY,
        off.ProductField.SERVING_SIZE,
        off.ProductField.SERVING_QUANTITY,
        off.ProductField.IMAGE_FRONT_URL,
        off.ProductField.INGREDIENTS_TEXT,
        off.ProductField.ALLERGENS,
        off.ProductField.NUTRITION,
      ],
      version: off.ProductQueryVersion.latestVersion,
    );

    final result = await off.OpenFoodAPIClient.getProductV3(configuration)
        .timeout(const Duration(seconds: 12));

    final product = result.product;

    if (product == null) {
      return null;
    }

    final nutrition = _getNutritionPerHundred(product);

    final catalogProduct = CatalogProduct(
      barcode: gtin,
      source: 'Open Food Facts',
      name: _clean(product.productName),
      brand: _clean(product.brands),
      packageQuantity: _clean(product.quantity),
      imageUrl: _highResolutionImage(product.imageFrontUrl),
      ingredients: _clean(product.ingredientsText),
      allergens: product.allergens?.names.isEmpty ?? true
          ? null
          : product.allergens!.names.join(', '),
      servingSize: _clean(product.servingSize),
      energyKcal100g: _nutrient(nutrition, off.Nutrient.energyKCal),
      carbohydrates100g: _nutrient(nutrition, off.Nutrient.carbohydrates),
      proteins100g: _nutrient(nutrition, off.Nutrient.proteins),
      fat100g: _nutrient(nutrition, off.Nutrient.fat),
      saturatedFat100g: _nutrient(nutrition, off.Nutrient.saturatedFat),
      sugars100g: _nutrient(nutrition, off.Nutrient.sugars),
      fiber100g: _nutrient(nutrition, off.Nutrient.fiber),
      sodium100g: _nutrient(nutrition, off.Nutrient.sodium),
    );

    return catalogProduct.hasUsefulData ? catalogProduct : null;
  }

  bool _needsComplement(CatalogProduct? product) {
    return product == null ||
        product.name?.trim().isNotEmpty != true ||
        product.imageUrl?.trim().isNotEmpty != true ||
        !product.hasNutrition;
  }

  CatalogProduct? _mergeProducts({
    required CatalogProduct? primary,
    required CatalogProduct? fallback,
  }) {
    if (primary == null) {
      return fallback;
    }

    if (fallback == null) {
      return primary;
    }

    final sources = <String>{primary.source, fallback.source}.join(' + ');

    return CatalogProduct(
      barcode: primary.barcode,
      source: sources,
      name: _firstText(primary.name, fallback.name),
      brand: _firstText(primary.brand, fallback.brand),
      packageQuantity: _firstText(
        primary.packageQuantity,
        fallback.packageQuantity,
      ),
      imageUrl: _firstText(primary.imageUrl, fallback.imageUrl),
      ingredients: _firstText(primary.ingredients, fallback.ingredients),
      allergens: _firstText(primary.allergens, fallback.allergens),
      servingSize: _firstText(primary.servingSize, fallback.servingSize),
      energyKcal100g: primary.energyKcal100g ?? fallback.energyKcal100g,
      carbohydrates100g:
          primary.carbohydrates100g ?? fallback.carbohydrates100g,
      proteins100g: primary.proteins100g ?? fallback.proteins100g,
      fat100g: primary.fat100g ?? fallback.fat100g,
      saturatedFat100g: primary.saturatedFat100g ?? fallback.saturatedFat100g,
      sugars100g: primary.sugars100g ?? fallback.sugars100g,
      fiber100g: primary.fiber100g ?? fallback.fiber100g,
      sodium100g: primary.sodium100g ?? fallback.sodium100g,
    );
  }

  String? _firstText(String? primary, String? fallback) {
    return _clean(primary) ?? _clean(fallback);
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  String? _highResolutionImage(String? value) {
    final cleaned = _clean(value);

    if (cleaned == null) {
      return null;
    }

    return cleaned.replaceFirst(
      RegExp(r'\.(?:100|200|400)\.jpg(?=$|\?)'),
      '.full.jpg',
    );
  }

  /// Procura primeiro valores por 100 g/100 mL. Se houver somente valores
  /// por porção, calcula o equivalente por 100 g/100 mL.
  _NutritionSelection? _getNutritionPerHundred(off.Product product) {
    final sets = off.NutritionHelper().getInputSets(product);

    if (sets == null || sets.isEmpty) {
      return null;
    }

    for (final set in sets) {
      if (_isPerHundred(set) &&
          set.key.preparation == off.NutritionSetKey.preparationAsSold) {
        return (set: set, multiplier: 1);
      }
    }

    for (final set in sets) {
      if (_isPerHundred(set)) {
        return (set: set, multiplier: 1);
      }
    }

    off.NutritionSet? servingSet;

    for (final set in sets) {
      if (set.key.perSize == off.PerSize.serving &&
          set.key.preparation == off.NutritionSetKey.preparationAsSold) {
        servingSet = set;
        break;
      }
    }

    if (servingSet == null) {
      for (final set in sets) {
        if (set.key.perSize == off.PerSize.serving) {
          servingSet = set;
          break;
        }
      }
    }

    if (servingSet == null) {
      return null;
    }

    final servingQuantity = _getServingQuantity(product, servingSet);

    if (servingQuantity == null || servingQuantity <= 0) {
      return null;
    }

    return (set: servingSet, multiplier: 100 / servingQuantity);
  }

  bool _isPerHundred(off.NutritionSet set) {
    return set.key.perSize == off.PerSize.oneHundredGrams ||
        set.key.perSize == off.PerSize.oneHundredMilliliters;
  }

  double? _getServingQuantity(
    off.Product product,
    off.NutritionSet servingSet,
  ) {
    final setQuantity = servingSet.key.perQuantity;

    if (setQuantity != null && setQuantity > 0) {
      return setQuantity.toDouble();
    }

    final productQuantity = product.servingQuantity;

    if (productQuantity != null && productQuantity > 0) {
      return productQuantity.toDouble();
    }

    return _parseServingQuantity(product.servingSize);
  }

  double? _parseServingQuantity(String? servingSize) {
    if (servingSize == null || servingSize.trim().isEmpty) {
      return null;
    }

    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:g|ml)\b',
      caseSensitive: false,
    ).firstMatch(servingSize);

    final value = match?.group(1)?.replaceAll(',', '.');

    if (value == null) {
      return null;
    }

    final parsed = double.tryParse(value);

    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  double? _nutrient(_NutritionSelection? nutrition, off.Nutrient nutrient) {
    if (nutrition == null) {
      return null;
    }

    final nutritionValue = nutrition.set.nutritionValues?[nutrient];
    final rawValue = (nutritionValue?.value ?? nutritionValue?.valueComputed)
        ?.toDouble();

    if (rawValue == null || !rawValue.isFinite || rawValue < 0) {
      return null;
    }

    final normalizedValue = rawValue * nutrition.multiplier;

    if (!normalizedValue.isFinite || normalizedValue < 0) {
      return null;
    }

    return double.parse(normalizedValue.toStringAsFixed(4));
  }
}
