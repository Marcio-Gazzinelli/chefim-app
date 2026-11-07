part of '../main.dart';

class Product {
  Product(
    this.name,
    this.expiryDate, {
    this.id,
    this.userId,
    this.quantity = 1,
    this.unit = 'unidade',
    this.calories,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.ingredients,
    this.allergens,
    this.servingSize,
    this.energyKcal100g,
    this.carbohydrates100g,
    this.proteins100g,
    this.fat100g,
    this.saturatedFat100g,
    this.sugars100g,
    this.fiber100g,
    this.sodium100g,
    this.dataSource,
  });

  final int? id;
  final int? userId;
  final String name;

  /// A validade pode não ser informada.
  final DateTime? expiryDate;

  final double quantity;
  final String unit;

  /// Campo legado mantido para não perder dados de versões anteriores.
  final int? calories;

  final String? barcode;
  final String? brand;

  /// Pode armazenar:
  ///
  /// - URL de uma imagem da internet;
  /// - caminho de uma imagem salva localmente no aparelho.
  ///
  /// O nome imageUrl foi mantido para não exigir uma migração no SQLite.
  final String? imageUrl;

  final String? ingredients;
  final String? allergens;
  final String? servingSize;

  /// Valores nutricionais referentes a 100 g ou 100 mL.
  final double? energyKcal100g;
  final double? carbohydrates100g;
  final double? proteins100g;
  final double? fat100g;
  final double? saturatedFat100g;
  final double? sugars100g;
  final double? fiber100g;

  /// O sódio é armazenado em gramas.
  ///
  /// Exemplo: 251 mg são armazenados como 0.251.
  final double? sodium100g;

  final String? dataSource;

  /// Quantidade de dias até o vencimento.
  ///
  /// Retorna null quando a validade não foi informada.
  int? get days {
    final value = expiryDate;

    if (value == null) {
      return null;
    }

    return DateUtils.dateOnly(value)
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
  }

  /// Data de validade formatada.
  String get date {
    final value = expiryDate;

    if (value == null) {
      return 'Não informada';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  bool get hasExpiryDate => expiryDate != null;

  String get quantityLabel {
    return '${_formatAmount(quantity)} '
        '${_displayUnit(unit, quantity)}';
  }

  /// Retorna a localização da imagem sem espaços extras.
  ///
  /// Retorna null quando não existe uma imagem válida.
  String? get imageLocation {
    final value = imageUrl?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  bool get hasImage => imageLocation != null;

  /// Indica se a imagem está hospedada na internet.
  bool get imageIsRemote {
    final value = imageLocation;

    if (value == null) {
      return false;
    }

    final scheme = Uri.tryParse(value)?.scheme.toLowerCase();

    return scheme == 'http' || scheme == 'https';
  }

  /// Indica se a imagem está armazenada no aparelho.
  bool get imageIsLocal {
    return hasImage && !imageIsRemote;
  }

  /// Retorna o caminho local da imagem.
  ///
  /// Também reconhece caminhos que começam com file://.
  String? get localImagePath {
    final value = imageLocation;

    if (value == null || imageIsRemote) {
      return null;
    }

    final uri = Uri.tryParse(value);

    if (uri != null && uri.scheme == 'file') {
      try {
        return uri.toFilePath();
      } catch (_) {
        return value;
      }
    }

    return value;
  }

  bool get hasNutrition {
    return nutritionFieldsCount > 0;
  }

  /// Quantidade de campos nutricionais disponíveis.
  int get nutritionFieldsCount {
    final values = <double?>[
      energyKcal100g,
      carbohydrates100g,
      proteins100g,
      fat100g,
      saturatedFat100g,
      sugars100g,
      fiber100g,
      sodium100g,
    ];

    return values.whereType<double>().length;
  }

  /// Indica se todos os campos nutricionais estão preenchidos.
  bool get hasCompleteNutrition {
    return nutritionFieldsCount == 8;
  }

  Product copyWith({
    int? id,
    int? userId,
    String? name,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    double? quantity,
    String? unit,
    int? calories,
    String? barcode,
    String? brand,
    String? imageUrl,
    bool clearImageUrl = false,
    String? ingredients,
    String? allergens,
    String? servingSize,
    double? energyKcal100g,
    double? carbohydrates100g,
    double? proteins100g,
    double? fat100g,
    double? saturatedFat100g,
    double? sugars100g,
    double? fiber100g,
    double? sodium100g,
    String? dataSource,
  }) {
    return Product(
      name ?? this.name,
      clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      allergens: allergens ?? this.allergens,
      servingSize: servingSize ?? this.servingSize,
      energyKcal100g: energyKcal100g ?? this.energyKcal100g,
      carbohydrates100g: carbohydrates100g ?? this.carbohydrates100g,
      proteins100g: proteins100g ?? this.proteins100g,
      fat100g: fat100g ?? this.fat100g,
      saturatedFat100g: saturatedFat100g ?? this.saturatedFat100g,
      sugars100g: sugars100g ?? this.sugars100g,
      fiber100g: fiber100g ?? this.fiber100g,
      sodium100g: sodium100g ?? this.sodium100g,
      dataSource: dataSource ?? this.dataSource,
    );
  }

  Map<String, Object?> toMap() {
    final expiry = expiryDate;

    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'expiry_date': expiry == null
          ? null
          : DateUtils.dateOnly(expiry).millisecondsSinceEpoch,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
      'barcode': barcode,
      'brand': brand,
      'image_url': imageLocation,
      'ingredients': ingredients,
      'allergens': allergens,
      'serving_size': servingSize,
      'energy_kcal_100g': energyKcal100g,
      'carbohydrates_100g': carbohydrates100g,
      'proteins_100g': proteins100g,
      'fat_100g': fat100g,
      'saturated_fat_100g': saturatedFat100g,
      'sugars_100g': sugars100g,
      'fiber_100g': fiber100g,
      'sodium_100g': sodium100g,
      'data_source': dataSource,
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    final idValue = map['id'];
    final userIdValue = map['user_id'];
    final expiryValue = map['expiry_date'];
    final caloriesValue = map['calories'];

    return Product(
      _readRequiredString(map['name'], fallback: 'Produto sem nome'),
      expiryValue == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((expiryValue as num).toInt()),
      id: idValue == null ? null : (idValue as num).toInt(),
      userId: userIdValue == null ? null : (userIdValue as num).toInt(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unit: _readNullableString(map['unit']) ?? 'unidade',
      calories: caloriesValue == null ? null : (caloriesValue as num).toInt(),
      barcode: _readNullableString(map['barcode']),
      brand: _readNullableString(map['brand']),
      imageUrl: _readNullableString(map['image_url']),
      ingredients: _readNullableString(map['ingredients']),
      allergens: _readNullableString(map['allergens']),
      servingSize: _readNullableString(map['serving_size']),
      energyKcal100g: (map['energy_kcal_100g'] as num?)?.toDouble(),
      carbohydrates100g: (map['carbohydrates_100g'] as num?)?.toDouble(),
      proteins100g: (map['proteins_100g'] as num?)?.toDouble(),
      fat100g: (map['fat_100g'] as num?)?.toDouble(),
      saturatedFat100g: (map['saturated_fat_100g'] as num?)?.toDouble(),
      sugars100g: (map['sugars_100g'] as num?)?.toDouble(),
      fiber100g: (map['fiber_100g'] as num?)?.toDouble(),
      sodium100g: (map['sodium_100g'] as num?)?.toDouble(),
      dataSource: _readNullableString(map['data_source']),
    );
  }
}

class ShoppingItem {
  ShoppingItem(
    this.name, {
    this.id,
    this.userId,
    this.quantity = 1,
    this.unit = 'unidade',
    this.checked = false,
  });

  final int? id;
  final int? userId;
  final String name;
  final double quantity;
  final String unit;
  final bool checked;

  String get quantityLabel {
    return '${_formatAmount(quantity)} '
        '${_displayUnit(unit, quantity)}';
  }

  ShoppingItem copyWith({
    int? id,
    int? userId,
    String? name,
    double? quantity,
    String? unit,
    bool? checked,
  }) {
    return ShoppingItem(
      name ?? this.name,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'checked': checked ? 1 : 0,
    };
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    final idValue = map['id'];
    final userIdValue = map['user_id'];

    return ShoppingItem(
      _readRequiredString(map['name'], fallback: 'Item sem nome'),
      id: idValue == null ? null : (idValue as num).toInt(),
      userId: userIdValue == null ? null : (userIdValue as num).toInt(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unit: _readNullableString(map['unit']) ?? 'unidade',
      checked: (map['checked'] as num?)?.toInt() == 1,
    );
  }
}

String? _readNullableString(Object? value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

String _readRequiredString(Object? value, {required String fallback}) {
  return _readNullableString(value) ?? fallback;
}

String _formatAmount(double value) {
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceAll('.', ',');
}

String _displayUnit(String unit, double quantity) {
  if (quantity == 1) {
    return unit;
  }

  switch (unit) {
    case 'unidade':
      return 'unidades';

    case 'pacote':
      return 'pacotes';

    case 'caixa':
      return 'caixas';

    default:
      return unit;
  }
}
