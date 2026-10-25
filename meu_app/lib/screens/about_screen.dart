part of '../main.dart';

extension _AboutScreen on _ChefimShellState {
  Widget aboutPage() => EntryPage(
    title: 'Sobre o Chefim',
    builder: (pageContext, refresh) => [
      const SizedBox(height: 8),
      panel(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text('CHEFIM.', style: type(30, bold: true, color: green)),
              const SizedBox(height: 6),
              Text('Sua despensa inteligente', style: type(14, bold: true)),
              const SizedBox(height: 9),
              Text(
                'O Chefim ajuda você a organizar alimentos, '
                'acompanhar validades e aproveitar melhor '
                'suas compras.',
                textAlign: TextAlign.center,
                style: type(11, color: muted),
              ),
            ],
          ),
        ),
        custom: true,
      ),
      section('Como funciona?', ''),
      step(
        '1',
        'Cadastre seus produtos',
        'Registre alimentos e datas de validade.',
      ),
      step('2', 'Receba alertas', 'Saiba o que está perto de vencer.'),
      step('3', 'Encontre receitas', 'Use ingredientes antes que estraguem.'),
      const SizedBox(height: 8),
      panel(
        Row(
          children: [
            badge(Icons.soup_kitchen_outlined, softGreen, darkGreen),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Projeto acadêmico', style: type(13, bold: true)),
                Text(
                  'Sprint 3 — Engenharia de Computação',
                  style: type(11, color: muted),
                ),
                Text('Versão 1.0 • 2026', style: type(10, color: muted)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            pageContext,
            MaterialPageRoute(builder: (_) => const TermsScreen()),
          ),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Termos de Uso'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            pageContext,
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Política de Privacidade'),
        ),
      ),
    ],
  );

  Widget step(String number, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        badge(Icons.circle, softGreen, darkGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number  $title', style: type(13, bold: true)),
              Text(text, style: type(11, color: muted)),
            ],
          ),
        ),
      ],
    ),
  );
}
