import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';

enum OrderStatus {
  received,
  preparing,
  ready,
  completed,
  cancelled;

  static OrderStatus fromString(String val) {
    return OrderStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == val.toLowerCase(),
      orElse: () => OrderStatus.received,
    );
  }
}

enum OrderType {
  pickup('pickup'),
  dineIn('dine-in'),
  delivery('delivery');

  const OrderType(this.value);
  final String value;

  static OrderType fromString(String val) {
    return OrderType.values.firstWhere(
      (t) => t.value.toLowerCase() == val.toLowerCase() || t.name.toLowerCase() == val.toLowerCase(),
      orElse: () => OrderType.pickup,
    );
  }
}

enum PaymentMethod {
  cash('cash'),
  counter('counter');

  const PaymentMethod(this.value);
  final String value;

  static PaymentMethod fromString(String val) {
    return PaymentMethod.values.firstWhere(
      (p) => p.value.toLowerCase() == val.toLowerCase() || p.name.toLowerCase() == val.toLowerCase(),
      orElse: () => PaymentMethod.counter,
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.itemId,
    required this.name,
    this.customizations = const {},
    required this.qty,
    required this.unitPrice,
    this.note = '',
  });

  final String itemId;
  final String name;
  final Map<String, dynamic> customizations;
  final int qty;
  final double unitPrice;
  final String note;

  double get total => unitPrice * qty;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      customizations: map['customizations'] is Map
          ? Map<String, dynamic>.from(map['customizations'] as Map)
          : {},
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'customizations': customizations,
      'qty': qty,
      'unitPrice': unitPrice,
      'note': note,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItem &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          name == other.name &&
          qty == other.qty &&
          unitPrice == other.unitPrice;

  @override
  int get hashCode => Object.hash(itemId, name, qty, unitPrice);
}

class OrderDraft {
  const OrderDraft({
    required this.userId,
    required this.userName,
    required this.items,
    required this.type,
    this.tableNo,
    this.address,
    this.payment = PaymentMethod.counter,
    this.note,
  });

  final String userId;
  final String userName;
  final List<OrderItem> items;
  final OrderType type;
  final String? tableNo;
  final String? address;
  final PaymentMethod payment;
  final String? note;

  double get total => items.fold(0.0, (sum, item) => sum + item.total);

  void validate() {
    if (items.isEmpty) {
      throw const ValidationFailure('Order must contain at least one item');
    }
    for (final item in items) {
      if (item.qty <= 0) {
        throw ValidationFailure('Item quantity must be greater than zero for ${item.name}');
      }
    }
    if (type == OrderType.dineIn && (tableNo == null || tableNo!.trim().isEmpty)) {
      throw const ValidationFailure('Table number is required for dine-in orders');
    }
    if (type == OrderType.delivery && (address == null || address!.trim().isEmpty)) {
      throw const ValidationFailure('Delivery address is required for delivery orders');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'type': type.value,
      if (tableNo != null) 'tableNo': tableNo,
      if (address != null) 'address': address,
      'payment': payment.value,
      'status': OrderStatus.received.name,
      if (note != null) 'note': note,
    };
  }
}

class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.items,
    required this.total,
    required this.type,
    this.tableNo,
    this.address,
    required this.payment,
    required this.status,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final List<OrderItem> items;
  final double total;
  final OrderType type;
  final String? tableNo;
  final String? address;
  final PaymentMethod payment;
  final OrderStatus status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Order.fromMap(data, id: doc.id);
  }

  factory Order.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((i) => OrderItem.fromMap(Map<String, dynamic>.from(i as Map)))
        .toList();

    return Order(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      items: items,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      type: OrderType.fromString(map['type'] as String? ?? 'pickup'),
      tableNo: map['tableNo'] as String?,
      address: map['address'] as String?,
      payment: PaymentMethod.fromString(map['payment'] as String? ?? 'counter'),
      status: OrderStatus.fromString(map['status'] as String? ?? 'received'),
      note: map['note'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'type': type.value,
      if (tableNo != null) 'tableNo': tableNo,
      if (address != null) 'address': address,
      'payment': payment.value,
      'status': status.name,
      if (note != null) 'note': note,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Order copyWith({
    String? id,
    String? userId,
    String? userName,
    List<OrderItem>? items,
    double? total,
    OrderType? type,
    String? tableNo,
    String? address,
    PaymentMethod? payment,
    OrderStatus? status,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      items: items ?? this.items,
      total: total ?? this.total,
      type: type ?? this.type,
      tableNo: tableNo ?? this.tableNo,
      address: address ?? this.address,
      payment: payment ?? this.payment,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          total == other.total &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, userId, total, status);
}
