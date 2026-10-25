part of '../main.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key, required this.userId});

  final int? userId;

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  static const List<String> _units = [
    'unidade',
    'kg',
    'g',
    'L',
    'mL',
    'pacote',
    'caixa',
  ];

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _items = <ShoppingItem>[];

  String _unit = 'unidade';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final savedItems = await DatabaseService.instance.getShoppingItems(
        userId: widget.userId,
      );
      if (!mounted) return;

      setState(() {
        _items
          ..clear()
          ..addAll(savedItems);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar a lista de compras.';
      });
    }
  }

  Future<void> _addItem() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o produto e uma quantidade válida.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final savedItem = await DatabaseService.instance.insertShoppingItem(
        ShoppingItem(
          name,
          userId: widget.userId,
          quantity: quantity,
          unit: _unit,
        ),
      );

      if (!mounted) return;

      setState(() {
        _items.add(savedItem);
        _sortItems();
        _saving = false;
        _nameController.clear();
        _quantityController.text = '1';
        _unit = 'unidade';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar o produto.')),
      );
    }
  }

  Future<void> _editItem(ShoppingItem item) async {
    final editedItem = await showModalBottomSheet<ShoppingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (_) => _ShoppingItemFormSheet(item: item),
    );

    if (editedItem == null || !mounted) return;

    try {
      await DatabaseService.instance.updateShoppingItem(editedItem);

      if (!mounted) return;

      setState(() {
        final index = _items.indexWhere((saved) => saved.id == item.id);
        if (index >= 0) {
          _items[index] = editedItem;
          _sortItems();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item atualizado com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o item.')),
      );
    }
  }

  Future<void> _toggleItem(ShoppingItem item, bool checked) async {
    if (item.id == null) return;

    final index = _items.indexWhere((saved) => saved.id == item.id);
    if (index < 0) return;

    final updatedItem = item.copyWith(checked: checked);

    setState(() {
      _items[index] = updatedItem;
      _sortItems();
    });

    try {
      await DatabaseService.instance.updateShoppingItem(updatedItem);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        final currentIndex = _items.indexWhere((saved) => saved.id == item.id);
        if (currentIndex >= 0) {
          _items[currentIndex] = item;
          _sortItems();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o item.')),
      );
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    if (item.id == null) return;

    try {
      await DatabaseService.instance.deleteShoppingItem(item.id!);
      if (!mounted) return;

      setState(() {
        _items.removeWhere((saved) => saved.id == item.id);
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover o item.')),
      );
    }
  }

  Future<void> _clearList() async {
    if (_items.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar lista?'),
        content: const Text(
          'Todos os itens da lista de compras serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DatabaseService.instance.clearShoppingItems(userId: widget.userId);
      if (!mounted) return;

      setState(_items.clear);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível limpar a lista.')),
      );
    }
  }

  void _sortItems() {
    _items.sort((first, second) {
      if (first.checked != second.checked) {
        return first.checked ? 1 : -1;
      }
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _items.where((item) => item.checked).length;

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: scroll([
          topbar('Lista de compras', back: () => Navigator.pop(context)),
          const SizedBox(height: 16),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adicionar item', style: type(13, bold: true)),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: input('Ex.: Arroz'),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: input('Quantidade'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_unit),
                        initialValue: _unit,
                        decoration: input('Unidade'),
                        items: _units
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _unit = value);
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                primary(
                  _saving ? 'Adicionando...' : 'Adicionar à lista',
                  _addItem,
                  icon: Icons.add,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$checkedCount de ${_items.length} comprados',
                  style: type(10, color: muted),
                ),
              ),
              TextButton(
                onPressed: _items.isEmpty ? null : _clearList,
                child: const Text('Limpar lista'),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            panel(
              Column(
                children: [
                  Icon(Icons.error_outline, color: red),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: type(12)),
                  TextButton.icon(
                    onPressed: _loadItems,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(
                  children: [
                    badge(
                      Icons.shopping_cart_outlined,
                      softGreen,
                      darkGreen,
                      size: 66,
                    ),
                    const SizedBox(height: 15),
                    Text('Sua lista está vazia.', style: type(15, bold: true)),
                    Text(
                      'Adicione o primeiro produto!',
                      style: type(12, color: muted),
                    ),
                  ],
                ),
              ),
            )
          else
            panel(
              Column(
                children: [
                  for (int index = 0; index < _items.length; index++) ...[
                    _shoppingItem(_items[index]),
                    if (index < _items.length - 1)
                      Divider(height: 1, color: line),
                  ],
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
        ]),
      ),
    );
  }

  Widget _shoppingItem(ShoppingItem item) {
    return Row(
      children: [
        Checkbox(
          value: item.checked,
          activeColor: green,
          onChanged: (value) => _toggleItem(item, value ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  color: item.checked ? muted : ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(item.quantityLabel, style: type(10, color: muted)),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Opções do item',
          icon: Icon(Icons.more_vert, color: muted),
          onSelected: (action) async {
            if (action == 'edit') {
              await _editItem(item);
            } else if (action == 'delete') {
              await _deleteItem(item);
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
    );
  }
}

class _ShoppingItemFormSheet extends StatefulWidget {
  const _ShoppingItemFormSheet({required this.item});

  final ShoppingItem item;

  @override
  State<_ShoppingItemFormSheet> createState() => _ShoppingItemFormSheetState();
}

class _ShoppingItemFormSheetState extends State<_ShoppingItemFormSheet> {
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

  List<String> get _availableUnits {
    if (_standardUnits.contains(_unit)) return _standardUnits;
    return [_unit, ..._standardUnits];
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(
      text: _formatAmount(widget.item.quantity),
    );
    _unit = widget.item.unit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o produto e uma quantidade válida.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      ShoppingItem(
        name,
        id: widget.item.id,
        userId: widget.item.userId,
        quantity: quantity,
        unit: _unit,
        checked: widget.item.checked,
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
            Text('Editar item', style: type(20, bold: true)),
            const SizedBox(height: 5),
            Text(
              'Altere o nome, a quantidade ou a unidade.',
              style: type(12, color: muted),
            ),
            const SizedBox(height: 20),
            field('Nome do produto', 'Ex.: Arroz', _nameController),
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
                      Text('Unidade', style: type(12, bold: true)),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: input('Unidade'),
                        items: _availableUnits
                            .map(
                              (unit) => DropdownMenuItem<String>(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _unit = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            primary('Salvar alterações', _save),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
