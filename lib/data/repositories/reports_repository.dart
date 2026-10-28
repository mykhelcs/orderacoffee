import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../models/order.dart';
import '../models/sales_summary.dart';

class ReportsRepository {
  ReportsRepository({this._firestore});

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _salesCol =>
      firestore.collection('sales');
  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      firestore.collection('orders');

  /// R1: Watch daily summary for specific date (yyyy-MM-dd)
  Stream<SalesSummary?> watchDailySummary(String dateStr) {
    return _salesCol.doc(dateStr).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SalesSummary.fromFirestore(doc);
    });
  }

  /// R2: Range summary between two dates (inclusive)
  Future<List<SalesSummary>> getRangeSummary({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final snapshot = await _salesCol
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromDate)
          .where(FieldPath.documentId, isLessThanOrEqualTo: toDate)
          .get();
      return snapshot.docs.map(SalesSummary.fromFirestore).toList();
    } catch (e) {
      throw ValidationFailure('Failed to fetch range summary: $e');
    }
  }

  /// R3: Top selling items aggregated from completed orders between two timestamps
  Future<List<Map<String, dynamic>>> getTopItems({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final snapshot = await _ordersCol
          .where('status', isEqualTo: OrderStatus.completed.name)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();

      final countMap = <String, int>{};
      final nameMap = <String, String>{};
      final revenueMap = <String, double>{};

      for (final doc in snapshot.docs) {
        final order = Order.fromFirestore(doc);
        for (final item in order.items) {
          countMap[item.itemId] = (countMap[item.itemId] ?? 0) + item.qty;
          nameMap[item.itemId] = item.name;
          revenueMap[item.itemId] = (revenueMap[item.itemId] ?? 0.0) + item.total;
        }
      }

      final sortedKeys = countMap.keys.toList()
        ..sort((a, b) => (countMap[b] ?? 0).compareTo(countMap[a] ?? 0));

      return sortedKeys.map((itemId) {
        return {
          'itemId': itemId,
          'name': nameMap[itemId] ?? '',
          'qty': countMap[itemId] ?? 0,
          'revenue': revenueMap[itemId] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw ValidationFailure('Failed to aggregate top items: $e');
    }
  }
}
