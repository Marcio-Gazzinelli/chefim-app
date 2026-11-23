part of '../main.dart';

extension _RecipesScreen on _ChefimShellState {
  Widget recipes() {
    return _RecipeIngredientsScreen(
      products: products,
      loading: productsLoading,
      error: productsError,
      onRetry: loadProducts,
      onSearch: () => open(const ScaledRecipesPage()),
    );
  }
}

enum _RecipeExpiryGroup {
  today('Vencendo hoje'),
  week('Vencendo em uma semana'),
  fortnight('Nos próximos 15 dias'),
  month('Vencendo neste mês'),
  later('Longe da validade'),
  unknown('Sem validade cadastrada'),
  expired('Vencidos');

  const _RecipeExpiryGroup(this.label);
  final String label;

  static _RecipeExpiryGroup fromDays(int? days) => switch (days) {
    null => unknown,
    < 0 => expired,
    0 => today,
    <= 7 => week,
    <= 15 => fortnight,
    <= 30 => month,
    _ => later,
  };
}

class _RecipeIngredientsScreen extends StatefulWidget {
  const _RecipeIngredientsScreen({
    required this.products,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSearch,
  });

  final List<Product> products;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onSearch;

  @override
  State<_RecipeIngredientsScreen> createState() =>
      _RecipeIngredientsScreenState();
}

class _RecipeIngredientsScreenState extends State<_RecipeIngredientsScreen> {
  static const _selectionLimit = 3;
  final _selectedKeys = <Object>{};

  Object _productKey(Product product) => product.id ?? product;

  bool _hasStock(Product product) =>
      product.quantity.isFinite && product.quantity > 0;

  bool _canSelect(Product product) => _hasStock(product) &&
      _RecipeExpiryGroup.fromDays(product.days) != _RecipeExpiryGroup.expired;

  @override
  void didUpdateWidget(covariant _RecipeIngredientsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading || widget.error != null) return;

    final availableKeys = widget.products
        .where(_canSelect)
        .map(_productKey)
        .toSet();
    _selectedKeys.retainAll(availableKeys);
  }

  void _toggle(Product product, bool selected) {
    if (!_canSelect(product)) return;

    if (selected && _selectedKeys.length >= _selectionLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione até 3 ingredientes.')),
      );
      return;
    }

    setState(() {
      final key = _productKey(product);
      if (selected) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  void _generate() {
    final available = {
      for (final product in widget.products.where(_canSelect))
        _productKey(product): product,
    };
    final selected = _selectedKeys
        .map((key) => available[key])
        .whereType<Product>()
        .toList();

    if (selected.isEmpty) {
      setState(() => _selectedKeys.clear());
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecipeLoadingScreen(products: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = <_RecipeExpiryGroup, List<Product>>{};
    for (final product in widget.products.where(_hasStock)) {
      final group = _RecipeExpiryGroup.fromDays(product.days);
      (groups[group] ??= []).add(product);
    }

    for (final group in groups.values) {
      group.sort((first, second) {
        final firstDate = first.expiryDate;
        final secondDate = second.expiryDate;
        if (firstDate != null && secondDate != null) {
          final byDate = firstDate.compareTo(secondDate);
          if (byDate != 0) return byDate;
        }
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });
    }

    final count = widget.products
        .where(
          (product) => _canSelect(product) &&
              _selectedKeys.contains(_productKey(product)),
        )
        .length;

    return scroll([
      topbar(
        'Receitas',
        action: IconButton(
          tooltip: 'Pesquisar receitas',
          onPressed: widget.onSearch,
          icon: const Icon(Icons.search),
        ),
      ),
      subtitle('Escolha até 3 ingredientes da sua despensa'),
      OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.people_outline),
        label: const Text('Para quantas pessoas? · Em breve'),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: count == 0 || widget.loading || widget.error != null
            ? null
            : _generate,
        icon: const Icon(Icons.auto_awesome),
        label: Text('Gerar receita ($count/$_selectionLimit)'),
      ),
      const SizedBox(height: 20),
      if (widget.loading)
        const Center(child: CircularProgressIndicator())
      else if (widget.error != null) ...[
        Text(widget.error!, textAlign: TextAlign.center),
        TextButton(
          onPressed: widget.onRetry,
          child: const Text('Tentar novamente'),
        ),
      ] else if (groups.isEmpty)
        const Text(
          'Adicione produtos à despensa para gerar uma receita.',
          textAlign: TextAlign.center,
        )
      else
        for (final group in _RecipeExpiryGroup.values)
          if (groups[group] case final products?) _buildGroup(group, products),
    ]);
  }

  Widget _buildGroup(_RecipeExpiryGroup group, List<Product> products) {
    final expired = group == _RecipeExpiryGroup.expired;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.label, style: type(15, bold: true)),
          const SizedBox(height: 8),
          panel(
            Column(
              children: [
                for (final product in products)
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    value: !expired &&
                        _selectedKeys.contains(_productKey(product)),
                    onChanged: expired
                        ? null
                        : (value) => _toggle(product, value == true),
                    title: Text(product.name),
                    subtitle: Text(
                      product.hasExpiryDate
                          ? '${product.quantityLabel} · ${product.date}'
                          : product.quantityLabel,
                    ),
                  ),
              ],
            ),
            custom: true,
          ),
        ],
      ),
    );
  }
}
