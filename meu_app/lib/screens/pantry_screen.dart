part of '../main.dart';

enum _PantryImageAction { camera, gallery, remove }

extension _PantryScreen on _ChefimShellState {
  Widget pantry() {
    final expired = products.where((product) {
      final days = product.days;
      return days != null && days < 0;
    }).length;

    final expiring = products.where((product) {
      final days = product.days;

      return days != null && days >= 0 && days <= expiryWarningDays;
    }).length;

    final hasAlert = expired > 0 || expiring > 0;

    final visibleProducts = products.where(_matchesPantryFilter).toList();

    final warningPeriod = expiryWarningDays == 1
        ? 'no próximo dia'
        : 'nos próximos $expiryWarningDays dias';

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
                        ? '$expired produto'
                              '${expired == 1 ? '' : 's'} vencido'
                              '${expired == 1 ? '' : 's'}'
                        : expiring > 0
                        ? '$expiring produto'
                              '${expiring == 1 ? '' : 's'} vence'
                              '${expiring == 1 ? '' : 'm'}'
                        : 'Nenhum produto vence',
                    style: type(12, bold: true),
                  ),
                  Text(
                    expired > 0 ? 'Revise sua despensa' : warningPeriod,
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
      primary(
        'Escanear produto',
        scanProduct,
        icon: Icons.qr_code_scanner_outlined,
        trailing: Icons.chevron_right,
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: addProduct,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar manualmente'),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pantryFilterChip(
            filter: PantryFilter.all,
            label: 'Todos',
            icon: Icons.inventory_2_outlined,
          ),
          _pantryFilterChip(
            filter: PantryFilter.expiring,
            label: 'Próximos',
            icon: Icons.access_time,
          ),
          _pantryFilterChip(
            filter: PantryFilter.expired,
            label: 'Vencidos',
            icon: Icons.event_busy_outlined,
          ),
        ],
      ),
      if (!productsLoading && productsError == null)
        section(
          _pantrySectionTitle(),
          '${visibleProducts.length} '
          '${visibleProducts.length == 1 ? 'item' : 'itens'}',
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
      if (!productsLoading &&
          productsError == null &&
          products.isNotEmpty &&
          visibleProducts.isEmpty)
        _emptyFilteredPantry(),
      if (!productsLoading && productsError == null)
        ...visibleProducts.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: productCard(product),
          ),
        ),
    ]);
  }

  bool _matchesPantryFilter(Product product) {
    final days = product.days;

    switch (pantryFilter) {
      case PantryFilter.all:
        return true;

      case PantryFilter.expiring:
        return days != null && days >= 0 && days <= expiryWarningDays;

      case PantryFilter.expired:
        return days != null && days < 0;
    }
  }

  String _pantrySectionTitle() {
    switch (pantryFilter) {
      case PantryFilter.all:
        return 'Produtos da despensa';

      case PantryFilter.expiring:
        return 'Próximos do vencimento';

      case PantryFilter.expired:
        return 'Produtos vencidos';
    }
  }

  Widget _pantryFilterChip({
    required PantryFilter filter,
    required String label,
    required IconData icon,
  }) {
    final selected = pantryFilter == filter;

    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: green,
      backgroundColor: surface,
      side: BorderSide(color: selected ? green : line),
      avatar: Icon(icon, size: 17, color: selected ? Colors.white : darkGreen),
      label: Text(
        label,
        style: type(10, bold: selected, color: selected ? Colors.white : ink),
      ),
      onSelected: (_) => setPantryFilter(filter),
    );
  }

  Widget _emptyFilteredPantry() {
    final showingExpired = pantryFilter == PantryFilter.expired;

    return panel(
      Column(
        children: [
          Icon(
            showingExpired ? Icons.event_available_outlined : Icons.access_time,
            color: muted,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            showingExpired
                ? 'Nenhum produto vencido.'
                : 'Nenhum produto próximo do vencimento.',
            textAlign: TextAlign.center,
            style: type(13, bold: true),
          ),
          const SizedBox(height: 4),
          Text(
            showingExpired
                ? 'Sua despensa não possui produtos vencidos.'
                : 'O prazo configurado é de '
                      '$expiryWarningDays '
                      '${expiryWarningDays == 1 ? 'dia' : 'dias'}.',
            textAlign: TextAlign.center,
            style: type(11, color: muted),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setPantryFilter(PantryFilter.all);
            },
            child: const Text('Mostrar todos'),
          ),
        ],
      ),
    );
  }

  Widget productCard(Product product) {
    final days = product.days;

    final statusColor = days == null
        ? muted
        : days < 0
        ? red
        : days <= expiryWarningDays
        ? const Color(0xFFE08A00)
        : darkGreen;

    return panel(
      Row(
        children: [
          _productImage(product, size: 56),
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
              if (action == 'details') {
                await showProductDetails(product);
              } else if (action == 'edit') {
                await editProduct(product);
              } else if (action == 'delete') {
                await deleteProduct(product);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 10),
                    Text('Detalhes'),
                  ],
                ),
              ),
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
    final days = product.days;

    if (days == null) {
      return 'Validade não informada';
    }

    if (days < -1) {
      return 'Venceu há ${-days} dias';
    }

    if (days == -1) {
      return 'Venceu ontem';
    }

    if (days == 0) {
      return 'Vence hoje';
    }

    if (days == 1) {
      return 'Vence amanhã';
    }

    return 'Vence em $days dias';
  }

  Future<void> showProductDetails(Product product) {
    final nutrition = <(String, double?, String)>[
      ('Energia', product.energyKcal100g, 'kcal'),
      ('Carboidratos', product.carbohydrates100g, 'g'),
      ('Proteínas', product.proteins100g, 'g'),
      ('Gorduras totais', product.fat100g, 'g'),
      ('Gorduras saturadas', product.saturatedFat100g, 'g'),
      ('Açúcares', product.sugars100g, 'g'),
      ('Fibras', product.fiber100g, 'g'),
      (
        'Sódio',
        product.sodium100g == null ? null : product.sodium100g! * 1000,
        'mg',
      ),
    ];

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasProductImage(product)) ...[
                Center(
                  child: _productImage(product, size: 150, fit: BoxFit.contain),
                ),
                const SizedBox(height: 18),
              ],
              _productDetail('Quantidade', product.quantityLabel),
              _productDetail('Validade', product.date),
              if (product.brand?.trim().isNotEmpty == true)
                _productDetail('Marca', product.brand!.trim()),
              if (product.barcode?.trim().isNotEmpty == true)
                _productDetail('Código', product.barcode!.trim()),
              if (product.servingSize?.trim().isNotEmpty == true)
                _productDetail('Porção', product.servingSize!.trim()),
              if (product.hasNutrition) ...[
                const SizedBox(height: 8),
                Text(
                  'Informação nutricional por 100 g/100 mL',
                  style: type(12, bold: true),
                ),
                const SizedBox(height: 5),
                ...nutrition
                    .where((entry) => entry.$2 != null)
                    .map(
                      (entry) => _productDetail(
                        entry.$1,
                        '${_formatAmount(entry.$2!)} '
                        '${entry.$3}',
                      ),
                    ),
              ],
              if (product.ingredients?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _productDetail('Ingredientes', product.ingredients!.trim()),
              ],
              if (product.allergens?.trim().isNotEmpty == true)
                _productDetail('Alérgenos', product.allergens!.trim()),
              if (product.dataSource?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Fonte: ${product.dataSource!.trim()}. '
                  'Confira os dados no rótulo.',
                  style: type(10, color: muted),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  bool _hasProductImage(Product product) {
    return product.hasImage;
  }

  Widget _productImage(
    Product product, {
    required double size,
    BoxFit fit = BoxFit.cover,
  }) {
    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: softGreen,
        borderRadius: BorderRadius.circular(size >= 100 ? 18 : 14),
        border: Border.all(color: line),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, color: ink, size: size * 0.48),
    );

    final imageLocation = product.imageLocation;

    if (imageLocation == null) {
      return fallback();
    }

    Widget image;

    if (product.imageIsRemote) {
      image = _DataSaverNetworkImage(
        imageUrl: imageLocation,
        width: size,
        height: size,
        fit: fit,
        fallbackBuilder: (_) => fallback(),
      );
    } else {
      image = FutureBuilder<dynamic>(
        future: XFile(imageLocation).readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return fallback();
          }

          if (snapshot.hasError || snapshot.data == null) {
            return fallback();
          }

          return Image.memory(
            snapshot.data,
            width: size,
            height: size,
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return fallback();
            },
          );
        },
      );
    }

    return Semantics(
      label: 'Foto de ${product.name}',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size >= 100 ? 18 : 14),
        child: Container(
          width: size,
          height: size,
          color: Colors.white,
          child: image,
        ),
      ),
    );
  }

  Widget _productDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: type(11, color: muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(value, textAlign: TextAlign.right, style: type(11)),
          ),
        ],
      ),
    );
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
      builder: (sheetContext) {
        return _ProductFormSheet(product: product);
      },
    );

    if (formProduct == null || !mounted) {
      return;
    }

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

          if (index >= 0) {
            products[index] = formProduct;
          }

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
      final firstDate = first.expiryDate;
      final secondDate = second.expiryDate;

      if (firstDate == null && secondDate != null) {
        return 1;
      }

      if (firstDate != null && secondDate == null) {
        return -1;
      }

      if (firstDate != null && secondDate != null) {
        final dateResult = firstDate.compareTo(secondDate);

        if (dateResult != 0) {
          return dateResult;
        }
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover produto?'),
        content: Text(
          '${product.name} será removido '
          'permanentemente da despensa.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

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
  State<_ProductFormSheet> createState() {
    return _ProductFormSheetState();
  }
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

  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _expiryDate;
  XFile? _pendingImage;
  String? _imageLocation;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  bool get _hasImage {
    return _imageLocation?.trim().isNotEmpty == true;
  }

  List<String> get _availableUnits {
    if (_standardUnits.contains(_unit)) {
      return _standardUnits;
    }

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
    _imageLocation = product?.imageLocation;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  bool _isRemoteImage(String location) {
    final lower = location.trim().toLowerCase();

    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<void> _openImageOptions() async {
    if (_saving) {
      return;
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A troca de foto está disponível '
            'no Android e iOS.',
          ),
        ),
      );
      return;
    }

    final action = await showModalBottomSheet<_PantryImageAction>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (actionContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto'),
                onTap: () {
                  Navigator.pop(actionContext, _PantryImageAction.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.pop(actionContext, _PantryImageAction.gallery);
                },
              ),
              if (_hasImage)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: red),
                  title: Text('Remover foto', style: TextStyle(color: red)),
                  onTap: () {
                    Navigator.pop(actionContext, _PantryImageAction.remove);
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _PantryImageAction.remove) {
      setState(() {
        _pendingImage = null;
        _imageLocation = null;
      });
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: action == _PantryImageAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _pendingImage = image;
        _imageLocation = image.path;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível selecionar a foto.')),
      );
    }
  }

  Future<String?> _savePendingImage() async {
    final pendingImage = _pendingImage;

    if (pendingImage == null) {
      final currentLocation = _imageLocation?.trim();

      if (currentLocation == null || currentLocation.isEmpty) {
        return null;
      }

      return currentLocation;
    }

    final databasesDirectory = await getDatabasesPath();

    final originalExtension = p.extension(pendingImage.path).toLowerCase();

    final validExtension = RegExp(r'^\.[a-z0-9]{1,5}$')
        .hasMatch(originalExtension);

    final extension = validExtension ? originalExtension : '.jpg';

    final destination = p.join(
      databasesDirectory,
      'chefim_product_'
      '${DateTime.now().microsecondsSinceEpoch}'
      '$extension',
    );

    await pendingImage.saveTo(destination);

    return destination;
  }

  Widget _imagePreview() {
    const size = 118.0;

    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: softGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.add_a_photo_outlined, color: darkGreen, size: 36),
    );

    final location = _imageLocation?.trim();

    if (location == null || location.isEmpty) {
      return fallback();
    }

    Widget image;

    if (_isRemoteImage(location)) {
      image = _DataSaverNetworkImage(
        imageUrl: location,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallbackBuilder: (_) => fallback(),
      );
    } else {
      image = FutureBuilder<dynamic>(
        future: XFile(location).readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError ||
              snapshot.data == null) {
            return fallback();
          }

          return Image.memory(
            snapshot.data,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return fallback();
            },
          );
        },
      );
    }

    return Semantics(
      label: 'Foto do produto',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(width: size, height: size, child: image),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }

    final name = _nameController.text.trim();

    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome e uma quantidade válida.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      final savedImageLocation = await _savePendingImage();

      if (!mounted) return;

      Navigator.pop(
        context,
        Product(
          name,
          _expiryDate,
          id: widget.product?.id,
          userId: widget.product?.userId,
          quantity: quantity,
          unit: _unit,
          calories: widget.product?.calories,
          barcode: widget.product?.barcode,
          brand: widget.product?.brand,
          imageUrl: savedImageLocation,
          ingredients: widget.product?.ingredients,
          allergens: widget.product?.allergens,
          servingSize: widget.product?.servingSize,
          energyKcal100g: widget.product?.energyKcal100g,
          carbohydrates100g: widget.product?.carbohydrates100g,
          proteins100g: widget.product?.proteins100g,
          fat100g: widget.product?.fat100g,
          saturatedFat100g: widget.product?.saturatedFat100g,
          sugars100g: widget.product?.sugars100g,
          fiber100g: widget.product?.fiber100g,
          sodium100g: widget.product?.sodium100g,
          dataSource: widget.product?.dataSource,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a foto.')),
      );
    }
  }

  Future<void> _selectExpiryDate() async {
    if (_saving) {
      return;
    }

    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? today,
      firstDate: DateTime(today.year - 20),
      lastDate: DateTime(today.year + 20, 12, 31),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _expiryDate = DateUtils.dateOnly(picked);
    });
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
                  : 'Inclua um item. A validade é opcional.',
              style: type(12, color: muted),
            ),
            const SizedBox(height: 20),
            Text('Foto do produto (opcional)', style: type(12, bold: true)),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _imagePreview(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _openImageOptions,
                        icon: Icon(
                          _hasImage
                              ? Icons.photo_camera_back_outlined
                              : Icons.add_a_photo_outlined,
                        ),
                        label: Text(
                          _hasImage ? 'Trocar foto' : 'Adicionar foto',
                        ),
                      ),
                      if (_hasImage)
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _pendingImage = null;
                                    _imageLocation = null;
                                  });
                                },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remover foto'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _unit = value;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Data de vencimento (opcional)', style: type(12, bold: true)),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _selectExpiryDate,
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
            if (_expiryDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _expiryDate = null;
                          });
                        },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remover data'),
                ),
              )
            else ...[
              const SizedBox(height: 7),
              Text(
                'Você pode cadastrar o produto sem '
                'informar a validade.',
                style: type(10, color: muted),
              ),
            ],
            const SizedBox(height: 18),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
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

/// Exibe imagens da internet respeitando a preferência
/// de economia de dados.
///
/// Quando o modo econômico está ativo, a imagem somente
/// é baixada depois de um toque explícito do usuário.
/// Imagens locais não passam por este widget.
class _DataSaverNetworkImage extends StatefulWidget {
  const _DataSaverNetworkImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fit,
    required this.fallbackBuilder,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final WidgetBuilder fallbackBuilder;

  @override
  State<_DataSaverNetworkImage> createState() {
    return _DataSaverNetworkImageState();
  }
}

class _DataSaverNetworkImageState extends State<_DataSaverNetworkImage> {
  bool _loadingPreference = true;
  bool _dataSaverEnabled = true;
  bool _loadThisImage = false;
  int _preferenceRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  @override
  void didUpdateWidget(covariant _DataSaverNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadThisImage = false;
    }

    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final request = ++_preferenceRequest;
    var enabled = true;

    try {
      enabled = await PreferencesService.instance.getDataSaver();
    } catch (_) {
      enabled = true;
    }

    if (!mounted || request != _preferenceRequest) {
      return;
    }

    if (_loadingPreference || enabled != _dataSaverEnabled) {
      setState(() {
        _dataSaverEnabled = enabled;
        _loadingPreference = false;
      });
    }
  }

  Widget _economyPlaceholder() {
    final showText = widget.width >= 100 && widget.height >= 90;

    return Semantics(
      button: true,
      label: 'Carregar foto usando a internet',
      child: Tooltip(
        message: 'Toque para carregar a foto',
        child: Material(
          color: softGreen,
          child: InkWell(
            onTap: () {
              setState(() {
                _loadThisImage = true;
              });
            },
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_download_outlined,
                    color: darkGreen,
                    size: showText ? 32 : widget.width * 0.42,
                  ),
                  if (showText) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Toque para carregar',
                      textAlign: TextAlign.center,
                      style: type(9, color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPreference) {
      return widget.fallbackBuilder(context);
    }

    if (_dataSaverEnabled && !_loadThisImage) {
      return _economyPlaceholder();
    }

    return Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : widget.fallbackBuilder(context);
      },
      errorBuilder: (context, error, stackTrace) {
        return widget.fallbackBuilder(context);
      },
    );
  }
}
