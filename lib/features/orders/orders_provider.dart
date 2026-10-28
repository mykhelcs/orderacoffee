import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';

// ─── Production Repository Provider ───────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

// ─── Stream Providers ─────────────────────────────────────────────────────────

/// Stream of active orders for a customer (received, preparing, ready).
final activeOrdersStreamProvider =
    StreamProvider.family<List<Order>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchMyActiveOrders(uid);
});

/// Stream of completed / past orders for a customer.
final orderHistoryStreamProvider =
    StreamProvider.family<List<Order>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchHistory(uid);
});

/// Stream of a single order by ID for live order tracking.
final singleOrderStreamProvider =
    StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrder(orderId);
});

/// Stream of the active queue for baristas/staff.
final liveQueueStreamProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).liveQueue();
});

// ─── Orders State & Notifier ──────────────────────────────────────────────────

@immutable
class OrdersState {
  const OrdersState({
    this.trackingOrderId,
    this.isPlacingOrder = false,
    this.error,
  });

  final String? trackingOrderId;
  final bool isPlacingOrder;
  final String? error;

  OrdersState copyWith({
    String? trackingOrderId,
    bool? isPlacingOrder,
    String? error,
    bool clearTrackingOrderId = false,
    bool clearError = false,
  }) {
    return OrdersState(
      trackingOrderId: clearTrackingOrderId
          ? null
          : (trackingOrderId ?? this.trackingOrderId),
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrdersState &&
          runtimeType == other.runtimeType &&
          trackingOrderId == other.trackingOrderId &&
          isPlacingOrder == other.isPlacingOrder &&
          error == other.error;

  @override
  int get hashCode => Object.hash(trackingOrderId, isPlacingOrder, error);
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._repo) : super(const OrdersState());

  final OrderRepository _repo;

  void selectTrackingOrder(String orderId) {
    state = state.copyWith(trackingOrderId: orderId);
  }

  void clearTrackingOrder() {
    state = state.copyWith(clearTrackingOrderId: true);
  }

  Future<String> placeOrder(OrderDraft draft) async {
    state = state.copyWith(isPlacingOrder: true, clearError: true);
    try {
      final id = await _repo.placeOrder(draft);
      state = state.copyWith(
        isPlacingOrder: false,
        trackingOrderId: id,
      );
      return id;
    } catch (e) {
      state = state.copyWith(isPlacingOrder: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> advanceStatus(String orderId, OrderStatus next) async {
    await _repo.advanceStatus(orderId, next);
  }

  Future<void> cancelOrder(String orderId) async {
    await _repo.cancelOrder(orderId);
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref.watch(orderRepositoryProvider));
});
