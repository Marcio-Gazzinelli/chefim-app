part of '../main.dart';

/// Consulta produtos do Cosmos por meio de uma Edge Function do Supabase.
///
/// O token do Cosmos nunca é enviado para o aplicativo. A Edge Function
/// consulta primeiro o cache privado no Supabase e somente consome uma
/// consulta da API do Cosmos quando o código ainda não estiver armazenado.
class CosmosCatalogService {
  CosmosCatalogService._();

  static final CosmosCatalogService instance = CosmosCatalogService._();

  static const String _functionName = 'cosmos-lookup';

  Future<CatalogProduct?> findByGtin(String gtin) async {
    if (!SupabaseCatalogService.isAvailable) {
      return null;
    }

    final barcode = _normalizeBarcode(gtin);

    if (barcode == null) {
      return null;
    }

    try {
      final response = await Supabase.instance.client.functions
          .invoke(_functionName, body: {'barcode': barcode})
          .timeout(const Duration(seconds: 15));

      final responseData = response.data;

      if (responseData is! Map || responseData['found'] != true) {
        return null;
      }

      final productData = responseData['product'];

      if (productData is! Map) {
        return null;
      }

      final product = CatalogProduct(
        barcode: barcode,
        source: _text(productData['source']) ?? 'Cosmos',
        name: _text(productData['name']),
        brand: _text(productData['brand']),
        packageQuantity: _text(productData['package_quantity']),
        imageUrl: _remoteImageUrl(productData['image_url']),
      );

      return product.hasUsefulData ? product : null;
    } catch (_) {
      // Uma falha ou o limite diário do Cosmos não deve impedir
      // que o usuário cadastre o produto manualmente.
      return null;
    }
  }

  String? _normalizeBarcode(String value) {
    final normalized = value.replaceAll(RegExp(r'\D'), '');

    const validLengths = <int>{8, 12, 13, 14};

    if (!validLengths.contains(normalized.length)) {
      return null;
    }

    return normalized;
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  String? _remoteImageUrl(Object? value) {
    final text = _text(value);

    if (text == null) {
      return null;
    }

    final uri = Uri.tryParse(text);

    if (uri == null || uri.host.trim().isEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();

    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    return text;
  }
}
