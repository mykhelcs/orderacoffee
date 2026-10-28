import 'package:cloud_firestore/cloud_firestore.dart';

class SizeOption {
  const SizeOption({required this.label, required this.delta});

  final String label;
  final double delta;

  factory SizeOption.fromMap(Map<String, dynamic> map) {
    return SizeOption(
      label: map['label'] as String? ?? '',
      delta: (map['delta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'delta': delta};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          delta == other.delta;

  @override
  int get hashCode => Object.hash(label, delta);
}

class MilkOption {
  const MilkOption({required this.label, required this.delta});

  final String label;
  final double delta;

  factory MilkOption.fromMap(Map<String, dynamic> map) {
    return MilkOption(
      label: map['label'] as String? ?? '',
      delta: (map['delta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'delta': delta};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilkOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          delta == other.delta;

  @override
  int get hashCode => Object.hash(label, delta);
}

class AddOnOption {
  const AddOnOption({required this.label, required this.price});

  final String label;
  final double price;

  factory AddOnOption.fromMap(Map<String, dynamic> map) {
    return AddOnOption(
      label: map['label'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'price': price};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddOnOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          price == other.price;

  @override
  int get hashCode => Object.hash(label, price);
}

class MenuOptions {
  const MenuOptions({
    this.sizes = const [],
    this.milks = const [],
    this.sugar = const [],
    this.ice = const [],
    this.addOns = const [],
  });

  final List<SizeOption> sizes;
  final List<MilkOption> milks;
  final List<String> sugar;
  final List<String> ice;
  final List<AddOnOption> addOns;

  factory MenuOptions.fromMap(Map<String, dynamic> map) {
    final rawSizes = map['sizes'] as List<dynamic>? ?? [];
    final sizes = rawSizes
        .map((s) => SizeOption.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();

    final rawMilks = map['milks'] as List<dynamic>? ?? [];
    final milks = rawMilks
        .map((m) => MilkOption.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final rawSugar = map['sugar'] as List<dynamic>? ?? [];
    final sugar = rawSugar.map((s) => s.toString()).toList();

    final rawIce = map['ice'] as List<dynamic>? ?? [];
    final ice = rawIce.map((i) => i.toString()).toList();

    final rawAddOns = map['addOns'] as List<dynamic>? ?? [];
    final addOns = rawAddOns
        .map((a) => AddOnOption.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();

    return MenuOptions(
      sizes: sizes,
      milks: milks,
      sugar: sugar,
      ice: ice,
      addOns: addOns,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sizes': sizes.map((s) => s.toMap()).toList(),
      'milks': milks.map((m) => m.toMap()).toList(),
      'sugar': sugar,
      'ice': ice,
      'addOns': addOns.map((a) => a.toMap()).toList(),
    };
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
    this.imageUrl,
    this.isAvailable = true,
    this.isHidden = false,
    this.options = const MenuOptions(),
    this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double basePrice;
  final String? imageUrl;
  final bool isAvailable;
  final bool isHidden;
  final MenuOptions options;
  final DateTime? updatedAt;

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return MenuItem.fromMap(data, id: doc.id);
  }

  factory MenuItem.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parsedUpdatedAt;
    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is Timestamp) {
      parsedUpdatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    } else if (rawUpdatedAt is int) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt);
    }

    final rawOptions = map['options'];
    final options = rawOptions is Map<String, dynamic>
        ? MenuOptions.fromMap(rawOptions)
        : rawOptions is Map
            ? MenuOptions.fromMap(Map<String, dynamic>.from(rawOptions))
            : const MenuOptions();

    return MenuItem(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      description: map['description'] as String? ?? '',
      basePrice: (map['basePrice'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
      isHidden: map['isHidden'] as bool? ?? false,
      options: options,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'basePrice': basePrice,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'isHidden': isHidden,
      'options': options.toMap(),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    double? basePrice,
    String? imageUrl,
    bool? isAvailable,
    bool? isHidden,
    MenuOptions? options,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isHidden: isHidden ?? this.isHidden,
      options: options ?? this.options,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          basePrice == other.basePrice &&
          isAvailable == other.isAvailable &&
          isHidden == other.isHidden;

  @override
  int get hashCode => Object.hash(id, name, category, basePrice, isAvailable, isHidden);
}
