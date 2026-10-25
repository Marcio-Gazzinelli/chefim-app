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
  });

  final int? id;
  final int? userId;
  final String name;
  final DateTime expiryDate;
  final double quantity;
  final String unit;

  /// Calorias totais da quantidade cadastrada, quando informadas.
  final int? calories;

  int get days =>
      DateUtils.dateOnly(expiryDate)
          .difference(DateUtils.dateOnly(DateTime.now()))
          .inDays;

  String get date =>
      '${expiryDate.day.toString().padLeft(2, '0')}/'
      '${expiryDate.month.toString().padLeft(2, '0')}/'
      '${expiryDate.year}';

  String get quantityLabel =>
      '${_formatAmount(quantity)} ${_displayUnit(unit, quantity)}';

  Product copyWith({
    int? id,
    int? userId,
    String? name,
    DateTime? expiryDate,
    double? quantity,
    String? unit,
    int? calories,
  }) {
    return Product(
      name ?? this.name,
      expiryDate ?? this.expiryDate,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'expiry_date': DateUtils.dateOnly(expiryDate).millisecondsSinceEpoch,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    final idValue = map['id'];
    final userIdValue = map['user_id'];
    final caloriesValue = map['calories'];

    return Product(
      map['name'] as String,
      DateTime.fromMillisecondsSinceEpoch((map['expiry_date'] as num).toInt()),
      id: idValue == null ? null : (idValue as num).toInt(),
      userId: userIdValue == null ? null : (userIdValue as num).toInt(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unit: map['unit'] as String? ?? 'unidade',
      calories: caloriesValue == null ? null : (caloriesValue as num).toInt(),
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

  String get quantityLabel =>
      '${_formatAmount(quantity)} ${_displayUnit(unit, quantity)}';

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
      map['name'] as String,
      id: idValue == null ? null : (idValue as num).toInt(),
      userId: userIdValue == null ? null : (userIdValue as num).toInt(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unit: map['unit'] as String? ?? 'unidade',
      checked: (map['checked'] as num?)?.toInt() == 1,
    );
  }
}

String _formatAmount(double value) {
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceAll('.', ',');
}

String _displayUnit(String unit, double quantity) {
  if (quantity == 1) return unit;

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
