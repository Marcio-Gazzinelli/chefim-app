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
              'Busca experimental',
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
            Text(
              'Descubra receitas com sua despensa',
              style: type(15, bold: true),
            ),
            const SizedBox(height: 10),
            const Text(
              'Selecione seus ingredientes e encontre '
              'referências culinárias.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: productsLoading
                  ? null
                  : () => open(
                      TheMealDbResultsPage(
                        products: List<Product>.of(products),
                      ),
                    ),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Buscar com minha despensa'),
            ),
          ],
        ),
      ),
    ]);
  }
}
