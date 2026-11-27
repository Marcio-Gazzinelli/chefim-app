import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_app/main.dart';

void main() {
  testWidgets('Aplicativo inicia pela tela de abertura do Chefim', (
    tester,
  ) async {
    await tester.pumpWidget(const ChefimApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Chefim'), findsOneWidget);
    expect(find.text('Seu Companheiro na Cozinha'), findsOneWidget);

    // Remove a tela para encerrar corretamente a animação do splash.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
