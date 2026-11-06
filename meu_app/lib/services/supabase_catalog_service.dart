part of '../main.dart';

class CommunityCatalogException implements Exception {
  const CommunityCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Consulta o catálogo comunitário do Chefim e envia sugestões de produtos
/// extraídas de rótulos.
///
/// Os produtos enviados pelos usuários não são publicados automaticamente.
/// Eles ficam aguardando revisão antes de entrarem no catálogo compartilhado.
class SupabaseCatalogService {
  SupabaseCatalogService._();

  static final SupabaseCatalogService instance = SupabaseCatalogService._();

  static const String _catalogTable = 'catalog_products';
  static const String _submissionsTable = 'catalog_submissions';
  static const String _labelBucket = 'catalog-labels';

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String _supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool _initialized = false;
  static bool _initializing = false;

  /// Informa se a URL e a chave foram fornecidas ao executar o aplicativo.
  static bool get isConfigured {
    return _supabaseUrl.trim().isNotEmpty &&
        _supabasePublishableKey.trim().isNotEmpty;
  }

  /// Informa se o Supabase foi configurado e inicializado corretamente.
  static bool get isAvailable {
    return isConfigured && _initialized;
  }

  /// Inicializa o Supabase.
  ///
  /// Caso a inicialização falhe, o restante do aplicativo continua
  /// funcionando com o banco local e com o Open Food Facts.
  static Future<void> initialize() async {
    if (!isConfigured || _initialized || _initializing) {
      return;
    }

    _initializing = true;

    try {
      await Supabase.initialize(
        url: _supabaseUrl.trim(),
        publishableKey: _supabasePublishableKey.trim(),
      );

      _initialized = true;
    } catch (_) {
      _initialized = false;
    } finally {
      _initializing = false;
    }
  }

  SupabaseClient get _client {
    if (!isAvailable) {
      throw const CommunityCatalogException(
        'O catálogo comunitário ainda não foi configurado.',
      );
    }

    return Supabase.instance.client;
  }

  /// Procura um produto pelo código de barras.
  ///
  /// Somente produtos revisados e com `verified = true` são retornados.
  /// Caso o Supabase esteja indisponível, retorna null para permitir que
  /// o aplicativo continue a busca no Open Food Facts.
  Future<CatalogProduct?> findByGtin(String gtin) async {
    if (!isAvailable) {
      return null;
    }

    final barcode = _normalizeBarcode(gtin);

    if (barcode == null) {
      return null;
    }

    try {
      final row = await _client
          .from(_catalogTable)
          .select()
          .eq('barcode', barcode)
          .eq('verified', true)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return CatalogProduct(
        barcode: barcode,
        source: _text(row['source']) ?? 'Catálogo Chefim',
        name: _text(row['name']),
        brand: _text(row['brand']),
        packageQuantity: _text(row['package_quantity']),
        imageUrl: _remoteImageUrl(row['image_url']),
        ingredients: _text(row['ingredients']),
        allergens: _text(row['allergens']),
        servingSize: _text(row['serving_size']),
        energyKcal100g: _number(row['energy_kcal_100g']),
        carbohydrates100g: _number(row['carbohydrates_100g']),
        proteins100g: _number(row['proteins_100g']),
        fat100g: _number(row['fat_100g']),
        saturatedFat100g: _number(row['saturated_fat_100g']),
        sugars100g: _number(row['sugars_100g']),
        fiber100g: _number(row['fiber_100g']),
        sodium100g: _number(row['sodium_100g']),
      );
    } catch (_) {
      // A indisponibilidade do Supabase não deve bloquear o scanner.
      return null;
    }
  }

  /// Envia uma sugestão de produto para revisão.
  ///
  /// A foto do rótulo é enviada ao Storage. Os dados são registrados na
  /// tabela `catalog_submissions`, mas não entram automaticamente no
  /// catálogo aprovado.
  ///
  /// Fotografias salvas somente no aparelho não são gravadas como URL.
  /// Somente endereços HTTP ou HTTPS podem ser enviados em `image_url`.
  Future<bool> submitLabelSuggestion({
    required Product product,
    required LabelScanResult labelScan,
  }) async {
    if (!isAvailable) {
      return false;
    }

    final barcode = _normalizeBarcode(product.barcode);

    if (barcode == null) {
      throw const CommunityCatalogException(
        'Não foi possível enviar a sugestão porque o produto não possui '
        'um código de barras válido.',
      );
    }

    final rawText = labelScan.rawText.trim();

    if (rawText.isEmpty) {
      throw const CommunityCatalogException(
        'Não foi possível enviar a sugestão porque nenhum texto foi '
        'identificado no rótulo.',
      );
    }

    String? uploadedPath;

    try {
      final bytes = await labelScan.image.readAsBytes();

      if (bytes.isEmpty) {
        throw const CommunityCatalogException('A foto do rótulo está vazia.');
      }

      final mimeType = _mimeTypeForImage(labelScan.image);
      final extension = _extensionForMimeType(mimeType);
      final safeBarcode = _safePathPart(barcode);
      final timestamp = DateTime.now().microsecondsSinceEpoch;

      uploadedPath = '$safeBarcode/$timestamp.$extension';

      await _client.storage
          .from(_labelBucket)
          .uploadBinary(
            uploadedPath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Uma imagem salva no celular possui um caminho como:
      // /data/user/0/.../foto.jpg
      //
      // Esse caminho funciona somente naquele aparelho e não pode ser
      // compartilhado com outros usuários. Portanto, somente URLs HTTP
      // ou HTTPS são enviadas ao Supabase.
      final shareableImageUrl = _remoteImageUrl(product.imageLocation);

      await _client.from(_submissionsTable).insert({
        'barcode': barcode,
        'name': _nullableText(product.name),
        'brand': _nullableText(product.brand),
        'image_url': shareableImageUrl,
        'ingredients': _nullableText(product.ingredients),
        'allergens': _nullableText(product.allergens),
        'serving_size': _nullableText(product.servingSize),
        'energy_kcal_100g': _validNumber(product.energyKcal100g),
        'carbohydrates_100g': _validNumber(product.carbohydrates100g),
        'proteins_100g': _validNumber(product.proteins100g),
        'fat_100g': _validNumber(product.fat100g),
        'saturated_fat_100g': _validNumber(product.saturatedFat100g),
        'sugars_100g': _validNumber(product.sugars100g),
        'fiber_100g': _validNumber(product.fiber100g),
        'sodium_100g': _validNumber(product.sodium100g),
        'raw_ocr_text': rawText,
        'label_image_path': uploadedPath,
        'source': _submissionSource(product),
      });

      return true;
    } on CommunityCatalogException {
      if (uploadedPath != null) {
        await _tryRemoveUploadedImage(uploadedPath);
      }

      rethrow;
    } catch (_) {
      if (uploadedPath != null) {
        await _tryRemoveUploadedImage(uploadedPath);
      }

      throw const CommunityCatalogException(
        'O produto foi salvo no celular, mas não foi possível enviar '
        'a sugestão ao catálogo Chefim.',
      );
    }
  }

  /// Tenta apagar a imagem caso o upload tenha funcionado, mas o cadastro
  /// da sugestão tenha falhado.
  Future<void> _tryRemoveUploadedImage(String uploadedPath) async {
    try {
      await _client.storage.from(_labelBucket).remove([uploadedPath]);
    } catch (_) {
      // Essa limpeza é apenas uma tentativa. A falha não impede o
      // funcionamento do aplicativo.
    }
  }

  String _submissionSource(Product product) {
    final currentSource = _nullableText(product.dataSource);

    if (currentSource == null) {
      return 'Rótulo fotografado';
    }

    final normalized = currentSource.toLowerCase();

    if (normalized.contains('rótulo') || normalized.contains('rotulo')) {
      return currentSource;
    }

    return '$currentSource + Rótulo fotografado';
  }

  /// Retorna uma URL somente quando o valor utiliza HTTP ou HTTPS.
  ///
  /// Caminhos locais do Android, iOS ou Windows retornam null.
  String? _remoteImageUrl(Object? value) {
    final text = _text(value);

    if (text == null) {
      return null;
    }

    final uri = Uri.tryParse(text);

    if (uri == null) {
      return null;
    }

    final isHttp = uri.scheme.toLowerCase() == 'http';
    final isHttps = uri.scheme.toLowerCase() == 'https';

    if ((!isHttp && !isHttps) || uri.host.trim().isEmpty) {
      return null;
    }

    return text;
  }

  String? _normalizeBarcode(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '');

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String? _nullableText(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  double? _number(Object? value) {
    double? parsed;

    if (value is num) {
      parsed = value.toDouble();
    } else {
      parsed = double.tryParse(
        value?.toString().trim().replaceAll(',', '.') ?? '',
      );
    }

    return _validNumber(parsed);
  }

  double? _validNumber(double? value) {
    if (value == null || !value.isFinite || value < 0) {
      return null;
    }

    return value;
  }

  String _safePathPart(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

    if (safe.isEmpty) {
      return 'sem-codigo';
    }

    return safe;
  }

  String _mimeTypeForImage(XFile image) {
    final reportedMimeType = image.mimeType
        ?.split(';')
        .first
        .trim()
        .toLowerCase();

    switch (reportedMimeType) {
      case 'image/png':
        return 'image/png';
      case 'image/webp':
        return 'image/webp';
      case 'image/heic':
        return 'image/heic';
      case 'image/heif':
        return 'image/heif';
      case 'image/jpeg':
      case 'image/jpg':
        return 'image/jpeg';
    }

    final extension = p.extension(image.path).toLowerCase();

    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      case '.jpeg':
      case '.jpg':
      default:
        return 'image/jpeg';
    }
  }

  String _extensionForMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'image/jpeg':
      case 'image/jpg':
      default:
        return 'jpg';
    }
  }
}
