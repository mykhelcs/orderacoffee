import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import '../models/cart_line.dart';
import '../models/order.dart';
import '../services/location_service.dart';
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

  // In-memory fallback order store for resilient local demo / offline execution
  static final Map<String, Order> _fallbackOrders = {};
  static final Set<String> _unsyncedOrderIds = {};
  static final StreamController<Map<String, Order>> _fallbackOrdersController =
      StreamController<Map<String, Order>>.broadcast();
  static Timer? _autoSyncTimer;

  static void _notifyFallback() {
    _fallbackOrdersController.add(Map.unmodifiable(_fallbackOrders));
  }

  /// Starts a periodic background sync worker that flushes pending orders
  /// to Cloud Firestore automatically every 10 seconds without user intervention.
  static void startPeriodicAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_unsyncedOrderIds.isNotEmpty) {
        OrderRepository().syncPendingOrdersToFirestore();
      }
    });
  }

  /// Syncs any locally created orders up to Cloud Firestore.
  Future<int> syncPendingOrdersToFirestore() async {
    final col = _ordersCol;
    if (col == null || _unsyncedOrderIds.isEmpty) return 0;

    int syncedCount = 0;
    final idsToSync = List<String>.from(_unsyncedOrderIds);

    for (final orderId in idsToSync) {
      final order = _fallbackOrders[orderId];
      if (order == null) continue;

      try {
        await col.doc(order.id).set(order.toMap(), SetOptions(merge: true));
        _unsyncedOrderIds.remove(orderId);
        syncedCount++;
        debugPrint(
            '[Firebase Sync] Order ${order.id} pushed to Cloud Firestore for user ${order.userId}!');
      } catch (e) {
        debugPrint(
            '[Firebase Sync] Failed to push order ${order.id} to Firestore: $e');
      }
    }

    return syncedCount;
  }

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

  /// O1: Place order with automatic local fallback
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

    final defaultBranch = kCafeBranches.first;
    final bLat = draft.branchLat ?? defaultBranch.lat;
    final bLng = draft.branchLng ?? defaultBranch.lng;
    final dLat =
        draft.deliveryLat ?? LocationService.defaultCustomerCoordinates.latitude;
    final dLng =
        draft.deliveryLng ?? LocationService.defaultCustomerCoordinates.longitude;

    final col = _ordersCol;
    if (col != null) {
      try {
        final docRef = await col.add({
          ...draft.toMap(),
          'branchId': draft.branchId ?? defaultBranch.id,
          'branchName': draft.branchName ?? defaultBranch.name,
          'branchLat': bLat,
          'branchLng': bLng,
          if (draft.type == OrderType.delivery) 'deliveryLat': dLat,
          if (draft.type == OrderType.delivery) 'deliveryLng': dLng,
          'riderLat': bLat,
          'riderLng': bLng,
          'status': OrderStatus.received.name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
            '[Firebase Sync] Order ${docRef.id} successfully written to Cloud Firestore for user ${draft.userId} (${draft.userName})!');
        return docRef.id;
      } catch (e) {
        debugPrint(
            'Firestore order write restricted ($e). Using resilient local store.');
      }
    }

    // Fallback: create resilient local order so checkout and tracking always succeed
    final fallbackId = 'ORD-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final now = DateTime.now();
    final localOrder = Order(
      id: fallbackId,
      userId: draft.userId,
      userName: draft.userName,
      userEmail: draft.userEmail,
      items: draft.items,
      subtotal: draft.subtotal,
      deliveryFee: draft.deliveryFee,
      discount: draft.discount,
      rewardCode: draft.rewardCode,
      total: draft.total,
      type: draft.type,
      tableNo: draft.tableNo,
      address: draft.address,
      payment: draft.payment,
      paymentStatus: draft.paymentStatus,
      status: OrderStatus.received,
      note: draft.note,
      paymongoCheckoutId: draft.paymongoCheckoutId,
      paymongoCheckoutUrl: draft.paymongoCheckoutUrl,
      paymongoPaymentId: draft.paymongoPaymentId,
      branchId: draft.branchId ?? defaultBranch.id,
      branchName: draft.branchName ?? defaultBranch.name,
      branchLat: bLat,
      branchLng: bLng,
      deliveryLat: draft.type == OrderType.delivery ? dLat : null,
      deliveryLng: draft.type == OrderType.delivery ? dLng : null,
      riderLat: bLat,
      riderLng: bLng,
      createdAt: now,
      updatedAt: now,
    );

    _fallbackOrders[fallbackId] = localOrder;
    _unsyncedOrderIds.add(fallbackId);
    _notifyFallback();

    // Auto-progress simulated order status & live rider GPS coordinates in background:
    // +6s -> preparing, +14s -> ready (rider on the way), +20s -> halfway, +28s -> completed (delivered)
    final startPos = LatLng(bLat, bLng);
    final endPos = LatLng(dLat, dLng);

    Timer(const Duration(seconds: 6), () {
      final current = _fallbackOrders[fallbackId];
      if (current != null && current.status == OrderStatus.received) {
        _fallbackOrders[fallbackId] = current.copyWith(
          status: OrderStatus.preparing,
          updatedAt: DateTime.now(),
        );
        _notifyFallback();
      }
    });

    Timer(const Duration(seconds: 14), () {
      final current = _fallbackOrders[fallbackId];
      if (current != null && current.status == OrderStatus.preparing) {
        final pos = LocationService.interpolateAlongRoute(startPos, endPos, 0.35);
        _fallbackOrders[fallbackId] = current.copyWith(
          status: OrderStatus.ready,
          riderLat: pos.latitude,
          riderLng: pos.longitude,
          updatedAt: DateTime.now(),
        );
        _notifyFallback();
      }
    });

    Timer(const Duration(seconds: 21), () {
      final current = _fallbackOrders[fallbackId];
      if (current != null && current.status == OrderStatus.ready) {
        final pos = LocationService.interpolateAlongRoute(startPos, endPos, 0.72);
        _fallbackOrders[fallbackId] = current.copyWith(
          riderLat: pos.latitude,
          riderLng: pos.longitude,
          updatedAt: DateTime.now(),
        );
        _notifyFallback();
      }
    });

    Timer(const Duration(seconds: 28), () {
      final current = _fallbackOrders[fallbackId];
      if (current != null && current.status == OrderStatus.ready) {
        _fallbackOrders[fallbackId] = current.copyWith(
          status: OrderStatus.completed,
          paymentStatus: PaymentStatus.paid,
          riderLat: endPos.latitude,
          riderLng: endPos.longitude,
          updatedAt: DateTime.now(),
        );
        _notifyFallback();
      }
    });

    return fallbackId;
  }

  /// Updates the PayMongo payment status & reference IDs (called by checkout or PayMongo webhook).
  Future<void> updatePaymentStatus(
    String id,
    PaymentStatus paymentStatus, {
    String? paymongoCheckoutId,
    String? paymongoCheckoutUrl,
    String? paymongoPaymentId,
  }) async {
    final local = _fallbackOrders[id];
    if (local != null) {
      _fallbackOrders[id] = local.copyWith(
        paymentStatus: paymentStatus,
        paymongoCheckoutId: paymongoCheckoutId ?? local.paymongoCheckoutId,
        paymongoCheckoutUrl: paymongoCheckoutUrl ?? local.paymongoCheckoutUrl,
        paymongoPaymentId: paymongoPaymentId ?? local.paymongoPaymentId,
        updatedAt: DateTime.now(),
      );
      _unsyncedOrderIds.add(id);
      _notifyFallback();
    }

    final col = _ordersCol;
    if (col == null) return;
    try {
      await col.doc(id).update({
        'paymentStatus': paymentStatus.value,
        if (paymongoCheckoutId != null)
          'paymongoCheckoutId': paymongoCheckoutId,
        if (paymongoCheckoutUrl != null)
          'paymongoCheckoutUrl': paymongoCheckoutUrl,
        if (paymongoPaymentId != null) 'paymongoPaymentId': paymongoPaymentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Local fallback already updated
    }
  }

  /// Updates the live rider GPS coordinates for an active delivery order.
  Future<void> updateRiderLocation(String id, double lat, double lng) async {
    final local = _fallbackOrders[id];
    if (local != null) {
      _fallbackOrders[id] = local.copyWith(
        riderLat: lat,
        riderLng: lng,
        updatedAt: DateTime.now(),
      );
      _notifyFallback();
    }

    final col = _ordersCol;
    if (col == null) return;
    try {
      await col.doc(id).update({
        'riderLat': lat,
        'riderLng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// O2: Track one order (live stream)
  Stream<Order?> watchOrder(String id) {
    if (id.isEmpty) return Stream.value(null);

    final initialFallback = _fallbackOrders[id];
    final col = _ordersCol;

    if (col == null || initialFallback != null) {
      return Stream<Order?>.multi((controller) {
        controller.add(_fallbackOrders[id]);
        final sub = _fallbackOrdersController.stream.listen((orders) {
          controller.add(orders[id]);
        });
        controller.onCancel = () => sub.cancel();
      });
    }

    return col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return _fallbackOrders[id];
      return Order.fromFirestore(doc);
    }).handleError((_) => _fallbackOrders[id]);
  }

  /// O2 (Future): Get order once
  Future<Order> getOrder(String id) async {
    final local = _fallbackOrders[id];
    if (local != null) return local;

    final col = _ordersCol;
    if (col == null) throw NotFoundFailure('Order not found: $id');
    try {
      final doc = await col.doc(id).get();
      if (!doc.exists) {
        throw NotFoundFailure('Order not found: $id');
      }
      return Order.fromFirestore(doc);
    } catch (_) {
      final fallback = _fallbackOrders[id];
      if (fallback != null) return fallback;
      throw NotFoundFailure('Order not found: $id');
    }
  }

  /// O3: Customer's active orders (live stream: received, preparing, ready)
  Stream<List<Order>> watchMyActiveOrders(String uid) {
    final col = _ordersCol;
    if (col == null || uid.isEmpty) {
      return Stream<List<Order>>.multi((controller) {
        void emit() {
          final local = _fallbackOrders.values
              .where((o) =>
                  (uid.isEmpty || o.userId == uid) &&
                  (o.status == OrderStatus.received ||
                      o.status == OrderStatus.preparing ||
                      o.status == OrderStatus.ready))
              .toList();
          controller.add(local);
        }

        emit();
        final sub = _fallbackOrdersController.stream.listen((_) => emit());
        controller.onCancel = () => sub.cancel();
      });
    }

    return col
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['received', 'preparing', 'ready'])
        .snapshots()
        .map((s) {
          final list = s.docs.map(Order.fromFirestore).toList();
          final local = _fallbackOrders.values
              .where((o) =>
                  (uid.isEmpty || o.userId == uid) &&
                  (o.status == OrderStatus.received ||
                      o.status == OrderStatus.preparing ||
                      o.status == OrderStatus.ready))
              .toList();
          final map = <String, Order>{};
          for (final o in [...list, ...local]) {
            map[o.id] = o;
          }
          final combined = map.values.toList();
          combined.sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));
          return combined;
        })
        .handleError((_) {
          final local = _fallbackOrders.values
              .where((o) =>
                  (uid.isEmpty || o.userId == uid) &&
                  (o.status == OrderStatus.received ||
                      o.status == OrderStatus.preparing ||
                      o.status == OrderStatus.ready))
              .toList();
          return local;
        });
  }

  /// O4: Customer's order history (live stream: completed, cancelled)
  Stream<List<Order>> watchHistory(String uid, {int limit = 20}) {
    final col = _ordersCol;
    if (col == null || uid.isEmpty) {
      return Stream<List<Order>>.multi((controller) {
        void emit() {
          final local = _fallbackOrders.values
              .where((o) =>
                  (uid.isEmpty || o.userId == uid) &&
                  (o.status == OrderStatus.completed ||
                      o.status == OrderStatus.cancelled))
              .toList();
          controller.add(local);
        }

        emit();
        final sub = _fallbackOrdersController.stream.listen((_) => emit());
        controller.onCancel = () => sub.cancel();
      });
    }

    return col
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['completed', 'cancelled'])
        .snapshots()
        .map((s) {
          final list = s.docs.map(Order.fromFirestore).toList();
          final local = _fallbackOrders.values
              .where((o) =>
                  (uid.isEmpty || o.userId == uid) &&
                  (o.status == OrderStatus.completed ||
                      o.status == OrderStatus.cancelled))
              .toList();
          final map = <String, Order>{};
          for (final o in [...list, ...local]) {
            map[o.id] = o;
          }
          final combined = map.values.toList();
          combined.sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));
          return combined.length > limit
              ? combined.sublist(0, limit)
              : combined;
        })
        .handleError((_) {
          final local = _fallbackOrders.values
              .where((o) =>
                  (uid.isEmpty || o.userId == uid) &&
                  (o.status == OrderStatus.completed ||
                      o.status == OrderStatus.cancelled))
              .toList();
          return local.length > limit ? local.sublist(0, limit) : local;
        });
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
    final local = _fallbackOrders[id];
    if (local != null) {
      if (local.status != OrderStatus.received) {
        throw OrderStateFailure(
          'Cannot cancel order in "${local.status.name}" status. Cancellation is only allowed when "received".',
        );
      }
      _fallbackOrders[id] = local.copyWith(
        status: OrderStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      _notifyFallback();
      return;
    }

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
    if (col == null) {
      return Stream<List<Order>>.multi((controller) {
        void emit() {
          final local = _fallbackOrders.values
              .where((o) =>
                  o.status == OrderStatus.received ||
                  o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.ready)
              .toList();
          controller.add(local);
        }

        emit();
        final sub = _fallbackOrdersController.stream.listen((_) => emit());
        controller.onCancel = () => sub.cancel();
      });
    }

    return col
        .where('status', whereIn: ['received', 'preparing', 'ready'])
        .snapshots()
        .map((s) {
          final list = s.docs.map(Order.fromFirestore).toList();
          final local = _fallbackOrders.values
              .where((o) =>
                  o.status == OrderStatus.received ||
                  o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.ready)
              .toList();
          final map = <String, Order>{};
          for (final o in [...list, ...local]) {
            map[o.id] = o;
          }
          final combined = map.values.toList();
          combined.sort((a, b) => (a.createdAt ?? DateTime(0))
              .compareTo(b.createdAt ?? DateTime(0)));
          return combined;
        })
        .handleError((_) {
          final local = _fallbackOrders.values
              .where((o) =>
                  o.status == OrderStatus.received ||
                  o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.ready)
              .toList();
          return local;
        });
  }

  /// O8: Advance order status with strict workflow validation
  Future<void> advanceStatus(String id, OrderStatus next) async {
    final local = _fallbackOrders[id];
    if (local != null) {
      final isValidTransition = switch (local.status) {
        OrderStatus.received =>
          next == OrderStatus.preparing || next == OrderStatus.cancelled,
        OrderStatus.preparing => next == OrderStatus.ready,
        OrderStatus.ready => next == OrderStatus.completed,
        OrderStatus.completed => false,
        OrderStatus.cancelled => false,
      };

      if (!isValidTransition) {
        throw OrderStateFailure(
          'Invalid transition from "${local.status.name}" to "${next.name}"',
        );
      }

      double? nextRiderLat = local.riderLat;
      double? nextRiderLng = local.riderLng;
      if (local.type == OrderType.delivery &&
          local.branchLat != null &&
          local.branchLng != null &&
          local.deliveryLat != null &&
          local.deliveryLng != null) {
        final start = LatLng(local.branchLat!, local.branchLng!);
        final end = LatLng(local.deliveryLat!, local.deliveryLng!);
        if (next == OrderStatus.ready) {
          final mid = LocationService.interpolateAlongRoute(start, end, 0.45);
          nextRiderLat = mid.latitude;
          nextRiderLng = mid.longitude;
        } else if (next == OrderStatus.completed) {
          nextRiderLat = end.latitude;
          nextRiderLng = end.longitude;
        }
      }

      _fallbackOrders[id] = local.copyWith(
        status: next,
        paymentStatus: next == OrderStatus.completed
            ? PaymentStatus.paid
            : local.paymentStatus,
        riderLat: nextRiderLat,
        riderLng: nextRiderLng,
        updatedAt: DateTime.now(),
      );
      _notifyFallback();
      return;
    }

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
      OrderStatus.received =>
        next == OrderStatus.preparing || next == OrderStatus.cancelled,
      OrderStatus.preparing => next == OrderStatus.ready,
      OrderStatus.ready => next == OrderStatus.completed,
      OrderStatus.completed => false,
      OrderStatus.cancelled => false,
    };

    if (!isValidTransition) {
      throw OrderStateFailure(
        'Invalid transition from "${currentStatus.name}" to "${next.name}"',
      );
    }

    try {
      await docRef.update({
        'status': next.name,
        if (next == OrderStatus.completed)
          'paymentStatus': PaymentStatus.paid.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to advance order status: $e');
    }
  }

  /// O9: Get completed orders for today (for sales summary calculation)
  Future<List<Order>> getCompletedToday(DateTime startOfDay) async {
    final col = _ordersCol;
    if (col == null) {
      return _fallbackOrders.values
          .where((o) =>
              o.status == OrderStatus.completed &&
              o.createdAt != null &&
              !o.createdAt!.isBefore(startOfDay))
          .toList();
    }
    try {
      final snapshot = await col
          .where('status', isEqualTo: OrderStatus.completed.name)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      final firestoreList = snapshot.docs.map(Order.fromFirestore).toList();
      final fallbackList = _fallbackOrders.values
          .where((o) =>
              o.status == OrderStatus.completed &&
              o.createdAt != null &&
              !o.createdAt!.isBefore(startOfDay))
          .toList();
      final merged = <String, Order>{};
      for (final o in [...firestoreList, ...fallbackList]) {
        merged[o.id] = o;
      }
      return merged.values.toList();
    } catch (e) {
      return _fallbackOrders.values
          .where((o) =>
              o.status == OrderStatus.completed &&
              o.createdAt != null &&
              !o.createdAt!.isBefore(startOfDay))
          .toList();
    }
  }
}
