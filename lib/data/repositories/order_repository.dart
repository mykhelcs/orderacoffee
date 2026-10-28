import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/errors/failures.dart';
import '../models/cart_line.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import 'cart_repository.dart';
import 'menu_repository.dart';

class OrderRepository {
  OrderRepository({
    this._firestore,
    FirebaseFunctions? functions,
  })  : _functions = functions;

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      firestore.collection('orders');

  /// O1: Place order
  /// Uses Callable Cloud Function if available/configured, otherwise writes directly
  /// with Firestore validation & server timestamps.
  Future<String> placeOrder(OrderDraft draft) async {
    draft.validate();

    if (_functions != null) {
      try {
        final callable = _functions!.httpsCallable('placeOrder');
        final res = await callable.call<Map<String, dynamic>>(draft.toMap());
        final orderId = res.data['orderId'] as String?;
        if (orderId != null && orderId.isNotEmpty) {
          return orderId;
        }
      } catch (e) {
        // If callable fails or is not deployed, fall through to direct Firestore
      }
    }

    try {
      final docRef = await _ordersCol.add({
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
    return _ordersCol.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Order.fromFirestore(doc);
    });
  }

  /// O2 (Future): Get order once
  Future<Order> getOrder(String id) async {
    final doc = await _ordersCol.doc(id).get();
    if (!doc.exists) {
      throw NotFoundFailure('Order not found: $id');
    }
    return Order.fromFirestore(doc);
  }

  /// O3: Customer's active orders (live stream: received, preparing, ready)
  Stream<List<Order>> watchMyActiveOrders(String uid) {
    return _ordersCol
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['received', 'preparing', 'ready'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Order.fromFirestore).toList());
  }

  /// O4: Customer's order history (paginated)
  Future<List<Order>> getOrderHistory(
    String uid, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _ordersCol
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
  /// Returns list of item names that are sold out / unavailable and were skipped.
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

        // Reconstruct customizations
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
    final docRef = _ordersCol.doc(id);
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
    return _ordersCol
        .where('status', whereIn: ['received', 'preparing', 'ready'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(Order.fromFirestore).toList());
  }

  /// O8: Advance order status with strict workflow validation
  /// Valid transitions: received -> preparing -> ready -> completed
  Future<void> advanceStatus(String id, OrderStatus next) async {
    final docRef = _ordersCol.doc(id);
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
    try {
      final snapshot = await _ordersCol
          .where('status', isEqualTo: OrderStatus.completed.name)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      return snapshot.docs.map(Order.fromFirestore).toList();
    } catch (e) {
      throw ValidationFailure('Failed to fetch completed orders: $e');
    }
  }
}
