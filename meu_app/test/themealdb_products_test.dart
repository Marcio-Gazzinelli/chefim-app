import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart' as chefim;

void main() {
  test('TheMealDB classifica receitas usando produtos da despensa', () async {
    final products = [
      chefim.Product(
        'Macarrão Espaguete Barilla 500 g',
        DateTime.now().add(const Duration(days: 30)),
        quantity: 500,
        unit: 'g',
      ),
      chefim.Product(
        'Creme de Leite Italac 200 g',
        DateTime.now().add(const Duration(days: 20)),
        quantity: 200,
        unit: 'g',
      ),
      chefim.Product(
        'Tomate Italiano',
        DateTime.now().add(const Duration(days: 5)),
        quantity: 3,
        unit: 'unidade',
      ),
      chefim.Product(
        'Frango congelado',
        DateTime.now().subtract(const Duration(days: 2)),
        quantity: 1000,
        unit: 'g',
      ),
    ];

    final service = chefim.TheMealDbRankingService.instance;

    final ranking = await service.searchAndRankProducts(products: products);

    expect(ranking, isNotEmpty);

    // A receita de referência usada nos nossos
    // experimentos deve continuar sendo encontrada.
    expect(ranking.any((item) => item.recipe.id == 'themealdb_53064'), isTrue);

    print('\n===== RANKING COM DESPENSA =====');
    print('Produtos cadastrados: ${products.length}');
    print('Receitas analisadas: ${ranking.length}');

    for (final item in ranking.take(10)) {
      print('\nReceita: ${item.recipe.name}');
      print('Principais: ${item.matchedCount}');
      print('Extras: ${item.extraCount}');
      print('Pontuação: ${item.score}');
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
