part of '../main.dart';

class LabelOcrException implements Exception {
  const LabelOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LabelScanResult {
  const LabelScanResult({
    required this.catalogProduct,
    required this.rawText,
    required this.image,
  });

  final CatalogProduct catalogProduct;
  final String rawText;
  final XFile image;
}

class _OcrToken {
  const _OcrToken({required this.text, required this.box});

  final String text;
  final Rect box;

  double get centerX => box.left + (box.width / 2);
}

class _OcrLine {
  const _OcrLine({required this.text, required this.box, required this.tokens});

  final String text;
  final Rect box;
  final List<_OcrToken> tokens;

  double get centerY => box.top + (box.height / 2);
}

class _NumberCandidate {
  const _NumberCandidate({required this.value, required this.centerX});

  final double value;
  final double centerX;
}

/// Fotografa uma tabela nutricional e tenta preencher os valores por 100 g
/// ou 100 mL. O resultado sempre deve ser conferido pelo usuário.
class LabelOcrService {
  LabelOcrService._();

  static final LabelOcrService instance = LabelOcrService._();

  final ImagePicker _picker = ImagePicker();

  /// Abre a câmera traseira e analisa a foto capturada.
  Future<LabelScanResult?> captureAndRead({required String barcode}) {
    return _pickAndRead(barcode: barcode, source: ImageSource.camera);
  }

  /// Permite selecionar uma foto existente na galeria.
  Future<LabelScanResult?> chooseFromGalleryAndRead({required String barcode}) {
    return _pickAndRead(barcode: barcode, source: ImageSource.gallery);
  }

  Future<LabelScanResult?> _pickAndRead({
    required String barcode,
    required ImageSource source,
  }) async {
    if (kIsWeb) {
      throw const LabelOcrException(
        'A leitura do rótulo por foto está disponível no Android e no iOS.',
      );
    }

    final image = await _picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 100,
      maxWidth: 3000,
      maxHeight: 3000,
    );

    if (image == null) {
      return null;
    }

    return _readImage(barcode: barcode, image: image);
  }

  Future<LabelScanResult> _readImage({
    required String barcode,
    required XFile image,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text.trim();

      if (rawText.isEmpty) {
        throw const LabelOcrException(
          'Não foi possível identificar textos na foto. '
          'Aproxime a câmera, evite reflexos e mantenha a tabela reta.',
        );
      }

      final lines = recognized.blocks
          .expand((block) => block.lines)
          .map(
            (line) => _OcrLine(
              text: line.text.trim(),
              box: line.boundingBox,
              tokens: line.elements
                  .map(
                    (element) => _OcrToken(
                      text: element.text.trim(),
                      box: element.boundingBox,
                    ),
                  )
                  .where((token) => token.text.isNotEmpty)
                  .toList(),
            ),
          )
          .where((line) => line.text.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        throw const LabelOcrException(
          'O texto foi localizado, mas não pôde ser organizado. '
          'Tente fotografar somente a tabela nutricional.',
        );
      }

      final product = _parseLabel(barcode: barcode, lines: lines);

      return LabelScanResult(
        catalogProduct: product,
        rawText: rawText,
        image: image,
      );
    } on LabelOcrException {
      rethrow;
    } catch (_) {
      throw const LabelOcrException(
        'Não foi possível analisar a foto do rótulo.',
      );
    } finally {
      await recognizer.close();
    }
  }

  CatalogProduct _parseLabel({
    required String barcode,
    required List<_OcrLine> lines,
  }) {
    final hundredColumnX = _findHundredColumnX(lines);

    final energy = _findNutrient(
      lines,
      labels: ['valor energetico', 'energetico', 'energia', 'energ'],
      maximum: 1000,
      hundredColumnX: hundredColumnX,
    );

    final carbohydrates = _findNutrient(
      lines,
      labels: ['carboidratos', 'carboidrato', 'carb'],
      maximum: 100,
      hundredColumnX: hundredColumnX,
    );

    final proteins = _findNutrient(
      lines,
      labels: ['proteinas', 'proteina', 'prot'],
      maximum: 100,
      hundredColumnX: hundredColumnX,
    );

    final fat = _findNutrient(
      lines,
      labels: ['gorduras totais', 'gordura total'],
      excludedLabels: ['saturadas', 'saturada', 'trans'],
      maximum: 100,
      hundredColumnX: hundredColumnX,
    );

    var saturatedFat = _findNutrient(
      lines,
      labels: [
        'gorduras saturadas',
        'gordura saturada',
        'saturadas',
        'saturada',
        'satur',
      ],
      maximum: 100,
      hundredColumnX: hundredColumnX,
    );

    var sugars = _findNutrient(
      lines,
      labels: ['acucares totais', 'acucar total', 'acucares', 'acuc'],
      excludedLabels: ['adicionados', 'adicionado', 'adicion'],
      maximum: 100,
      hundredColumnX: hundredColumnX,
    );

    final fiber = _findNutrient(
      lines,
      labels: [
        'fibras alimentares',
        'fibra alimentar',
        'fibras',
        'fibra',
        'fibr',
      ],
      maximum: 100,
      hundredColumnX: hundredColumnX,
    );

    final sodium = _findNutrient(
      lines,
      labels: ['sodio', 'sodi'],
      maximum: 100000,
      hundredColumnX: hundredColumnX,
      convertMilligramsToGrams: true,
    );

    // Corrige um erro frequente do OCR: reconhecer 8,1 como 81.
    // A correção somente é aplicada quando o resultado fica coerente
    // com o valor total correspondente.
    saturatedFat = _repairPartValue(part: saturatedFat, total: fat);

    sugars = _repairPartValue(part: sugars, total: carbohydrates);

    final nutritionValues = <double?>[
      energy,
      carbohydrates,
      proteins,
      fat,
      saturatedFat,
      sugars,
      fiber,
      sodium,
    ];

    final extractedCount = nutritionValues.whereType<double>().length;

    final String source;

    if (extractedCount == 0) {
      source = 'Preenchimento manual após tentativa de leitura';
    } else if (extractedCount == nutritionValues.length) {
      source = 'Rótulo fotografado (leitura automática)';
    } else {
      source = 'Rótulo fotografado (leitura automática parcial)';
    }

    return CatalogProduct(
      barcode: barcode,
      source: source,
      servingSize: _findServingSize(lines),
      ingredients: _findSection(lines, ['ingredientes']),
      allergens: _findSection(lines, ['alergicos', 'alergico']),
      energyKcal100g: energy,
      carbohydrates100g: carbohydrates,
      proteins100g: proteins,
      fat100g: fat,
      saturatedFat100g: saturatedFat,
      sugars100g: sugars,
      fiber100g: fiber,
      sodium100g: sodium,
    );
  }

  /// Localiza horizontalmente o cabeçalho "100 g" ou "100 mL".
  ///
  /// Com essa posição é possível diferenciar a coluna de 100 g da coluna
  /// referente à porção e da coluna de percentual diário.
  double? _findHundredColumnX(List<_OcrLine> lines) {
    for (final line in lines) {
      for (var index = 0; index < line.tokens.length; index++) {
        final token = line.tokens[index];
        final compact = _normalize(token.text).replaceAll(' ', '');

        if (RegExp(r'^100(?:g|ml)$').hasMatch(compact)) {
          return token.centerX;
        }

        if (compact == '100' && index + 1 < line.tokens.length) {
          final next = _normalize(line.tokens[index + 1].text)
              .replaceAll(' ', '');

          if (next == 'g' || next == 'ml') {
            return token.centerX;
          }
        }
      }

      final match = RegExp(
        r'100\s*(?:g|ml)\b',
        caseSensitive: false,
      ).firstMatch(line.text);

      if (match != null && line.text.isNotEmpty) {
        final middle = (match.start + match.end) / 2;
        final fraction = middle / line.text.length;

        return line.box.left + (line.box.width * fraction);
      }
    }

    return null;
  }

  double? _findNutrient(
    List<_OcrLine> lines, {
    required List<String> labels,
    List<String> excludedLabels = const [],
    required double maximum,
    required double? hundredColumnX,
    bool convertMilligramsToGrams = false,
  }) {
    for (final line in lines) {
      final normalized = _normalize(line.text);

      if (!_matchesAnyLabel(normalized, labels) ||
          _matchesAnyLabel(normalized, excludedLabels)) {
        continue;
      }

      final rowLines = lines
          .where((candidate) => _isSameRow(line, candidate))
          .toList();

      final candidates = <_NumberCandidate>[];

      for (final rowLine in rowLines) {
        final amountBeforeReadingTokens = candidates.length;

        for (final token in rowLine.tokens) {
          candidates.addAll(_extractNumbers(token.text, token.box));
        }

        // Em algumas imagens, o ML Kit identifica a linha, mas não consegue
        // separar corretamente cada elemento da linha.
        if (candidates.length == amountBeforeReadingTokens) {
          candidates.addAll(_extractNumbers(rowLine.text, rowLine.box));
        }
      }

      if (candidates.isEmpty) {
        continue;
      }

      late final _NumberCandidate selected;

      if (hundredColumnX != null) {
        candidates.sort((first, second) {
          final firstDistance = (first.centerX - hundredColumnX).abs();
          final secondDistance = (second.centerX - hundredColumnX).abs();

          return firstDistance.compareTo(secondDistance);
        });

        selected = candidates.first;
      } else {
        // Nas tabelas brasileiras, o primeiro valor normalmente representa
        // a coluna por 100 g ou 100 mL.
        candidates.sort(
          (first, second) => first.centerX.compareTo(second.centerX),
        );

        selected = candidates.first;
      }

      final parsed = selected.value;

      if (!parsed.isFinite || parsed < 0 || parsed > maximum) {
        continue;
      }

      if (convertMilligramsToGrams) {
        final rowText = rowLines.map((rowLine) => rowLine.text).join(' ');
        final normalizedRow = _normalize(rowText);

        // O Product armazena sódio em gramas, mas o rótulo normalmente
        // apresenta o valor em miligramas.
        if (normalizedRow.contains('mg') || parsed > 10) {
          return _rounded(parsed / 1000);
        }
      }

      return _rounded(parsed);
    }

    return null;
  }

  List<_NumberCandidate> _extractNumbers(String text, Rect box) {
    if (text.trim().isEmpty) {
      return const [];
    }

    final matches = RegExp(r'\d+(?:[.,]\d+)?').allMatches(text);

    final result = <_NumberCandidate>[];

    for (final match in matches) {
      final rawValue = match.group(0);

      if (rawValue == null) {
        continue;
      }

      final parsed = double.tryParse(rawValue.replaceAll(',', '.'));

      if (parsed == null) {
        continue;
      }

      final textLength = text.isEmpty ? 1 : text.length;
      final matchMiddle = (match.start + match.end) / 2;
      final fraction = matchMiddle / textLength;

      result.add(
        _NumberCandidate(
          value: parsed,
          centerX: box.left + (box.width * fraction),
        ),
      );
    }

    return result;
  }

  bool _isSameRow(_OcrLine reference, _OcrLine candidate) {
    if (identical(reference, candidate)) {
      return true;
    }

    final top = reference.box.top > candidate.box.top
        ? reference.box.top
        : candidate.box.top;

    final bottom = reference.box.bottom < candidate.box.bottom
        ? reference.box.bottom
        : candidate.box.bottom;

    final overlap = bottom - top;

    final smallerHeight = reference.box.height < candidate.box.height
        ? reference.box.height
        : candidate.box.height;

    if (overlap > 0 && overlap >= smallerHeight * 0.25) {
      return true;
    }

    final largerHeight = reference.box.height > candidate.box.height
        ? reference.box.height
        : candidate.box.height;

    final centerDistance = (reference.centerY - candidate.centerY).abs();

    return centerDistance <= (largerHeight * 0.75) + 4;
  }

  double? _repairPartValue({required double? part, required double? total}) {
    if (part == null || total == null || part <= total) {
      return part;
    }

    final dividedByTen = part / 10;

    if (dividedByTen <= total) {
      return _rounded(dividedByTen);
    }

    final dividedByHundred = part / 100;

    if (dividedByHundred <= total) {
      return _rounded(dividedByHundred);
    }

    // Um valor parcial não pode ser maior que seu total. É mais seguro
    // deixar o campo vazio do que salvar um valor possivelmente incorreto.
    return null;
  }

  String? _findServingSize(List<_OcrLine> lines) {
    for (var index = 0; index < lines.length; index++) {
      final normalized = _normalize(lines[index].text);

      if (!normalized.contains('porcao')) {
        continue;
      }

      final values = <String>[lines[index].text];

      if (index + 1 < lines.length) {
        values.add(lines[index + 1].text);
      }

      final combined = values.join(' ');

      final match = RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
        caseSensitive: false,
      ).firstMatch(combined);

      if (match != null) {
        return '${match.group(1)} '
            '${match.group(2)?.toLowerCase()}';
      }
    }

    return null;
  }

  String? _findSection(List<_OcrLine> lines, List<String> labels) {
    for (var index = 0; index < lines.length; index++) {
      final normalized = _normalize(lines[index].text);

      if (!_matchesAnyLabel(normalized, labels)) {
        continue;
      }

      final separator = lines[index].text.indexOf(':');
      final values = <String>[];

      if (separator >= 0 && separator < lines[index].text.length - 1) {
        values.add(lines[index].text.substring(separator + 1).trim());
      }

      for (
        var next = index + 1;
        next < lines.length && next <= index + 2;
        next++
      ) {
        final nextNormalized = _normalize(lines[next].text);

        if (_isAnotherSection(nextNormalized)) {
          break;
        }

        values.add(lines[next].text);
      }

      final result = values
          .where((value) => value.trim().isNotEmpty)
          .join(' ')
          .trim();

      return result.isEmpty ? null : result;
    }

    return null;
  }

  bool _matchesAnyLabel(String value, List<String> labels) {
    if (labels.isEmpty) {
      return false;
    }

    return labels.any((label) => _matchesLabel(value, _normalize(label)));
  }

  bool _matchesLabel(String value, String label) {
    if (value.contains(label)) {
      return true;
    }

    final valueWords = value
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();

    final labelWords = label
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (valueWords.isEmpty || labelWords.isEmpty) {
      return false;
    }

    return labelWords.every(
      (labelWord) =>
          valueWords.any((valueWord) => _wordsAreSimilar(valueWord, labelWord)),
    );
  }

  bool _wordsAreSimilar(String value, String expected) {
    if (value == expected) {
      return true;
    }

    if (expected.length >= 4 && value.length >= expected.length) {
      final prefix = value.substring(0, expected.length);

      final allowedPrefixErrors = expected.length <= 5 ? 1 : 2;

      if (_levenshtein(prefix, expected) <= allowedPrefixErrors) {
        return true;
      }
    }

    if (value.length < 4 || expected.length < 4) {
      return false;
    }

    final longestLength = value.length > expected.length
        ? value.length
        : expected.length;

    final allowedErrors = longestLength <= 6 ? 1 : 2;

    return _levenshtein(value, expected) <= allowedErrors;
  }

  int _levenshtein(String first, String second) {
    if (first == second) {
      return 0;
    }

    if (first.isEmpty) {
      return second.length;
    }

    if (second.isEmpty) {
      return first.length;
    }

    var previous = List<int>.generate(second.length + 1, (index) => index);

    for (var firstIndex = 0; firstIndex < first.length; firstIndex++) {
      final current = List<int>.filled(second.length + 1, 0);

      current[0] = firstIndex + 1;

      for (var secondIndex = 0; secondIndex < second.length; secondIndex++) {
        final insertion = current[secondIndex] + 1;
        final deletion = previous[secondIndex + 1] + 1;

        final substitution =
            previous[secondIndex] +
            (first[firstIndex] == second[secondIndex] ? 0 : 1);

        var smallest = insertion < deletion ? insertion : deletion;

        if (substitution < smallest) {
          smallest = substitution;
        }

        current[secondIndex + 1] = smallest;
      }

      previous = current;
    }

    return previous.last;
  }

  bool _isAnotherSection(String value) {
    return value.contains('informacao nutricional') ||
        value.contains('alergico') ||
        value.contains('ingredientes') ||
        value.contains('conservacao') ||
        value.contains('validade');
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9%]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _rounded(double value) {
    return double.parse(value.toStringAsFixed(4));
  }
}
