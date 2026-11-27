import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart' as chefim;

void main() {
  test('Lê calorias estimadas e calcula valor por porção', () {
    final recipe = chefim.AiGeneratedRecipe.fromJson({
      'nome': 'Arroz com frango',
      'porcoes': 2,
      'calorias_totais_estimadas': 900,
      'ingredientes': [
        {
          'nome': 'Arroz',
          'quantidade': '200',
          'unidade': 'g',
          'origem': 'selecionado',
        },
      ],
      'preparo': ['Etapa 1', 'Etapa 2', 'Etapa 3'],
      'observacoes': <String>[],
    });

    expect(recipe.estimatedCaloriesTotal, 900);
    expect(recipe.estimatedCaloriesPerServing, 450);
  });

  test('Mantém os dados da receita ao salvar e restaurar', () {
    final recipe = chefim.AiGeneratedRecipe.fromJson({
      'nome': 'Omelete',
      'porcoes': 1,
      'calorias_totais_estimadas': 320,
      'calorias_por_porcao': 320,
      'ingredientes': [
        {
          'nome': 'Ovo',
          'quantidade': '2',
          'unidade': 'unidades',
          'origem': 'selecionado',
        },
      ],
      'preparo': ['Bata os ovos', 'Aqueça a frigideira', 'Cozinhe'],
      'observacoes': ['Sirva quente'],
    });

    final saved = chefim.SavedRecipe(
      id: 7,
      userId: 3,
      recipe: recipe,
      createdAt: DateTime(2026, 11, 25),
    );
    final restored = chefim.SavedRecipe.fromMap(saved.toMap());

    expect(restored.id, 7);
    expect(restored.userId, 3);
    expect(restored.recipe.name, 'Omelete');
    expect(restored.recipe.ingredients.single.name, 'Ovo');
    expect(restored.recipe.estimatedCaloriesPerServing, 320);
    expect(restored.createdAt, DateTime(2026, 11, 25));
  });

  test('Identifica ingredientes não encontrados na despensa', () {
    final recipe = chefim.AiGeneratedRecipe.fromJson({
      'nome': 'Macarrão ao molho',
      'porcoes': 2,
      'ingredientes': [
        {
          'nome': 'Espaguete',
          'quantidade': '200',
          'unidade': 'g',
          'origem': 'selecionado',
        },
        {
          'nome': 'Queijo parmesão',
          'quantidade': '50',
          'unidade': 'g',
          'origem': 'adicional',
        },
      ],
      'preparo': ['Etapa 1', 'Etapa 2', 'Etapa 3'],
      'observacoes': <String>[],
    });
    final pantry = [
      chefim.Product('Macarrão Penne 500 g', null, quantity: 500, unit: 'g'),
    ];

    final missing = chefim.RecipeIngredientAvailabilityService.instance
        .missingIngredients(recipe: recipe, pantryProducts: pantry);

    expect(missing.map((ingredient) => ingredient.name), ['Queijo parmesão']);
  });
}
