import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart' as chefim;

void main() {
  test('TheMealDB busca e converte receita por ID', () async {
    final service = chefim.TheMealDbService.instance;

    // Fettuccine Alfredo, usado nos nossos experimentos.
    final recipe = await service.getRecipeById('53064');

    expect(recipe, isNotNull);
    expect(recipe!.id, 'themealdb_53064');
    expect(recipe.name, isNotEmpty);
    expect(recipe.source, 'TheMealDB');
    expect(recipe.ingredients, isNotEmpty);
    expect(recipe.steps, isNotEmpty);

    print('Nome: ${recipe.name}');
    print('Ingredientes: ${recipe.ingredients.length}');
    print('Etapas: ${recipe.steps.length}');

    for (final ingredient in recipe.ingredients) {
      print('${ingredient.name}: ${ingredient.unit}');
    }
  });

  test('TheMealDB busca receitas por ingrediente', () async {
    final service = chefim.TheMealDbService.instance;

    final recipes = await service.searchByIngredient('tomato');

    expect(recipes, isNotEmpty);

    print('\n===== RECEITAS COM TOMATE =====');
    print('Total encontrado: ${recipes.length}');

    for (final recipe in recipes.take(10)) {
      print('${recipe.id} - ${recipe.name}');
    }
  });

  test('TheMealDB combina buscas sem duplicar receitas', () async {
    final service = chefim.TheMealDbService.instance;

    final recipes = await service.searchByIngredients([
      'tomato',
      'cream',
      'pasta',
    ]);

    expect(recipes, isNotEmpty);

    final ids = recipes.map((recipe) => recipe.id).toList();
    final uniqueIds = ids.toSet();

    expect(ids.length, uniqueIds.length);

    print('\n===== BUSCA COMBINADA =====');
    print('Ingredientes: tomato, cream, pasta');
    print('Receitas únicas: ${recipes.length}');

    for (final recipe in recipes.take(15)) {
      print('${recipe.id} - ${recipe.name}');
    }
  });
}
