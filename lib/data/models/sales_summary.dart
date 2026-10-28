import 'package:cloud_firestore/cloud_firestore.dart';

class SalesSummary {
  const SalesSummary({
    required this.date,
    required this.orderCount,
    required this.revenue,
  });

  final String date;
  final int orderCount;
  final double revenue;

  factory SalesSummary.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SalesSummary.fromMap(data, date: doc.id);
  }

  factory SalesSummary.fromMap(Map<String, dynamic> map, {required String date}) {
    return SalesSummary(
      date: date,
      orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderCount': orderCount,
      'revenue': revenue,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesSummary &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          orderCount == other.orderCount &&
          revenue == other.revenue;

  @override
  int get hashCode => Object.hash(date, orderCount, revenue);
}
