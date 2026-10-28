import 'menu_item.dart';

class CartCustomizations {
  const CartCustomizations({
    this.size,
    this.milk,
    this.sugar,
    this.ice,
    this.addOns = const [],
  });

  final SizeOption? size;
  final MilkOption? milk;
  final String? sugar;
  final String? ice;
  final List<AddOnOption> addOns;

  double get extraPrice {
    double total = 0.0;
    if (size != null) total += size!.delta;
    if (milk != null) total += milk!.delta;
    for (final addOn in addOns) {
      total += addOn.price;
    }
    return total;
  }

  factory CartCustomizations.fromMap(Map<String, dynamic> map) {
    final rawSize = map['size'];
    final size = rawSize is Map<String, dynamic>
        ? SizeOption.fromMap(rawSize)
        : rawSize is Map
            ? SizeOption.fromMap(Map<String, dynamic>.from(rawSize))
            : null;

    final rawMilk = map['milk'];
    final milk = rawMilk is Map<String, dynamic>
        ? MilkOption.fromMap(rawMilk)
        : rawMilk is Map
            ? MilkOption.fromMap(Map<String, dynamic>.from(rawMilk))
            : null;

    final rawAddOns = map['addOns'] as List<dynamic>? ?? [];
    final addOns = rawAddOns
        .map((a) => AddOnOption.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();

    return CartCustomizations(
      size: size,
      milk: milk,
      sugar: map['sugar'] as String?,
      ice: map['ice'] as String?,
      addOns: addOns,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (size != null) 'size': size!.toMap(),
      if (milk != null) 'milk': milk!.toMap(),
      if (sugar != null) 'sugar': sugar,
      if (ice != null) 'ice': ice,
      'addOns': addOns.map((a) => a.toMap()).toList(),
    };
  }

  CartCustomizations copyWith({
    SizeOption? size,
    MilkOption? milk,
    String? sugar,
    String? ice,
    List<AddOnOption>? addOns,
  }) {
    return CartCustomizations(
      size: size ?? this.size,
      milk: milk ?? this.milk,
      sugar: sugar ?? this.sugar,
      ice: ice ?? this.ice,
      addOns: addOns ?? this.addOns,
    );
  }
}

class CartLine {
  const CartLine({
    required this.id,
    required this.itemId,
    required this.name,
    required this.basePrice,
    this.customizations = const CartCustomizations(),
    this.qty = 1,
    this.note = '',
  });

  final String id;
  final String itemId;
  final String name;
  final double basePrice;
  final CartCustomizations customizations;
  final int qty;
  final String note;

  double get unitPrice => basePrice + customizations.extraPrice;
  double get lineTotal => unitPrice * qty;

  factory CartLine.fromMap(Map<String, dynamic> map) {
    final rawCust = map['customizations'];
    final cust = rawCust is Map<String, dynamic>
        ? CartCustomizations.fromMap(rawCust)
        : rawCust is Map
            ? CartCustomizations.fromMap(Map<String, dynamic>.from(rawCust))
            : const CartCustomizations();

    return CartLine(
      id: map['id'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      basePrice: (map['basePrice'] as num?)?.toDouble() ?? 0.0,
      customizations: cust,
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'name': name,
      'basePrice': basePrice,
      'customizations': customizations.toMap(),
      'qty': qty,
      'note': note,
    };
  }

  CartLine copyWith({
    String? id,
    String? itemId,
    String? name,
    double? basePrice,
    CartCustomizations? customizations,
    int? qty,
    String? note,
  }) {
    return CartLine(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      basePrice: basePrice ?? this.basePrice,
      customizations: customizations ?? this.customizations,
      qty: qty ?? this.qty,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartLine &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          itemId == other.itemId &&
          qty == other.qty &&
          note == other.note;

  @override
  int get hashCode => Object.hash(id, itemId, qty, note);
}
