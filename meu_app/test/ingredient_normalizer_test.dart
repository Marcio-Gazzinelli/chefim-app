import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart' as chefim;

void main() {
  final normalizer = chefim.IngredientNormalizerService.instance;

  test('Identifica ingredientes em produtos comerciais', () {
    final products = [
      'Macarrão Espaguete Barilla 500 g',
      'Creme de Leite Italac 200 g',
      'Tomate Italiano',
    ];

    final ingredients = normalizer.identifyAll(products);

    expect(ingredients.length, 3);

    print('\n===== NORMALIZACAO =====');

    for (final product in products) {
      final ingredient = normalizer.identify(product);

      expect(ingredient, isNotNull);

      print('$product -> ${ingredient!.name}');
    }
  });

  test('Expande termos para a TheMealDB', () {
    final terms = normalizer.searchTermsFor([
      'Macarrão Espaguete Barilla 500 g',
      'Creme de Leite Italac 200 g',
      'Tomate Italiano',
    ]);

    expect(terms, contains('tomato'));
    expect(terms, contains('heavy cream'));
    expect(terms, contains('fettuccine'));

    expect(terms.length, terms.toSet().length);

    print('\n===== TERMOS DE PESQUISA =====');

    for (final term in terms) {
      print(term);
    }
  });

  test('Não confunde ingredientes diferentes', () {
    expect(normalizer.identify('Cream Cheese Philadelphia'), isNull);

    expect(normalizer.identify('Molho de Tomate 340 g'), isNull);

    expect(normalizer.identify('Chocolate ao Leite'), isNull);

    expect(normalizer.identify('Pastagem'), isNull);
  });

  test('Reconhece nomes em inglês', () {
    expect(normalizer.identify('Heavy Cream')?.key, 'creme_de_leite');

    expect(normalizer.identify('Fettuccine')?.key, 'macarrao');

    expect(normalizer.identify('Cherry Tomatoes')?.key, 'tomate');
  });

  test('Reconhece novos ingredientes em nomes comerciais', () {
    final products = {
      'Peito de Frango Sadia Congelado 1 kg': 'frango',
      'Arroz Branco Camil 5 kg': 'arroz',
      'Batata Inglesa 1 kg': 'batata',
      'Cebola Roxa 500 g': 'cebola',
      'Alho Descascado 200 g': 'alho',
      'Leite Integral Italac 1 L': 'leite',
      'Queijo Mussarela 400 g': 'queijo',
      'Ovos Brancos 12 unidades': 'ovo',
      'Carne Moída Patinho 500 g': 'carne_bovina',
      'Cenoura 1 kg': 'cenoura',
      'Feijão Preto Camil 1 kg': 'feijao',
      'Manteiga 200 g': 'manteiga',
      'Farinha de Trigo 1 kg': 'farinha_trigo',
    };

    for (final entry in products.entries) {
      final result = normalizer.identify(entry.key);

      expect(
        result?.key,
        entry.value,
        reason: 'Falha ao identificar: ${entry.key}',
      );

      print('${entry.key} -> ${result?.name}');
    }
  });

  test('Não confunde produtos derivados com ingredientes básicos', () {
    final products = [
      'Molho de Tomate Tradicional 340 g',
      'Extrato de Tomate 130 g',
      'Cream Cheese Philadelphia',
      'Leite Condensado 395 g',
      'Leite de Coco 200 ml',
      'Pasta de Amendoim 500 g',
      'Caldo de Frango 100 g',
      'Manteiga de Amendoim',
    ];

    for (final product in products) {
      expect(
        normalizer.identify(product),
        isNull,
        reason: 'Classificação inesperada: $product',
      );
    }
  });

  test('Expande frango e arroz para termos em inglês', () {
    final terms = normalizer.searchTermsFor([
      'Peito de Frango Sadia 1 kg',
      'Arroz Branco Camil 5 kg',
    ]);

    expect(terms, contains('chicken'));
    expect(terms, contains('chicken breast'));
    expect(terms, contains('rice'));
    expect(terms, contains('white rice'));
  });

  test('Identifica categoria e variedade dos produtos', () {
    final cases = {
      'Macarrão Espaguete Barilla 500 g': ('macarrao', 'espaguete'),
      'Macarrão Penne Renata 500 g': ('macarrao', 'penne'),
      'Peito de Frango Sadia 1 kg': ('frango', 'peito'),
      'Sobrecoxa de Frango 1 kg': ('frango', 'sobrecoxa'),
      'Queijo Mussarela 400 g': ('queijo', 'mussarela'),
      'Queijo Parmesão 150 g': ('queijo', 'parmesao'),
      'Arroz Branco Camil 5 kg': ('arroz', 'branco'),
      'Arroz Integral Tio João 1 kg': ('arroz', 'integral'),
      'Tomate Italiano': ('tomate', 'italiano'),
    };

    for (final entry in cases.entries) {
      final result = normalizer.identifyDetailed(entry.key);

      expect(result, isNotNull);
      expect(result!.categoryKey, entry.value.$1);
      expect(result.varietyKey, entry.value.$2);
      expect(result.originalName, entry.key);

      print(
        '${entry.key} -> '
        '${result.categoryName} / ${result.varietyName}',
      );
    }
  });

  test('Preserva ingredientes sem variedade definida', () {
    final result = normalizer.identifyDetailed('Macarrão 500 g');

    expect(result, isNotNull);
    expect(result!.categoryKey, 'macarrao');
    expect(result.varietyKey, isNull);
    expect(result.hasVariety, isFalse);
  });

  test('Distingue formatos de macarrão', () {
    final pantry = normalizer.identifyDetailed(
      'Macarrão Espaguete Barilla 500 g',
    );

    final reference = normalizer.identifyDetailed('Penne');

    expect(pantry, isNotNull);
    expect(reference, isNotNull);

    expect(pantry!.categoryKey, reference!.categoryKey);
    expect(pantry.varietyKey, isNot(reference.varietyKey));
  });

  test('Identifica correspondencia exata', () {
    final match = normalizer.compareIngredients(
      pantryProductName: 'Macarrão Espaguete Barilla 500 g',
      recipeIngredientName: 'Spaghetti',
    );

    expect(match.type, chefim.IngredientMatchType.exact);

    expect(match.requiresAdaptation, isFalse);
  });

  test('Identifica variedades diferentes', () {
    final match = normalizer.compareIngredients(
      pantryProductName: 'Macarrão Espaguete Barilla 500 g',
      recipeIngredientName: 'Penne',
    );

    expect(match.type, chefim.IngredientMatchType.differentVariety);

    expect(match.requiresAdaptation, isTrue);
  });

  test('Identifica categoria sem variedade definida', () {
    final match = normalizer.compareIngredients(
      pantryProductName: 'Macarrão 500 g',
      recipeIngredientName: 'Penne',
    );

    expect(match.type, chefim.IngredientMatchType.sameCategory);
  });

  test('Identifica categorias incompatíveis', () {
    final match = normalizer.compareIngredients(
      pantryProductName: 'Arroz Branco Camil 5 kg',
      recipeIngredientName: 'Spaghetti',
    );

    expect(match.type, chefim.IngredientMatchType.incompatible);

    expect(match.isCompatible, isFalse);
  });

  test('Nao inventa correspondencia desconhecida', () {
    final match = normalizer.compareIngredients(
      pantryProductName: 'Produto desconhecido XYZ',
      recipeIngredientName: 'Spaghetti',
    );

    expect(match.type, chefim.IngredientMatchType.unknown);

    expect(match.isCompatible, isFalse);
  });
}
