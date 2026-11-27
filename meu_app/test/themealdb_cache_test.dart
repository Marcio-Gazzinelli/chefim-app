// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:meu_app/main.dart' as chefim;

void main() {
  test('Cache reutiliza os detalhes da mesma receita', () async {
    final service = chefim.TheMealDbService.instance;

    service.clearCache();

    final stopwatch = Stopwatch()..start();

    final first = await service.getRecipeByIdCached('53064');

    final firstDuration = stopwatch.elapsedMilliseconds;

    stopwatch.reset();

    final second = await service.getRecipeByIdCached('53064');

    final secondDuration = stopwatch.elapsedMilliseconds;

    stopwatch.stop();

    expect(first, isNotNull);
    expect(identical(first, second), isTrue);

    print('\n===== TESTE DE CACHE =====');
    print('Primeira consulta: $firstDuration ms');
    print('Segunda consulta: $secondDuration ms');
    print('Mesmo objeto reutilizado: ${identical(first, second)}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
