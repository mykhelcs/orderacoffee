import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/order.dart';
import 'package:orderacoffee/data/repositories/order_repository.dart';
import 'package:orderacoffee/features/orders/orders_provider.dart';

class _FakeOrderRepository extends OrderRepository {
  final Map<String, Order> _store = {};
  final Map<String, StreamController<Order?>> _controllers = {};
  int _seq = 1000;

  @override
  Future<String> placeOrder(OrderDraft draft) async {
    draft.validate();
    final id = '#${++_seq}';
    final order = Order(
      id: id,
      userId: draft.userId,
      userName: draft.userName,
      items: draft.items,
      total: draft.total,
      type: draft.type,
      payment: draft.payment,
      status: OrderStatus.received,
    );
    _store[id] = order;
    _emit(id, order);
    return id;
  }

  @override
  Stream<Order?> watchOrder(String id) {
    _controllers.putIfAbsent(id, () => StreamController<Order?>.broadcast());
    Future.microtask(() => _emit(id, _store[id]));
    return _controllers[id]!.stream;
  }

  @override
  Future<void> advanceStatus(String id, OrderStatus next) async {
    final current = _store[id];
    if (current == null) throw NotFoundFailure('Order not found: $id');

    final isValid = switch (current.status) {
      OrderStatus.received => next == OrderStatus.preparing || next == OrderStatus.cancelled,
      OrderStatus.preparing => next == OrderStatus.ready,
      OrderStatus.ready => next == OrderStatus.completed,
      OrderStatus.completed => false,
      OrderStatus.cancelled => false,
    };

    if (!isValid) {
      throw OrderStateFailure(
        'Invalid status transition from "${current.status.name}" to "${next.name}"',
      );
    }

    final updated = current.copyWith(status: next);
    _store[id] = updated;
    _emit(id, updated);
  }

  @override
  Future<void> cancelOrder(String id) async {
    final current = _store[id];
    if (current == null) throw NotFoundFailure('Order not found: $id');
    final updated = current.copyWith(status: OrderStatus.cancelled);
    _store[id] = updated;
    _emit(id, updated);
  }

  void _emit(String id, Order? order) {
    if (_controllers.containsKey(id) && !_controllers[id]!.isClosed) {
      _controllers[id]!.add(order);
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}

void main() {
  group('OrdersProvider Tests', () {
    late ProviderContainer container;
    late _FakeOrderRepository fakeRepo;

    setUp(() {
      fakeRepo = _FakeOrderRepository();
      container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      fakeRepo.dispose();
      container.dispose();
    });

    test('initial state has no tracking order', () {
      final state = container.read(ordersProvider);
      expect(state.trackingOrderId, isNull);
      expect(state.isPlacingOrder, isFalse);
    });

    test('selectTrackingOrder updates trackingOrderId', () {
      final notifier = container.read(ordersProvider.notifier);
      notifier.selectTrackingOrder('#1041');
      expect(container.read(ordersProvider).trackingOrderId, '#1041');

      notifier.clearTrackingOrder();
      expect(container.read(ordersProvider).trackingOrderId, isNull);
    });

    test('placeOrder creates order and sets trackingOrderId', () async {
      final notifier = container.read(ordersProvider.notifier);

      const draft = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'americano',
            name: 'Americano',
            qty: 1,
            unitPrice: 110.0,
          ),
        ],
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
      );

      final orderId = await notifier.placeOrder(draft);
      expect(orderId, startsWith('#'));
      expect(container.read(ordersProvider).trackingOrderId, orderId);

      final order = await container.read(singleOrderStreamProvider(orderId).future);
      expect(order, isNotNull);
      expect(order!.id, orderId);
      expect(order.status, OrderStatus.received);
      expect(order.total, 110.0);
    });

    test('advanceStatus progresses order along happy path', () async {
      final notifier = container.read(ordersProvider.notifier);

      const draft = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'flat-white',
            name: 'Flat White',
            qty: 1,
            unitPrice: 140.0,
          ),
        ],
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
      );

      final orderId = await notifier.placeOrder(draft);

      // received -> preparing
      await notifier.advanceStatus(orderId, OrderStatus.preparing);
      final preparingOrder = await container.read(singleOrderStreamProvider(orderId).future);
      expect(preparingOrder?.status, OrderStatus.preparing);

      // preparing -> ready
      await notifier.advanceStatus(orderId, OrderStatus.ready);
      final readyOrder = await container.read(singleOrderStreamProvider(orderId).future);
      expect(readyOrder?.status, OrderStatus.ready);

      // ready -> completed
      await notifier.advanceStatus(orderId, OrderStatus.completed);
      final completedOrder = await container.read(singleOrderStreamProvider(orderId).future);
      expect(completedOrder?.status, OrderStatus.completed);
    });

    test('advanceStatus throws OrderStateFailure on illegal transition', () async {
      final notifier = container.read(ordersProvider.notifier);

      const draft = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'cold-brew',
            name: 'Cold Brew',
            qty: 1,
            unitPrice: 150.0,
          ),
        ],
        type: OrderType.pickup,
      );

      final orderId = await notifier.placeOrder(draft);

      expect(
        () => notifier.advanceStatus(orderId, OrderStatus.completed),
        throwsA(isA<OrderStateFailure>()),
      );
    });

    test('cancelOrder marks received order as cancelled', () async {
      final notifier = container.read(ordersProvider.notifier);

      const draft = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'croissant',
            name: 'Butter Croissant',
            qty: 1,
            unitPrice: 95.0,
          ),
        ],
        type: OrderType.pickup,
      );

      final orderId = await notifier.placeOrder(draft);
      await notifier.cancelOrder(orderId);

      final order = await container.read(singleOrderStreamProvider(orderId).future);
      expect(order!.status, OrderStatus.cancelled);
    });
  });
}
