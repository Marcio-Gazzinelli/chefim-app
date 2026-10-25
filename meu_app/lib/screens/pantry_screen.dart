part of '../main.dart';

extension _PantryScreen on _ChefimShellState {
  Widget pantry() {
    final expired = products.where((product) => product.days < 0).length;
    final expiring = products
        .where((product) => product.days >= 0 && product.days <= 3)
        .length;
    final hasAlert = expired > 0 || expiring > 0;

    return scroll([
      topbar('Minha despensa'),
      subtitle('Veja seus produtos e o que está perto de vencer.'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: softGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            badge(Icons.notifications_none, Colors.white, darkGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expired > 0
                        ? '$expired produto${expired == 1 ? '' : 's'} vencido'
                              '${expired == 1 ? '' : 's'}'
                        : expiring > 0
                        ? '$expiring produto${expiring == 1 ? '' : 's'} vence'
                              '${expiring == 1 ? '' : 'm'}'
                        : 'Nenhum produto vence',
                    style: type(12, bold: true),
                  ),
                  Text(
                    expired > 0 ? 'Revise sua despensa' : 'nos próximos 3 dias',
                    style: type(
                      12,
                      bold: hasAlert,
                      color: hasAlert ? red : darkGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      primary('Adicionar produto', addProduct, icon: Icons.add),
      if (!productsLoading && productsError == null)
        section(
          'Produtos da despensa',
          '${products.length} ${products.length == 1 ? 'item' : 'itens'}',
        ),
      if (productsLoading)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (!productsLoading && productsError != null)
        panel(
          Column(
            children: [
              Icon(Icons.error_outline, color: red),
              const SizedBox(height: 8),
              Text(
                productsError!,
                textAlign: TextAlign.center,
                style: type(12),
              ),
              TextButton.icon(
                onPressed: loadProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      if (!productsLoading && productsError == null && products.isEmpty)
        panel(
          Column(
            children: [
              Icon(Icons.inventory_2_outlined, color: muted, size: 38),
              const SizedBox(height: 10),
              Text('Sua despensa está vazia.', style: type(13, bold: true)),
              const SizedBox(height: 4),
              Text(
                'Adicione seu primeiro produto.',
                style: type(11, color: muted),
              ),
            ],
          ),
        ),
      if (!productsLoading && productsError == null)
        ...products.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: productCard(product),
          ),
        ),
    ]);
  }

  Widget productCard(Product product) {
    final statusColor = product.days < 0
        ? red
        : product.days <= 3
        ? const Color(0xFFE08A00)
        : darkGreen;

    return panel(
      Row(
        children: [
          badge(Icons.inventory_2_outlined, softGreen, ink, size: 52),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: type(13, bold: true)),
                const SizedBox(height: 3),
                Text(_expiryText(product), style: type(11, color: statusColor)),
                Text(
                  '${product.quantityLabel} • ${product.date}',
                  style: type(10, color: muted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções do produto',
            icon: Icon(Icons.more_vert, color: muted),
            onSelected: (action) async {
              if (action == 'edit') {
                await editProduct(product);
              } else if (action == 'delete') {
                await deleteProduct(product);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 10),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 10),
                    Text('Remover'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _expiryText(Product product) {
    if (product.days < -1) {
      return 'Venceu há ${-product.days} dias';
    }
    if (product.days == -1) return 'Venceu ontem';
    if (product.days == 0) return 'Vence hoje';
    if (product.days == 1) return 'Vence amanhã';
    return 'Vence em ${product.days} dias';
  }

  Future<void> addProduct() {
    return showProductForm();
  }

  Future<void> editProduct(Product product) {
    return showProductForm(product: product);
  }

  Future<void> showProductForm({Product? product}) async {
    final formProduct = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (sheetContext) => _ProductFormSheet(product: product),
    );

    if (formProduct == null || !mounted) return;

    try {
      if (product == null) {
        final productToSave = formProduct.copyWith(userId: currentUserId);
        final savedProduct = await DatabaseService.instance.insertProduct(
          productToSave,
        );

        if (!mounted) return;

        refresh(() {
          products.add(savedProduct);
          _sortProducts();
        });
      } else {
        await DatabaseService.instance.updateProduct(formProduct);

        if (!mounted) return;

        refresh(() {
          final index = products.indexWhere(
            (savedProduct) => savedProduct.id == product.id,
          );
          if (index >= 0) products[index] = formProduct;
          _sortProducts();
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null
                ? 'Produto adicionado com sucesso.'
                : 'Produto atualizado com sucesso.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o produto.')),
      );
    }
  }

  void _sortProducts() {
    products.sort((first, second) {
      final dateResult = first.expiryDate.compareTo(second.expiryDate);
      if (dateResult != 0) return dateResult;
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover produto?'),
        content: Text(
          '${product.name} será removido permanentemente da despensa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DatabaseService.instance.deleteProduct(product.id!);

      if (!mounted) return;

      refresh(() {
        products.removeWhere((savedProduct) => savedProduct.id == product.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto removido da despensa.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover o produto.')),
      );
    }
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({this.product});

  final Product? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  static const List<String> _standardUnits = [
    'unidade',
    'kg',
    'g',
    'L',
    'mL',
    'pacote',
    'caixa',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late String _unit;
  DateTime? _expiryDate;

  bool get _isEditing => widget.product != null;

  List<String> get _availableUnits {
    if (_standardUnits.contains(_unit)) return _standardUnits;
    return [_unit, ..._standardUnits];
  }

  @override
  void initState() {
    super.initState();

    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _quantityController = TextEditingController(
      text: _formatAmount(product?.quantity ?? 1),
    );
    _unit = product?.unit ?? 'unidade';
    _expiryDate = product?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (name.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome, quantidade, unidade e validade.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      Product(
        name,
        _expiryDate!,
        id: widget.product?.id,
        userId: widget.product?.userId,
        quantity: quantity,
        unit: _unit,
        calories: widget.product?.calories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Editar produto' : 'Adicionar produto',
              style: type(20, bold: true),
            ),
            const SizedBox(height: 5),
            Text(
              _isEditing
                  ? 'Atualize as informações do produto.'
                  : 'Inclua um item e acompanhe sua validade.',
              style: type(12, color: muted),
            ),
            const SizedBox(height: 20),
            field('Nome do produto', 'Ex.: Café', _nameController),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    'Quantidade',
                    'Ex.: 1',
                    _quantityController,
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unidade de medida', style: type(12, bold: true)),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: input('Unidade'),
                        items: _availableUnits
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _unit = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Data de vencimento', style: type(12, bold: true)),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final today = DateUtils.dateOnly(DateTime.now());
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? today,
                    firstDate: DateTime(today.year - 20),
                    lastDate: DateTime(today.year + 20, 12, 31),
                  );

                  if (picked != null && mounted) {
                    setState(() => _expiryDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _expiryDate == null
                      ? 'Selecionar data'
                      : '${_expiryDate!.day.toString().padLeft(2, '0')}/'
                            '${_expiryDate!.month.toString().padLeft(2, '0')}/'
                            '${_expiryDate!.year}',
                ),
              ),
            ),
            const SizedBox(height: 18),
            primary(
              _isEditing ? 'Salvar alterações' : 'Adicionar à despensa',
              _submit,
            ),
          ],
        ),
      ),
    );
  }
}
