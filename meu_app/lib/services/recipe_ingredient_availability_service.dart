part of '../main.dart';

class RecipeIngredientAvailabilityService {
  RecipeIngredientAvailabilityService._();

  static final instance = RecipeIngredientAvailabilityService._();

  bool isAvailable({
    required AiRecipeIngredient ingredient,
    required List<Product> pantryProducts,
  }) {
    return pantryProducts
        .where(_isUsable)
        .any((product) => _matches(product, ingredient));
  }

  List<AiRecipeIngredient> availableIngredients({
    required AiGeneratedRecipe recipe,
    required List<Product> pantryProducts,
  }) {
    return recipe.ingredients
        .where(
          (ingredient) => isAvailable(
            ingredient: ingredient,
            pantryProducts: pantryProducts,
          ),
        )
        .toList(growable: false);
  }

  List<AiRecipeIngredient> missingIngredients({
    required AiGeneratedRecipe recipe,
    required List<Product> pantryProducts,
  }) {
    return recipe.ingredients
        .where(
          (ingredient) => !isAvailable(
            ingredient: ingredient,
            pantryProducts: pantryProducts,
          ),
        )
        .toList(growable: false);
  }

  bool _isUsable(Product product) {
    final days = product.days;
    return product.quantity.isFinite &&
        product.quantity > 0 &&
        (days == null || days >= 0);
  }

  bool _matches(Product product, AiRecipeIngredient ingredient) {
    final normalizer = IngredientNormalizerService.instance;
    final match = normalizer.compareIngredients(
      pantryProductName: product.name,
      recipeIngredientName: ingredient.name,
    );

    if (match.isCompatible) {
      return true;
    }

    final productName = normalizer.normalizeText(product.name);
    final ingredientName = normalizer.normalizeText(ingredient.name);

    if (productName.isEmpty || ingredientName.isEmpty) {
      return false;
    }

    return productName == ingredientName ||
        ' $productName '.contains(' $ingredientName ') ||
        ' $ingredientName '.contains(' $productName ');
  }
}
