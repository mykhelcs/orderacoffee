import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'cart_line.dart';

/// Standard delivery fee in PHP (waived for subtotals >= kFreeDeliveryThreshold).
const double kStandardDeliveryFee = 45.0;
const double kFreeDeliveryThreshold = 500.0;
const double kLoyaltyRewardDiscount = 140.0;

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
      (t) =>
          t.value.toLowerCase() == val.toLowerCase() ||
          t.name.toLowerCase() == val.toLowerCase(),
      orElse: () => OrderType.pickup,
    );
  }
}

enum PaymentMethod {
  cash('cash'),
  counter('counter'),
  gcash('gcash'),
  maya('maya'),
  card('card');

  const PaymentMethod(this.value);
  final String value;

  bool get isPayMongo =>
      this == PaymentMethod.gcash ||
      this == PaymentMethod.maya ||
      this == PaymentMethod.card;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash on delivery',
        PaymentMethod.counter => 'Pay at counter',
        PaymentMethod.gcash => 'GCash',
        PaymentMethod.maya => 'Maya',
        PaymentMethod.card => 'Card',
      };

  String get paymongoMethodType => switch (this) {
        PaymentMethod.gcash => 'gcash',
        PaymentMethod.maya => 'paymaya',
        PaymentMethod.card => 'card',
        _ => 'gcash',
      };

  static PaymentMethod fromString(String val) {
    final lower = val.toLowerCase();
    if (lower == 'paymaya') return PaymentMethod.maya;
    return PaymentMethod.values.firstWhere(
      (p) => p.value.toLowerCase() == lower || p.name.toLowerCase() == lower,
      orElse: () => PaymentMethod.counter,
    );
  }
}

enum PaymentStatus {
  unpaid('unpaid'),
  pending('pending'),
  paid('paid'),
  failed('failed'),
  refunded('refunded');

  const PaymentStatus(this.value);
  final String value;

  static PaymentStatus fromString(String val) {
    return PaymentStatus.values.firstWhere(
      (s) =>
          s.value.toLowerCase() == val.toLowerCase() ||
          s.name.toLowerCase() == val.toLowerCase(),
      orElse: () => PaymentStatus.unpaid,
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

  /// Human-readable summary of size, milk, shots, sugar, ice, and add-ons for barista/customer display.
  String get customizationSummary {
    if (customizations.isEmpty) return '';
    try {
      final parsed = CartCustomizations.fromMap(customizations);
      final summary = parsed.formatSummary(includeDefaultShots: true);
      if (summary.isNotEmpty) return summary;
    } catch (_) {}

    return customizations.values
        .where((v) => v != null && v.toString().isNotEmpty)
        .map((v) {
          if (v is Map) return (v['label'] ?? '').toString();
          if (v is List) {
            return v
                .map((e) => e is Map ? (e['label'] ?? '').toString() : e.toString())
                .where((s) => s.isNotEmpty)
                .join(', ');
          }
          return v.toString();
        })
        .where((s) => s.isNotEmpty)
        .join(' • ');
  }

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
    this.userEmail,
    required this.items,
    required this.type,
    this.tableNo,
    this.address,
    this.payment = PaymentMethod.counter,
    this.paymentStatus = PaymentStatus.unpaid,
    this.note,
    double? subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.rewardCode,
    this.paymongoCheckoutId,
    this.paymongoCheckoutUrl,
    this.paymongoPaymentId,
    this.branchId,
    this.branchName,
    this.branchLat,
    this.branchLng,
    this.deliveryLat,
    this.deliveryLng,
    this.riderLat,
    this.riderLng,
  }) : _explicitSubtotal = subtotal;

  final String userId;
  final String userName;
  final String? userEmail;
  final List<OrderItem> items;
  final OrderType type;
  final String? tableNo;
  final String? address;
  final PaymentMethod payment;
  final PaymentStatus paymentStatus;
  final String? note;
  final double? _explicitSubtotal;
  final double deliveryFee;
  final double discount;
  final String? rewardCode;
  final String? paymongoCheckoutId;
  final String? paymongoCheckoutUrl;
  final String? paymongoPaymentId;
  final String? branchId;
  final String? branchName;
  final double? branchLat;
  final double? branchLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? riderLat;
  final double? riderLng;

  /// Computes standard delivery fee: ₱ 45 for delivery under ₱ 500, free otherwise.
  static double computeDeliveryFee(OrderType type, double subtotal) {
    if (type != OrderType.delivery) return 0.0;
    if (subtotal <= 0) return 0.0;
    return subtotal >= kFreeDeliveryThreshold ? 0.0 : kStandardDeliveryFee;
  }

  double get subtotal =>
      _explicitSubtotal ?? items.fold(0.0, (acc, item) => acc + item.total);

  double get total {
    final raw = subtotal + deliveryFee - discount;
    return raw < 0.0 ? 0.0 : raw;
  }

  void validate() {
    if (items.isEmpty) {
      throw const ValidationFailure('Order must contain at least one item');
    }
    for (final item in items) {
      if (item.qty <= 0) {
        throw ValidationFailure(
            'Item quantity must be greater than zero for ${item.name}');
      }
    }
    if (type == OrderType.dineIn &&
        (tableNo == null || tableNo!.trim().isEmpty)) {
      throw const ValidationFailure(
          'Table number is required for dine-in orders');
    }
    if (type == OrderType.delivery &&
        (address == null || address!.trim().isEmpty)) {
      throw const ValidationFailure(
          'Delivery address is required for delivery orders');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      if (userEmail != null && userEmail!.isNotEmpty) 'userEmail': userEmail,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'discount': discount,
      if (rewardCode != null && rewardCode!.isNotEmpty)
        'rewardCode': rewardCode,
      'total': total,
      'type': type.value,
      if (tableNo != null) 'tableNo': tableNo,
      if (address != null) 'address': address,
      'payment': payment.value,
      'paymentStatus': paymentStatus.value,
      'status': OrderStatus.received.name,
      if (note != null && note!.isNotEmpty) 'note': note,
      if (paymongoCheckoutId != null)
        'paymongoCheckoutId': paymongoCheckoutId,
      if (paymongoCheckoutUrl != null)
        'paymongoCheckoutUrl': paymongoCheckoutUrl,
      if (paymongoPaymentId != null) 'paymongoPaymentId': paymongoPaymentId,
      if (branchId != null) 'branchId': branchId,
      if (branchName != null) 'branchName': branchName,
      if (branchLat != null) 'branchLat': branchLat,
      if (branchLng != null) 'branchLng': branchLng,
      if (deliveryLat != null) 'deliveryLat': deliveryLat,
      if (deliveryLng != null) 'deliveryLng': deliveryLng,
      if (riderLat != null) 'riderLat': riderLat,
      if (riderLng != null) 'riderLng': riderLng,
    };
  }
}

class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.items,
    required this.total,
    required this.type,
    this.tableNo,
    this.address,
    required this.payment,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.status,
    this.note,
    this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.rewardCode,
    this.paymongoCheckoutId,
    this.paymongoCheckoutUrl,
    this.paymongoPaymentId,
    this.branchId,
    this.branchName,
    this.branchLat,
    this.branchLng,
    this.deliveryLat,
    this.deliveryLng,
    this.riderLat,
    this.riderLng,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final List<OrderItem> items;
  final double total;
  final OrderType type;
  final String? tableNo;
  final String? address;
  final PaymentMethod payment;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final String? note;
  final double? subtotal;
  final double deliveryFee;
  final double discount;
  final String? rewardCode;
  final String? paymongoCheckoutId;
  final String? paymongoCheckoutUrl;
  final String? paymongoPaymentId;
  final String? branchId;
  final String? branchName;
  final double? branchLat;
  final double? branchLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? riderLat;
  final double? riderLng;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get computedSubtotal =>
      subtotal ?? items.fold(0.0, (acc, item) => acc + item.total);

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
      userEmail: map['userEmail'] as String?,
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble(),
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      rewardCode: map['rewardCode'] as String?,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      type: OrderType.fromString(map['type'] as String? ?? 'pickup'),
      tableNo: map['tableNo'] as String?,
      address: map['address'] as String?,
      payment: PaymentMethod.fromString(map['payment'] as String? ?? 'counter'),
      paymentStatus:
          PaymentStatus.fromString(map['paymentStatus'] as String? ?? 'unpaid'),
      status: OrderStatus.fromString(map['status'] as String? ?? 'received'),
      note: map['note'] as String?,
      paymongoCheckoutId: map['paymongoCheckoutId'] as String?,
      paymongoCheckoutUrl: map['paymongoCheckoutUrl'] as String?,
      paymongoPaymentId: map['paymongoPaymentId'] as String?,
      branchId: map['branchId'] as String?,
      branchName: map['branchName'] as String?,
      branchLat: (map['branchLat'] as num?)?.toDouble(),
      branchLng: (map['branchLng'] as num?)?.toDouble(),
      deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
      deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
      riderLat: (map['riderLat'] as num?)?.toDouble(),
      riderLng: (map['riderLng'] as num?)?.toDouble(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      if (userEmail != null && userEmail!.isNotEmpty) 'userEmail': userEmail,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': computedSubtotal,
      'deliveryFee': deliveryFee,
      'discount': discount,
      if (rewardCode != null && rewardCode!.isNotEmpty)
        'rewardCode': rewardCode,
      'total': total,
      'type': type.value,
      if (tableNo != null) 'tableNo': tableNo,
      if (address != null) 'address': address,
      'payment': payment.value,
      'paymentStatus': paymentStatus.value,
      'status': status.name,
      if (note != null) 'note': note,
      if (paymongoCheckoutId != null)
        'paymongoCheckoutId': paymongoCheckoutId,
      if (paymongoCheckoutUrl != null)
        'paymongoCheckoutUrl': paymongoCheckoutUrl,
      if (paymongoPaymentId != null) 'paymongoPaymentId': paymongoPaymentId,
      if (branchId != null) 'branchId': branchId,
      if (branchName != null) 'branchName': branchName,
      if (branchLat != null) 'branchLat': branchLat,
      if (branchLng != null) 'branchLng': branchLng,
      if (deliveryLat != null) 'deliveryLat': deliveryLat,
      if (deliveryLng != null) 'deliveryLng': deliveryLng,
      if (riderLat != null) 'riderLat': riderLat,
      if (riderLng != null) 'riderLng': riderLng,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Order copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    String? rewardCode,
    double? total,
    OrderType? type,
    String? tableNo,
    String? address,
    PaymentMethod? payment,
    PaymentStatus? paymentStatus,
    OrderStatus? status,
    String? note,
    String? paymongoCheckoutId,
    String? paymongoCheckoutUrl,
    String? paymongoPaymentId,
    String? branchId,
    String? branchName,
    double? branchLat,
    double? branchLng,
    double? deliveryLat,
    double? deliveryLng,
    double? riderLat,
    double? riderLng,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      rewardCode: rewardCode ?? this.rewardCode,
      total: total ?? this.total,
      type: type ?? this.type,
      tableNo: tableNo ?? this.tableNo,
      address: address ?? this.address,
      payment: payment ?? this.payment,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      note: note ?? this.note,
      paymongoCheckoutId: paymongoCheckoutId ?? this.paymongoCheckoutId,
      paymongoCheckoutUrl: paymongoCheckoutUrl ?? this.paymongoCheckoutUrl,
      paymongoPaymentId: paymongoPaymentId ?? this.paymongoPaymentId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      branchLat: branchLat ?? this.branchLat,
      branchLng: branchLng ?? this.branchLng,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      riderLat: riderLat ?? this.riderLat,
      riderLng: riderLng ?? this.riderLng,
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
          status == other.status &&
          paymentStatus == other.paymentStatus &&
          riderLat == other.riderLat &&
          riderLng == other.riderLng;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        total,
        status,
        paymentStatus,
        riderLat,
        riderLng,
      );
}
