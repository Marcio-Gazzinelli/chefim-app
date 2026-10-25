part of '../main.dart';

extension _RecipesScreen on _ChefimShellState {
  Widget recipes() {
    return scroll([
      topbar(
        'Receitas',
        action: IconButton(
          tooltip: 'Pesquisar receitas',
          onPressed: () => open(const ScaledRecipesPage()),
          icon: Icon(Icons.search, color: darkGreen),
        ),
      ),
      subtitle('Com o que você tem na despensa'),
      Row(
        children: [
          Expanded(
            child: Text('Ideias para hoje', style: type(14, bold: true)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '0 disponíveis',
              style: type(10, bold: true, color: darkGreen),
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      Center(
        child: Column(
          children: [
            badge(Icons.soup_kitchen_outlined, softGreen, darkGreen, size: 62),
            const SizedBox(height: 14),
            Text('Nenhuma receita disponível', style: type(15, bold: true)),
          ],
        ),
      ),
    ]);
  }
}
