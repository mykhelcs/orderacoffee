import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/errors/failures.dart';
import '../models/cart_line.dart';
import '../models/order.dart';
import 'cart_repository.dart';
import 'menu_repository.dart';

class OrderRepository {
  OrderRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFirestore? get firestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFunctions? get functions {
    if (_functions != null) return _functions;
    try {
      return FirebaseFunctions.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _ordersCol {
    final fs = firestore;
    if (fs == null) return null;
    return fs.collection('orders');
  }

  /// O1: Place order
  Future<String> placeOrder(OrderDraft draft) async {
    draft.validate();

    final fn = functions;
    if (fn != null) {
      try {
        final callable = fn.httpsCallable('placeOrder');
        final res = await callable.call<Map<String, dynamic>>(draft.toMap());
        final orderId = res.data['orderId'] as String?;
        if (orderId != null && orderId.isNotEmpty) {
          return orderId;
        }
      } catch (_) {
        // Fall through to direct Firestore
      }
    }

    final col = _ordersCol;
    if (col == null) {
      // In development/preview before Firebase is configured, generate a deterministic order tag
      return '#${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    try {
      final docRef = await col.add({
        ...draft.toMap(),
        'status': OrderStatus.received.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ValidationFailure('Failed to place order: $e');
    }
  }

  /// O2: Track one order (live stream)
  Stream<Order?> watchOrder(String id) {
    final col = _ordersCol;
    if (col == null || id.isEmpty) return Stream.value(null);
    return col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Order.fromFirestore(doc);
    });
  }

  /// O2 (Future): Get order once
  Future<Order> getOrder(String id) async {
    final col = _ordersCol;
    if (col == null) throw NotFoundFailure('Order not found: $id');
    final doc = await col.doc(id).get();
    if (!doc.exists) {
      throw NotFoundFailure('Order not found: $id');
    }
    return Order.fromFirestore(doc);
  }

  /// O3: Customer's active orders (live stream: received, preparing, ready)
  Stream<List<Order>> watchMyActiveOrders(String uid) {
    final col = _ordersCol;
    if (col == null || uid.isEmpty) return Stream.value(const []);
    return col
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['received', 'preparing', 'ready'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Order.fromFirestore).toList());
  }

  /// O4: Customer's order history (live stream: completed, cancelled)
  Stream<List<Order>> watchHistory(String uid, {int limit = 20}) {
    final col = _ordersCol;
    if (col == null || uid.isEmpty) return Stream.value(const []);
    return col
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Order.fromFirestore).toList());
  }

  /// O4 (Future): Customer's order history paginated
  Future<List<Order>> getOrderHistory(
    String uid, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final col = _ordersCol;
    if (col == null || uid.isEmpty) return const [];
    try {
      Query<Map<String, dynamic>> query = col
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(Order.fromFirestore).toList();
    } catch (e) {
      throw ValidationFailure('Failed to fetch order history: $e');
    }
  }

  /// O5: Reorder: read past order, verify item availability, restore to cart
  Future<List<String>> reorder({
    required String orderId,
    required CartRepository cart,
    required MenuRepository menu,
  }) async {
    final order = await getOrder(orderId);
    final unavailableItems = <String>[];

    for (final orderItem in order.items) {
      try {
        final menuItem = await menu.getItem(orderItem.itemId);
        if (!menuItem.isAvailable || menuItem.isHidden) {
          unavailableItems.add(menuItem.name);
          continue;
        }

        final custMap = orderItem.customizations;
        final customizations = CartCustomizations.fromMap(custMap);

        await cart.addLine(
          menuItem,
          customizations,
          orderItem.qty,
          note: orderItem.note,
        );
      } catch (_) {
        unavailableItems.add(orderItem.name);
      }
    }

    return unavailableItems;
  }

  /// O6: Cancel order (Customer can only cancel while status is 'received')
  Future<void> cancelOrder(String id) async {
    final col = _ordersCol;
    if (col == null) return;
    final docRef = col.doc(id);
    final doc = await docRef.get();
    if (!doc.exists) {
      throw NotFoundFailure('Order not found: $id');
    }

    final currentStatusStr = (doc.data()?['status'] as String?) ?? 'received';
    final currentStatus = OrderStatus.fromString(currentStatusStr);

    if (currentStatus != OrderStatus.received) {
      throw OrderStateFailure(
        'Cannot cancel order in "${currentStatus.name}" status. Cancellation is only allowed when "received".',
      );
    }

    try {
      await docRef.update({
        'status': OrderStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to cancel order: $e');
    }
  }

  /// O7: Live queue for admin/barista (live stream: received, preparing, ready)
  Stream<List<Order>> liveQueue() {
    final col = _ordersCol;
    if (col == null) return Stream.value(const []);
    return col
        .where('status', whereIn: ['received', 'preparing', 'ready'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(Order.fromFirestore).toList());
  }

  /// O8: Advance order status with strict workflow validation
  Future<void> advanceStatus(String id, OrderStatus next) async {
    final col = _ordersCol;
    if (col == null) return;
    final docRef = col.doc(id);
    final doc = await docRef.get();
    if (!doc.exists) {
      throw NotFoundFailure('Order not found: $id');
    }

    final currentStatusStr = (doc.data()?['status'] as String?) ?? 'received';
    final currentStatus = OrderStatus.fromString(currentStatusStr);

    final isValidTransition = switch (currentStatus) {
      OrderStatus.received => next == OrderStatus.preparing || next == OrderStatus.cancelled,
      OrderStatus.preparing => next == OrderStatus.ready,
      OrderStatus.ready => next == OrderStatus.completed,
      OrderStatus.completed => false,
      OrderStatus.cancelled => false,
    };

    if (!isValidTransition) {
      throw OrderStateFailure(
        'Invalid status transition from "${currentStatus.name}" to "${next.name}"',
      );
    }

    try {
      await docRef.update({
        'status': next.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to advance order status: $e');
    }
  }

  /// O9: Completed orders today (Admin)
  Future<List<Order>> getCompletedToday(DateTime startOfDay) async {
    final col = _ordersCol;
    if (col == null) return const [];
    try {
      final snapshot = await col
          .where('status', isEqualTo: OrderStatus.completed.name)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      return snapshot.docs.map(Order.fromFirestore).toList();
    } catch (e) {
      throw ValidationFailure('Failed to fetch completed orders: $e');
    }
  }
}
