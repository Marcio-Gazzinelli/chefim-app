part of '../main.dart';

class ParsedBarcode {
  const ParsedBarcode({
    required this.rawValue,
    required this.databaseCode,
    this.gtin,
    this.expiryDate,
  });

  final String rawValue;

  /// Código usado para procurar o produto no SQLite.
  final String databaseCode;

  /// GTIN recuperado de EAN/UPC ou de um QR GS1, quando existente.
  final String? gtin;

  /// Validade existente em um QR/GS1 (AI 17). EAN comum não possui validade.
  final DateTime? expiryDate;
}

class BarcodeParserService {
  const BarcodeParserService._();

  static ParsedBarcode? parse(Barcode barcode) {
    final raw = barcode.rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;

    if (barcode.format == BarcodeFormat.qrCode) {
      final gs1Gtin = _readGs1Value(raw, '01', 14);
      final gs1Expiry = _readGs1Value(raw, '17', 6);
      final gtin = gs1Gtin != null && _isValidGtin(gs1Gtin) ? gs1Gtin : null;

      return ParsedBarcode(
        rawValue: raw,
        databaseCode: gtin ?? raw,
        gtin: gtin,
        expiryDate: _parseGs1Date(gs1Expiry),
      );
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!_isValidGtin(digits)) return null;

    return ParsedBarcode(rawValue: raw, databaseCode: digits, gtin: digits);
  }

  static String? _readGs1Value(String raw, String ai, int length) {
    // Formato legível: (01)078... (17)271231
    final parenthesized = RegExp('\\($ai\\)(\\d{$length})').firstMatch(raw);
    if (parenthesized != null) return parenthesized.group(1);

    // GS1 Digital Link: https://dominio/01/GTIN/17/YYMMDD
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      final segments = uri.pathSegments;
      for (var index = 0; index < segments.length - 1; index++) {
        if (segments[index] == ai &&
            RegExp('^\\d{$length}\$').hasMatch(segments[index + 1])) {
          return segments[index + 1];
        }
      }
    }

    // Conteúdo GS1 bruto, possivelmente iniciado por identificador simbólico.
    final withoutSymbology = raw.replaceFirst(RegExp(r'^\][A-Za-z0-9]{2}'), '');
    final rawMatch = RegExp('(?:^|\u001D)$ai(\\d{$length})')
        .firstMatch(withoutSymbology);
    return rawMatch?.group(1);
  }

  static DateTime? _parseGs1Date(String? value) {
    if (value == null || value.length != 6) return null;

    final yearPart = int.tryParse(value.substring(0, 2));
    final month = int.tryParse(value.substring(2, 4));
    final dayPart = int.tryParse(value.substring(4, 6));
    if (yearPart == null || month == null || dayPart == null) return null;
    if (month < 1 || month > 12) return null;

    final year = 2000 + yearPart;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = dayPart == 0 ? lastDay : dayPart;
    if (day < 1 || day > lastDay) return null;

    return DateTime(year, month, day);
  }

  static bool _isValidGtin(String value) {
    if (!RegExp(r'^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$').hasMatch(value)) {
      return false;
    }

    var sum = 0;
    var multiplier = 3;

    for (var index = value.length - 2; index >= 0; index--) {
      sum += int.parse(value[index]) * multiplier;
      multiplier = multiplier == 3 ? 1 : 3;
    }

    final expectedCheckDigit = (10 - (sum % 10)) % 10;
    return expectedCheckDigit == int.parse(value[value.length - 1]);
  }
}
