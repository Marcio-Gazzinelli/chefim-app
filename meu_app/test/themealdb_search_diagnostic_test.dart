
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart' as chefim;

void main() {
  test('Diagnosticar termos de pesquisa da TheMealDB', () async {
    final service = chefim.TheMealDbService.instance;

    final terms = [
      'tomato',
      'tomatoes',
      'cream',
      'heavy cream',
      'double cream',
      'pasta',
      'spaghetti',
      'fettuccine',
      'penne',
      'macaroni',
    ];

    print('\n===== DIAGNOSTICO DE BUSCA =====');

    for (final term in terms) {
      final recipes = await service.searchByIngredient(term);

      final containsAlfredo = recipes.any(
        (recipe) => recipe.id == '53064',
      );

      print(
        '$term: ${recipes.length} receitas'
        '${containsAlfredo ? " [FETTUCCINE ALFREDO]" : ""}',
      );
    }
  });
}
