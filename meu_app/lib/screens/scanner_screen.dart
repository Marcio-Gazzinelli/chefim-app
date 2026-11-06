part of '../main.dart';

enum _CameraAccess { checking, granted, denied, permanentlyDenied }

enum _ProductImageAction { camera, gallery, remove }

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.userId});

  final int? userId;

  @override
  State<ScannerPage> createState() {
    return _ScannerPageState();
  }
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final camera = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );

  _CameraAccess cameraAccess = _CameraAccess.checking;

  bool processing = false;
  String? processingMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _requestCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        cameraAccess != _CameraAccess.granted) {
      _checkPermissionAfterSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera.dispose();
    super.dispose();
  }

  Future<void> _requestCamera() async {
    if (mounted) {
      setState(() {
        cameraAccess = _CameraAccess.checking;
      });
    }

    final status = await Permission.camera.request();

    if (!mounted) {
      return;
    }

    if (status.isGranted) {
      setState(() {
        cameraAccess = _CameraAccess.granted;
      });

      _startAfterBuild();
    } else {
      setState(() {
        cameraAccess = status.isPermanentlyDenied
            ? _CameraAccess.permanentlyDenied
            : _CameraAccess.denied;
      });
    }
  }

  Future<void> _checkPermissionAfterSettings() async {
    final status = await Permission.camera.status;

    if (!mounted || !status.isGranted) {
      return;
    }

    setState(() {
      cameraAccess = _CameraAccess.granted;
    });

    _startAfterBuild();
  }

  void _startAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || cameraAccess != _CameraAccess.granted) {
        return;
      }

      try {
        await camera.start();
      } catch (_) {
        if (mounted) {
          setState(() {
            cameraAccess = _CameraAccess.denied;
          });
        }
      }
    });
  }

  Future<void> _resumeScanner() async {
    if (!mounted) {
      return;
    }

    setState(() {
      processing = false;
      processingMessage = null;
    });

    try {
      await camera.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          cameraAccess = _CameraAccess.denied;
        });
      }
    }
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (processing) {
      return;
    }

    ParsedBarcode? parsed;

    for (final barcode in capture.barcodes) {
      parsed = BarcodeParserService.parse(barcode);

      if (parsed != null) {
        break;
      }
    }

    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido ou não reconhecido.')),
      );

      return;
    }

    setState(() {
      processing = true;
      processingMessage = 'Verificando produto...';
    });

    await camera.stop();

    await Future.wait([
      HapticFeedback.mediumImpact(),
      SystemSound.play(SystemSoundType.click),
    ]);

    if (!mounted) {
      return;
    }

    try {
      final existing = await DatabaseService.instance.getProductByBarcode(
        userId: widget.userId,
        barcode: parsed.databaseCode,
      );

      if (!mounted) {
        return;
      }

      if (existing != null) {
        await _handleExistingProduct(existing);
      } else {
        await _handleNewProduct(parsed);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showError(
        'Não foi possível consultar o banco de dados. '
        'Tente novamente.',
      );

      await _resumeScanner();
    }
  }

  Future<void> _handleExistingProduct(Product product) async {
    var currentProduct = product;

    CatalogProduct? catalogProduct;
    LabelScanResult? labelScan;

    final barcode = product.barcode?.trim();

    final needsComplement =
        product.imageUrl?.trim().isNotEmpty != true ||
        product.brand?.trim().isNotEmpty != true ||
        !product.hasNutrition;

    if (needsComplement && barcode != null && barcode.isNotEmpty) {
      setState(() {
        processingMessage = 'Buscando dados atualizados do produto...';
      });

      try {
        catalogProduct = await ProductCatalogService.instance.findByGtin(
          barcode,
        );

        if (catalogProduct != null) {
          currentProduct = _mergeProductWithCatalog(
            currentProduct,
            catalogProduct,
          );

          await DatabaseService.instance.updateProduct(currentProduct);
        }
      } catch (_) {
        // A falta de internet não impede
        // a atualização da quantidade.
      }
    }

    if (!currentProduct.hasNutrition &&
        barcode != null &&
        barcode.isNotEmpty &&
        mounted) {
      labelScan = await _offerLabelPhoto(barcode: barcode);

      if (!mounted) {
        return;
      }

      if (labelScan != null) {
        catalogProduct = _mergeCatalogWithLabel(
          catalogProduct,
          labelScan.catalogProduct,
        );

        final reviewedProduct = await showModalBottomSheet<Product>(
          context: context,
          isScrollControlled: true,
          backgroundColor: surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
          ),
          builder: (_) => _ScannedProductFormSheet(
            barcode: barcode,
            catalogProduct: catalogProduct,
            initialExpiry: currentProduct.expiryDate,
            existingProduct: currentProduct,
          ),
        );

        if (reviewedProduct != null) {
          currentProduct = reviewedProduct;

          await DatabaseService.instance.updateProduct(currentProduct);
        } else {
          labelScan = null;
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      processingMessage = null;
    });

    final amount = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StockIncrementDialog(product: currentProduct),
    );

    if (amount == null) {
      await _resumeScanner();
      return;
    }

    if (mounted) {
      setState(() {
        processingMessage = 'Atualizando estoque...';
      });
    }

    try {
      final updatedProduct = await DatabaseService.instance.updateQuantity(
        product: currentProduct,
        amountToAdd: amount,
      );

      if (labelScan != null) {
        await _sendLabelSuggestion(
          product: updatedProduct,
          labelScan: labelScan,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estoque de ${currentProduct.name} '
            'atualizado.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showError('Não foi possível atualizar a quantidade.');

      await _resumeScanner();
    }
  }

  Future<void> _handleNewProduct(ParsedBarcode parsed) async {
    CatalogProduct? catalogProduct;
    LabelScanResult? labelScan;
    String? catalogWarning;

    if (parsed.gtin != null) {
      if (mounted) {
        setState(() {
          processingMessage = 'Buscando dados do produto...';
        });
      }

      try {
        catalogProduct = await ProductCatalogService.instance.findByGtin(
          parsed.gtin!,
        );

        if (catalogProduct == null) {
          catalogWarning =
              'Produto não encontrado no catálogo. '
              'Complete os dados.';
        }
      } on ProductCatalogException catch (error) {
        catalogWarning = error.message;
      }
    }

    if (parsed.gtin != null &&
        (catalogProduct == null || !catalogProduct.hasNutrition) &&
        mounted) {
      labelScan = await _offerLabelPhoto(barcode: parsed.gtin!);

      if (labelScan != null) {
        catalogProduct = _mergeCatalogWithLabel(
          catalogProduct,
          labelScan.catalogProduct,
        );

        catalogWarning = null;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      processingMessage = null;
    });

    if (catalogWarning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(catalogWarning)));
    }

    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (_) => _ScannedProductFormSheet(
        barcode: parsed.databaseCode,
        catalogProduct: catalogProduct,
        initialExpiry: parsed.expiryDate,
      ),
    );

    if (product == null) {
      await _resumeScanner();
      return;
    }

    if (mounted) {
      setState(() {
        processingMessage = 'Salvando produto...';
      });
    }

    try {
      final savedProduct = await DatabaseService.instance.createProduct(
        product.copyWith(userId: widget.userId),
      );

      if (labelScan != null) {
        await _sendLabelSuggestion(product: savedProduct, labelScan: labelScan);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto cadastrado com sucesso.')),
      );

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showError('Não foi possível salvar o produto.');

      await _resumeScanner();
    }
  }

  Future<LabelScanResult?> _offerLabelPhoto({required String barcode}) async {
    if (!mounted) {
      return null;
    }

    setState(() {
      processingMessage = null;
    });

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Informações nutricionais não encontradas'),
        content: const Text(
          'Fotografe somente a tabela nutricional '
          'ou escolha uma foto nítida da galeria. '
          'Evite reflexos e deixe a coluna de 100 g '
          'completamente visível.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Agora não'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext, ImageSource.gallery);
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeria'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext, ImageSource.camera);
            },
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Câmera'),
          ),
        ],
      ),
    );

    if (source == null || !mounted) {
      return null;
    }

    setState(() {
      processingMessage = 'Analisando o rótulo...';
    });

    try {
      final result = source == ImageSource.camera
          ? await LabelOcrService.instance.captureAndRead(barcode: barcode)
          : await LabelOcrService.instance.chooseFromGalleryAndRead(
              barcode: barcode,
            );

      if (result != null && !result.catalogProduct.hasNutrition && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O texto foi lido, mas os valores '
              'não ficaram claros. Os campos não '
              'identificados deverão ser preenchidos '
              'manualmente.',
            ),
          ),
        );
      } else if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Valores encontrados. Confira cada '
              'campo antes de salvar.',
            ),
          ),
        );
      }

      return result;
    } on LabelOcrException catch (error) {
      if (mounted) {
        await _showError(error.message);
      }

      return null;
    } finally {
      if (mounted) {
        setState(() {
          processingMessage = null;
        });
      }
    }
  }

  CatalogProduct _mergeCatalogWithLabel(
    CatalogProduct? catalog,
    CatalogProduct label,
  ) {
    if (catalog == null) {
      return label;
    }

    final sources = <String>{catalog.source, label.source}.join(' + ');

    return CatalogProduct(
      barcode: catalog.barcode,
      source: sources,
      name: catalog.name ?? label.name,
      brand: catalog.brand ?? label.brand,
      packageQuantity: catalog.packageQuantity ?? label.packageQuantity,
      imageUrl: catalog.imageUrl ?? label.imageUrl,
      ingredients: label.ingredients ?? catalog.ingredients,
      allergens: label.allergens ?? catalog.allergens,
      servingSize: label.servingSize ?? catalog.servingSize,
      energyKcal100g: label.energyKcal100g ?? catalog.energyKcal100g,
      carbohydrates100g: label.carbohydrates100g ?? catalog.carbohydrates100g,
      proteins100g: label.proteins100g ?? catalog.proteins100g,
      fat100g: label.fat100g ?? catalog.fat100g,
      saturatedFat100g: label.saturatedFat100g ?? catalog.saturatedFat100g,
      sugars100g: label.sugars100g ?? catalog.sugars100g,
      fiber100g: label.fiber100g ?? catalog.fiber100g,
      sodium100g: label.sodium100g ?? catalog.sodium100g,
    );
  }

  Product _mergeProductWithCatalog(Product product, CatalogProduct catalog) {
    final sources = <String>{
      if (product.dataSource?.trim().isNotEmpty == true)
        product.dataSource!.trim(),
      catalog.source,
    }.join(' + ');

    return product.copyWith(
      brand: product.brand ?? catalog.brand,

      // Preserva a imagem escolhida pelo usuário.
      imageUrl: product.imageUrl ?? catalog.imageUrl,

      ingredients: product.ingredients ?? catalog.ingredients,
      allergens: product.allergens ?? catalog.allergens,
      servingSize: product.servingSize ?? catalog.servingSize,
      energyKcal100g: product.energyKcal100g ?? catalog.energyKcal100g,
      carbohydrates100g: product.carbohydrates100g ?? catalog.carbohydrates100g,
      proteins100g: product.proteins100g ?? catalog.proteins100g,
      fat100g: product.fat100g ?? catalog.fat100g,
      saturatedFat100g: product.saturatedFat100g ?? catalog.saturatedFat100g,
      sugars100g: product.sugars100g ?? catalog.sugars100g,
      fiber100g: product.fiber100g ?? catalog.fiber100g,
      sodium100g: product.sodium100g ?? catalog.sodium100g,
      dataSource: sources,
    );
  }

  Future<void> _sendLabelSuggestion({
    required Product product,
    required LabelScanResult labelScan,
  }) async {
    try {
      await SupabaseCatalogService.instance.submitLabelSuggestion(
        product: product,
        labelScan: labelScan,
      );
    } on CommunityCatalogException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openManualForm() async {
    await camera.stop();

    if (!mounted) {
      return;
    }

    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (_) {
        return const _ScannedProductFormSheet();
      },
    );

    if (product == null) {
      await _resumeScanner();
      return;
    }

    try {
      await DatabaseService.instance.createProduct(
        product.copyWith(userId: widget.userId),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showError('Não foi possível salvar o produto.');

      await _resumeScanner();
    }
  }

  Future<void> _showError(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Algo deu errado'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cameraAccess == _CameraAccess.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (cameraAccess != _CameraAccess.granted) {
      return _CameraPermissionPage(
        permanentlyDenied: cameraAccess == _CameraAccess.permanentlyDenied,
        retry: _requestCamera,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B100C),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: camera,
              onDetect: _detected,
              errorBuilder: (_, error) {
                return _ScannerError(error: error);
              },
            ),
            const ColoredBox(color: Color(0x22000000)),
            Positioned(
              top: 2,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Escanear produto',
                      textAlign: TextAlign.center,
                      style: type(18, bold: true, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ligar ou desligar lanterna',
                    onPressed: camera.toggleTorch,
                    icon: const Icon(
                      Icons.flash_on_outlined,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Trocar câmera',
                    onPressed: camera.switchCamera,
                    icon: const Icon(
                      Icons.cameraswitch_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Semantics(
                label:
                    'Área para posicionar o código '
                    'de barras',
                child: FractionallySizedBox(
                  widthFactor: .78,
                  child: AspectRatio(
                    aspectRatio: 1.55,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 330),
                      decoration: BoxDecoration(
                        border: Border.all(color: green, width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aponte para um EAN, UPC ou '
                    'QR Code',
                    textAlign: TextAlign.center,
                    style: type(13, bold: true, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: processing ? null : _openManualForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Cadastrar manualmente'),
                  ),
                ],
              ),
            ),
            if (processingMessage != null)
              ColoredBox(
                color: const Color(0x99000000),
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    label: processingMessage,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: green),
                          const SizedBox(height: 14),
                          Text(processingMessage!, style: type(13, bold: true)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraPermissionPage extends StatelessWidget {
  const _CameraPermissionPage({
    required this.permanentlyDenied,
    required this.retry,
  });

  final bool permanentlyDenied;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(title: const Text('Escanear produto')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 64, color: muted),
              const SizedBox(height: 18),
              Text(
                'Permita o acesso à câmera',
                textAlign: TextAlign.center,
                style: type(20, bold: true),
              ),
              const SizedBox(height: 8),
              Text(
                permanentlyDenied
                    ? 'A permissão foi bloqueada. '
                          'Abra as configurações do '
                          'celular e autorize a câmera '
                          'para o Chefim.'
                    : 'O Chefim usa a câmera somente '
                          'para identificar o código do '
                          'produto.',
                textAlign: TextAlign.center,
                style: type(13, color: muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Abrir configurações'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: retry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B100C),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'A câmera não foi autorizada.'
                : 'Não foi possível iniciar a câmera.',
            textAlign: TextAlign.center,
            style: type(14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StockIncrementDialog extends StatefulWidget {
  const _StockIncrementDialog({required this.product});

  final Product product;

  @override
  State<_StockIncrementDialog> createState() {
    return _StockIncrementDialogState();
  }
}

class _StockIncrementDialogState extends State<_StockIncrementDialog> {
  late final double step;
  late double amount;

  @override
  void initState() {
    super.initState();

    step = switch (widget.product.unit) {
      'kg' || 'L' => .1,
      'g' || 'mL' => 100,
      _ => 1,
    };

    amount = step;
  }

  @override
  Widget build(BuildContext context) {
    final newTotal = widget.product.quantity + amount;

    return AlertDialog(
      title: const Text('Produto já cadastrado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.product.name, style: type(16, bold: true)),
          const SizedBox(height: 4),
          Text(
            'Estoque atual: '
            '${widget.product.quantityLabel}',
            style: type(12, color: muted),
          ),
          const SizedBox(height: 18),
          Text('Quantidade a adicionar', style: type(12, bold: true)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Diminuir quantidade',
                onPressed: amount <= step
                    ? null
                    : () {
                        setState(() {
                          amount -= step;
                        });
                      },
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 115,
                child: Text(
                  '${_formatAmount(amount)} '
                  '${widget.product.unit}',
                  textAlign: TextAlign.center,
                  style: type(16, bold: true),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Aumentar quantidade',
                onPressed: () {
                  setState(() {
                    amount += step;
                  });
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Novo total: '
            '${_formatAmount(newTotal)} '
            '${widget.product.unit}',
            style: type(12, color: darkGreen),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, amount);
          },
          child: const Text('Atualizar estoque'),
        ),
      ],
    );
  }
}

class _ScannedProductFormSheet extends StatefulWidget {
  const _ScannedProductFormSheet({
    this.barcode,
    this.catalogProduct,
    this.initialExpiry,
    this.existingProduct,
  });

  final String? barcode;
  final CatalogProduct? catalogProduct;
  final DateTime? initialExpiry;
  final Product? existingProduct;

  @override
  State<_ScannedProductFormSheet> createState() {
    return _ScannedProductFormSheetState();
  }
}

class _ScannedProductFormSheetState extends State<_ScannedProductFormSheet> {
  static const units = ['unidade', 'kg', 'g', 'L', 'mL', 'pacote', 'caixa'];

  final ImagePicker _productImagePicker = ImagePicker();

  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late final TextEditingController energyController;
  late final TextEditingController carbohydratesController;
  late final TextEditingController proteinsController;
  late final TextEditingController fatController;
  late final TextEditingController saturatedFatController;
  late final TextEditingController sugarsController;
  late final TextEditingController fiberController;
  late final TextEditingController sodiumController;

  String unit = 'unidade';
  DateTime? expiryDate;

  String? selectedImageLocation;
  XFile? pendingProductImage;

  bool saving = false;

  bool get isEditing {
    return widget.existingProduct != null;
  }

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.existingProduct?.name ?? widget.catalogProduct?.name ?? '',
    );

    quantityController = TextEditingController(
      text: _formatAmount(widget.existingProduct?.quantity ?? 1),
    );

    final catalog = widget.catalogProduct;
    final existing = widget.existingProduct;

    energyController = _numberController(
      catalog?.energyKcal100g ?? existing?.energyKcal100g,
    );

    carbohydratesController = _numberController(
      catalog?.carbohydrates100g ?? existing?.carbohydrates100g,
    );

    proteinsController = _numberController(
      catalog?.proteins100g ?? existing?.proteins100g,
    );

    fatController = _numberController(catalog?.fat100g ?? existing?.fat100g);

    saturatedFatController = _numberController(
      catalog?.saturatedFat100g ?? existing?.saturatedFat100g,
    );

    sugarsController = _numberController(
      catalog?.sugars100g ?? existing?.sugars100g,
    );

    fiberController = _numberController(
      catalog?.fiber100g ?? existing?.fiber100g,
    );

    final sodium = catalog?.sodium100g ?? existing?.sodium100g;

    sodiumController = _numberController(sodium == null ? null : sodium * 1000);

    unit = widget.existingProduct?.unit ?? 'unidade';

    expiryDate = widget.existingProduct?.expiryDate ?? widget.initialExpiry;

    final initialImage =
        widget.existingProduct?.imageUrl ?? widget.catalogProduct?.imageUrl;

    selectedImageLocation = initialImage?.trim().isEmpty == true
        ? null
        : initialImage?.trim();
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    energyController.dispose();
    carbohydratesController.dispose();
    proteinsController.dispose();
    fatController.dispose();
    saturatedFatController.dispose();
    sugarsController.dispose();
    fiberController.dispose();
    sodiumController.dispose();

    super.dispose();
  }

  TextEditingController _numberController(double? value) {
    return TextEditingController(
      text: value == null ? '' : _formatAmount(value),
    );
  }

  double? _optionalNumber(TextEditingController controller) {
    final text = controller.text.trim();

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text.replaceAll(',', '.'));
  }

  bool _hasInvalidNutritionValue(TextEditingController controller) {
    final text = controller.text.trim();

    if (text.isEmpty) {
      return false;
    }

    final value = _optionalNumber(controller);

    return value == null || value < 0;
  }

  Future<void> _pickExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? today,
      firstDate: DateTime(today.year - 20),
      lastDate: DateTime(today.year + 20, 12, 31),
    );

    if (picked != null && mounted) {
      setState(() {
        expiryDate = picked;
      });
    }
  }

  Future<void> _chooseProductImage() async {
    final hasImage =
        pendingProductImage != null ||
        selectedImageLocation?.trim().isNotEmpty == true;

    final action = await showModalBottomSheet<_ProductImageAction>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto do produto'),
                subtitle: const Text('Fotografe a frente da embalagem'),
                onTap: () {
                  Navigator.pop(sheetContext, _ProductImageAction.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.pop(sheetContext, _ProductImageAction.gallery);
                },
              ),
              if (hasImage)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: red),
                  title: Text('Remover foto', style: type(13, color: red)),
                  onTap: () {
                    Navigator.pop(sheetContext, _ProductImageAction.remove);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () {
                  Navigator.pop(sheetContext);
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

    if (action == _ProductImageAction.remove) {
      setState(() {
        pendingProductImage = null;
        selectedImageLocation = null;
      });

      return;
    }

    final picked = await _productImagePicker.pickImage(
      source: action == _ProductImageAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      pendingProductImage = picked;
      selectedImageLocation = null;
    });
  }

  Future<String?> _persistPendingProductImage() async {
    final pending = pendingProductImage;

    if (pending == null) {
      return selectedImageLocation;
    }

    final databaseDirectory = await getDatabasesPath();

    final originalExtension = p.extension(pending.path).toLowerCase();

    final allowedExtensions = <String>{'.jpg', '.jpeg', '.png', '.webp'};

    final extension = allowedExtensions.contains(originalExtension)
        ? originalExtension
        : '.jpg';

    final barcode = (widget.existingProduct?.barcode ?? widget.barcode ?? '')
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

    final identifier = barcode.isEmpty ? 'manual' : barcode;

    final fileName =
        'chefim_product_${identifier}_'
        '${DateTime.now().millisecondsSinceEpoch}'
        '$extension';

    final destination = p.join(databaseDirectory, fileName);

    await pending.saveTo(destination);

    return destination;
  }

  bool _isRemoteImage(String location) {
    final scheme = Uri.tryParse(location)?.scheme.toLowerCase();

    return scheme == 'http' || scheme == 'https';
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 38, color: darkGreen),
          const SizedBox(height: 6),
          Text('Sem foto', style: type(11, color: muted)),
        ],
      ),
    );
  }

  Widget _imageFromXFile(XFile image) {
    return FutureBuilder(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 140,
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (bytes == null || snapshot.hasError) {
          return _imagePlaceholder();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: 140,
            height: 140,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  Widget _productImagePreview() {
    final pending = pendingProductImage;

    if (pending != null) {
      return _imageFromXFile(pending);
    }

    final location = selectedImageLocation?.trim();

    if (location == null || location.isEmpty) {
      return _imagePlaceholder();
    }

    if (_isRemoteImage(location)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          location,
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _imagePlaceholder();
          },
        ),
      );
    }

    return _imageFromXFile(XFile(location));
  }

  String _resolvedDataSource() {
    final catalogSource = widget.catalogProduct?.source.trim();

    final existingSource = widget.existingProduct?.dataSource?.trim();

    if (catalogSource != null && catalogSource.isNotEmpty) {
      if (catalogSource.contains('leitura automática') &&
          !catalogSource.contains('revisado pelo usuário')) {
        return '$catalogSource + '
            'revisado pelo usuário';
      }

      return catalogSource;
    }

    if (existingSource?.isNotEmpty == true) {
      return existingSource!;
    }

    return 'Cadastro manual';
  }

  Future<void> _submit() async {
    if (saving) {
      return;
    }

    final name = nameController.text.trim();

    final quantity = double.tryParse(
      quantityController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe o nome e uma '
            'quantidade válida.',
          ),
        ),
      );

      return;
    }

    final nutritionControllers = [
      energyController,
      carbohydratesController,
      proteinsController,
      fatController,
      saturatedFatController,
      sugarsController,
      fiberController,
      sodiumController,
    ];

    if (nutritionControllers.any(_hasInvalidNutritionValue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confira os valores nutricionais. '
            'Use apenas números positivos.',
          ),
        ),
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
    });

    String? finalImageLocation;

    try {
      finalImageLocation = await _persistPendingProductImage();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a foto. '
            'Tente escolher outra imagem.',
          ),
        ),
      );

      return;
    }

    if (!mounted) {
      return;
    }

    final catalog = widget.catalogProduct;

    final sodium = _optionalNumber(sodiumController);

    Navigator.pop(
      context,
      Product(
        name,
        expiryDate,
        id: widget.existingProduct?.id,
        userId: widget.existingProduct?.userId,
        quantity: quantity,
        unit: unit,
        calories: widget.existingProduct?.calories,
        barcode: widget.existingProduct?.barcode ?? widget.barcode,
        brand: catalog?.brand ?? widget.existingProduct?.brand,
        imageUrl: finalImageLocation,
        ingredients:
            catalog?.ingredients ?? widget.existingProduct?.ingredients,
        allergens: catalog?.allergens ?? widget.existingProduct?.allergens,
        servingSize:
            catalog?.servingSize ?? widget.existingProduct?.servingSize,
        energyKcal100g: _optionalNumber(energyController),
        carbohydrates100g: _optionalNumber(carbohydratesController),
        proteins100g: _optionalNumber(proteinsController),
        fat100g: _optionalNumber(fatController),
        saturatedFat100g: _optionalNumber(saturatedFatController),
        sugars100g: _optionalNumber(sugarsController),
        fiber100g: _optionalNumber(fiberController),
        sodium100g: sodium == null ? null : sodium / 1000,
        dataSource: _resolvedDataSource(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalogProduct;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Conferir dados do produto' : 'Confirmar produto',
              style: type(20, bold: true),
            ),
            const SizedBox(height: 5),
            Text(
              'Confira os dados antes de '
              'salvar na despensa.',
              style: type(12, color: muted),
            ),
            const SizedBox(height: 14),
            Text('Foto do produto', style: type(12, bold: true)),
            const SizedBox(height: 8),
            Center(child: _productImagePreview()),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: saving ? null : _chooseProductImage,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  pendingProductImage != null ||
                          selectedImageLocation?.trim().isNotEmpty == true
                      ? 'Alterar ou remover foto'
                      : 'Adicionar foto',
                ),
              ),
            ),
            Text(
              'A foto da embalagem é '
              'independente da foto usada para '
              'ler a tabela nutricional.',
              style: type(10, color: muted),
            ),
            if (widget.barcode != null) ...[
              const SizedBox(height: 14),
              Text('Código de barras', style: type(12, bold: true)),
              const SizedBox(height: 5),
              SelectableText(widget.barcode!, style: type(12, color: muted)),
            ],
            if (catalog?.brand != null || catalog?.packageQuantity != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  catalog?.brand,
                  catalog?.packageQuantity,
                ].whereType<String>().join(' • '),
                style: type(11, color: muted),
              ),
            ],
            const SizedBox(height: 16),
            field('Nome do produto', 'Ex.: Feijão', nameController),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    isEditing ? 'Quantidade atual' : 'Quantidade inicial',
                    'Ex.: 1',
                    quantityController,
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
                        initialValue: unit,
                        decoration: input('Unidade'),
                        items: units
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              unit = value;
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
            Text('Data de validade (opcional)', style: type(12, bold: true)),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: saving ? null : _pickExpiry,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  expiryDate == null
                      ? 'Selecionar data'
                      : '${expiryDate!.day.toString().padLeft(2, '0')}/'
                            '${expiryDate!.month.toString().padLeft(2, '0')}/'
                            '${expiryDate!.year}',
                ),
              ),
            ),
            if (expiryDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: saving
                      ? null
                      : () {
                          setState(() {
                            expiryDate = null;
                          });
                        },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remover data'),
                ),
              ),
            if (widget.barcode != null && widget.initialExpiry == null) ...[
              const SizedBox(height: 6),
              Text(
                'A validade não está no EAN '
                'comum. Você pode informar a '
                'data impressa na embalagem ou '
                'deixar este campo vazio.',
                style: type(10, color: muted),
              ),
            ] else if (expiryDate == null) ...[
              const SizedBox(height: 6),
              Text(
                'Você pode cadastrar o produto '
                'sem informar a validade.',
                style: type(10, color: muted),
              ),
            ],
            const SizedBox(height: 14),
            ExpansionTile(
              initiallyExpanded:
                  catalog?.source.contains('Rótulo fotografado') ?? false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                'Informações nutricionais '
                '(opcional)',
                style: type(13, bold: true),
              ),
              subtitle: Text(
                'Valores por 100 g ou 100 mL',
                style: type(10, color: muted),
              ),
              children: [
                if (catalog?.source.contains('Rótulo fotografado') ?? false)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      catalog!.source.contains('parcial')
                          ? 'Alguns valores foram '
                                'extraídos da foto. '
                                'Preencha os campos '
                                'restantes e confira '
                                'todos os dados.'
                          : 'Os valores foram '
                                'extraídos da foto. '
                                'Compare todos eles '
                                'com o rótulo antes '
                                'de salvar.',
                      style: type(10),
                    ),
                  ),
                _nutritionField('Energia (kcal)', energyController),
                _nutritionField('Carboidratos (g)', carbohydratesController),
                _nutritionField('Proteínas (g)', proteinsController),
                _nutritionField('Gorduras totais (g)', fatController),
                _nutritionField(
                  'Gorduras saturadas (g)',
                  saturatedFatController,
                ),
                _nutritionField('Açúcares totais (g)', sugarsController),
                _nutritionField('Fibras (g)', fiberController),
                _nutritionField('Sódio (mg)', sodiumController),
              ],
            ),
            if (catalog != null) ...[
              const SizedBox(height: 8),
              Text(
                'Fonte: ${catalog.source}. '
                'Os dados devem ser conferidos '
                'no rótulo.',
                style: type(10, color: muted),
              ),
            ],
            const SizedBox(height: 20),
            primary(
              saving
                  ? 'Salvando...'
                  : isEditing
                  ? 'Salvar alterações'
                  : 'Salvar produto',
              _submit,
              icon: Icons.check,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutritionField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: field(
        label,
        'Não informado',
        controller,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
