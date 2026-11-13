import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/repositories/order_repository.dart';
import 'package:orderacoffee/backend/services/paymongo_service.dart';

// ─── Production Repository & Service Providers ───────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

final paymongoServiceProvider = Provider<PayMongoService>((ref) {
  return PayMongoService();
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
    this.lastPaymongoSession,
    this.error,
  });

  final String? trackingOrderId;
  final bool isPlacingOrder;
  final PayMongoCheckoutSession? lastPaymongoSession;
  final String? error;

  OrdersState copyWith({
    String? trackingOrderId,
    bool? isPlacingOrder,
    PayMongoCheckoutSession? lastPaymongoSession,
    String? error,
    bool clearTrackingOrderId = false,
    bool clearPaymongoSession = false,
    bool clearError = false,
  }) {
    return OrdersState(
      trackingOrderId: clearTrackingOrderId
          ? null
          : (trackingOrderId ?? this.trackingOrderId),
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      lastPaymongoSession: clearPaymongoSession
          ? null
          : (lastPaymongoSession ?? this.lastPaymongoSession),
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
          lastPaymongoSession == other.lastPaymongoSession &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        trackingOrderId,
        isPlacingOrder,
        lastPaymongoSession,
        error,
      );
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._repo, [PayMongoService? paymongo])
      : _paymongo = paymongo ?? PayMongoService(),
        super(const OrdersState());

  final OrderRepository _repo;
  final PayMongoService _paymongo;

  void selectTrackingOrder(String orderId) {
    state = state.copyWith(trackingOrderId: orderId);
  }

  void clearTrackingOrder() {
    state = state.copyWith(clearTrackingOrderId: true);
  }

  Future<String> placeOrder(OrderDraft draft) async {
    state = state.copyWith(
      isPlacingOrder: true,
      clearError: true,
      clearPaymongoSession: true,
    );
    try {
      PayMongoCheckoutSession? session;
      OrderDraft effectiveDraft = draft;
      final allocatedOrderId = _repo.allocateOrderId();

      if (draft.payment.isPayMongo) {
        session = await _paymongo.createCheckoutSession(
          orderId: allocatedOrderId,
          draft: draft,
        );
        effectiveDraft = OrderDraft(
          userId: draft.userId,
          userName: draft.userName,
          userEmail: draft.userEmail,
          items: draft.items,
          type: draft.type,
          tableNo: draft.tableNo,
          address: draft.address,
          payment: draft.payment,
          paymentStatus: PaymentStatus.pending,
          paymongoCheckoutId: session.id,
          paymongoCheckoutUrl: session.checkoutUrl,
          note: draft.note,
          subtotal: draft.subtotal,
          deliveryFee: draft.deliveryFee,
          discount: draft.discount,
          rewardCode: draft.rewardCode,
          branchId: draft.branchId,
          branchName: draft.branchName,
          branchLat: draft.branchLat,
          branchLng: draft.branchLng,
          deliveryLat: draft.deliveryLat,
          deliveryLng: draft.deliveryLng,
        );
      }

      final id = await _repo.placeOrder(effectiveDraft, orderId: allocatedOrderId);

      if (session != null) {
        await _repo.updatePaymentStatus(
          id,
          PaymentStatus.pending,
          paymongoCheckoutId: session.id,
          paymongoCheckoutUrl: session.checkoutUrl,
        );
      }

      state = state.copyWith(
        isPlacingOrder: false,
        trackingOrderId: id,
        lastPaymongoSession: session,
      );
      return id;
    } catch (e) {
      state = state.copyWith(isPlacingOrder: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> completePayMongoPayment(
    String orderId, {
    String? paymentId,
  }) async {
    await _repo.updatePaymentStatus(
      orderId,
      PaymentStatus.paid,
      paymongoPaymentId:
          paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> advanceStatus(String orderId, OrderStatus next) async {
    await _repo.advanceStatus(orderId, next);
  }

  Future<void> cancelOrder(String orderId) async {
    await _repo.cancelOrder(orderId);
  }

  Future<void> updateRiderLocation(
    String orderId,
    double lat,
    double lng,
  ) async {
    await _repo.updateRiderLocation(orderId, lat, lng);
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(
    ref.watch(orderRepositoryProvider),
    ref.watch(paymongoServiceProvider),
  );
});
