part of '../main.dart';

/// Dados de um produto recuperados de um catálogo externo ou comunitário.
///
/// Os campos são opcionais porque tanto o Open Food Facts quanto o catálogo
/// do Chefim podem possuir registros incompletos.
class CatalogProduct {
  const CatalogProduct({
    required this.barcode,
    required this.source,
    this.name,
    this.brand,
    this.packageQuantity,
    this.imageUrl,
    this.ingredients,
    this.allergens,
    this.servingSize,
    this.energyKcal100g,
    this.carbohydrates100g,
    this.proteins100g,
    this.fat100g,
    this.saturatedFat100g,
    this.sugars100g,
    this.fiber100g,
    this.sodium100g,
  });

  final String barcode;
  final String source;
  final String? name;
  final String? brand;
  final String? packageQuantity;
  final String? imageUrl;
  final String? ingredients;
  final String? allergens;
  final String? servingSize;
  final double? energyKcal100g;
  final double? carbohydrates100g;
  final double? proteins100g;
  final double? fat100g;
  final double? saturatedFat100g;
  final double? sugars100g;
  final double? fiber100g;
  final double? sodium100g;

  bool get hasNutrition =>
      energyKcal100g != null ||
      carbohydrates100g != null ||
      proteins100g != null ||
      fat100g != null ||
      saturatedFat100g != null ||
      sugars100g != null ||
      fiber100g != null ||
      sodium100g != null;

  bool get hasUsefulData =>
      name?.trim().isNotEmpty == true ||
      brand?.trim().isNotEmpty == true ||
      imageUrl?.trim().isNotEmpty == true ||
      hasNutrition;
}
