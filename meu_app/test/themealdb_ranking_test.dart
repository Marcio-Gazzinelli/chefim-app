import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart' as chefim;

void main() {
  test('TheMealDB busca receitas a partir de produtos comerciais', () async {
    final service = chefim.TheMealDbRankingService.instance;

    final ranking = await service.searchAndRank(
      productNames: [
        'Macarrão Espaguete Barilla 500 g',
        'Creme de Leite Italac 200 g',
        'Tomate Italiano',
      ],
    );

    expect(ranking, isNotEmpty);

    // Verifica se o Alfredo foi encontrado.
    final alfredoResults = ranking
        .where((item) => item.recipe.id == 'themealdb_53064')
        .toList();

    expect(alfredoResults, isNotEmpty);

    final alfredo = alfredoResults.first;

    expect(alfredo.matchedCount, 2);
    expect(alfredo.matchedIngredients, contains('Macarrão'));
    expect(alfredo.matchedIngredients, contains('Creme de leite'));

    // Verifica a ordenação.
    for (var i = 1; i < ranking.length; i++) {
      final previous = ranking[i - 1];
      final current = ranking[i];

      expect(previous.matchedCount >= current.matchedCount, isTrue);

      if (previous.matchedCount == current.matchedCount) {
        expect(previous.score >= current.score, isTrue);
      }
    }

    print('\n===== RANKING COM PRODUTOS =====');
    print('Total analisado: ${ranking.length}');

    for (final item in ranking.take(10)) {
      print('\nReceita: ${item.recipe.name}');
      print('ID: ${item.recipe.id}');
      print('Principais: ${item.matchedCount}');
      print(
        'Encontrados: '
        '${item.matchedIngredients.join(", ")}',
      );
      print('Extras: ${item.extraCount}');
      print('Pontuação: ${item.score}');
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('Ranking prefere variedade exata', () {
    final normalizer = chefim.IngredientNormalizerService.instance;

    final rankingService = chefim.TheMealDbRankingService.instance;

    chefim.Recipe recipe(String name, String pasta) {
      return chefim.Recipe(
        id: name,
        name: name,
        servings: 2,
        preparationMinutes: 20,
        ingredients: [
          chefim.RecipeIngredient(name: pasta),
          const chefim.RecipeIngredient(name: 'Tomato'),
        ],
        steps: const ['Prepare o prato.'],
      );
    }

    final ranking = rankingService.rankRecipes(
      [
        recipe('Receita com Penne', 'Penne'),
        recipe('Receita com Espaguete', 'Spaghetti'),
      ],
      selectedIngredients: normalizer.identifyAll([
        'Macarrão Espaguete Barilla 500 g',
        'Tomate Italiano',
      ]),
      productNames: ['Macarrão Espaguete Barilla 500 g', 'Tomate Italiano'],
    );

    expect(ranking.first.recipe.name, 'Receita com Espaguete');
    expect(ranking.first.exactMatches, 1);

    final penne = ranking.firstWhere(
      (item) => item.recipe.name == 'Receita com Penne',
    );

    expect(penne.substitutions, contains('Penne -> Espaguete'));

    print('Primeira receita: ${ranking.first.recipe.name}');
    print('Substituições: ${penne.substitutions}');
  });
}
