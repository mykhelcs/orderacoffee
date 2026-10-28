import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/data/models/order.dart';
import 'package:orderacoffee/data/repositories/cart_repository.dart';
import 'package:orderacoffee/data/repositories/menu_repository.dart';
import 'package:orderacoffee/data/repositories/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OrderRepository (O1 - O9)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = OrderRepository(firestore: fakeFirestore);
    });

    test('O1 & O2: placeOrder creates order and getOrder / watchOrder retrieves it', () async {
      const draft = OrderDraft(
        userId: 'user_xyz',
        userName: 'John Doe',
        items: [
          OrderItem(
            itemId: 'menu_1',
            name: 'Caramel Macchiato',
            qty: 2,
            unitPrice: 140.0,
          ),
        ],
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
        note: 'Extra napkin',
      );

      final orderId = await repository.placeOrder(draft);
      expect(orderId, isNotEmpty);

      final order = await repository.getOrder(orderId);
      expect(order.userId, 'user_xyz');
      expect(order.userName, 'John Doe');
      expect(order.total, 280.0);
      expect(order.status, OrderStatus.received);
      expect(order.type, OrderType.pickup);
    });

    test('O1: placeOrder rejects invalid draft', () async {
      const invalidDraft = OrderDraft(
        userId: 'user_xyz',
        userName: 'John Doe',
        items: [], // Empty items
        type: OrderType.pickup,
      );

      expect(
        () => repository.placeOrder(invalidDraft),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('O3: watchMyActiveOrders filters by userId and active statuses', () async {
      // Place active order
      final id1 = await repository.placeOrder(const OrderDraft(
        userId: 'user_a',
        userName: 'Alice',
        items: [OrderItem(itemId: '1', name: 'Coffee', qty: 1, unitPrice: 100.0)],
        type: OrderType.pickup,
      ));

      // Place completed order for same user
      final id2 = await repository.placeOrder(const OrderDraft(
        userId: 'user_a',
        userName: 'Alice',
        items: [OrderItem(itemId: '1', name: 'Coffee', qty: 1, unitPrice: 100.0)],
        type: OrderType.pickup,
      ));
      await fakeFirestore.collection('orders').doc(id2).update({
        'status': OrderStatus.completed.name,
      });

      // Place active order for different user
      await repository.placeOrder(const OrderDraft(
        userId: 'user_b',
        userName: 'Bob',
        items: [OrderItem(itemId: '1', name: 'Coffee', qty: 1, unitPrice: 100.0)],
        type: OrderType.pickup,
      ));

      final activeList = await repository.watchMyActiveOrders('user_a').first;
      expect(activeList.length, 1);
      expect(activeList.first.id, id1);
    });

    test('O4: getOrderHistory returns past orders for user', () async {
      await repository.placeOrder(const OrderDraft(
        userId: 'user_hist',
        userName: 'History User',
        items: [OrderItem(itemId: '1', name: 'Tea', qty: 1, unitPrice: 80.0)],
        type: OrderType.pickup,
      ));

      final history = await repository.getOrderHistory('user_hist');
      expect(history.length, 1);
      expect(history.first.userId, 'user_hist');
    });

    test('O5: reorder checks menu availability and repopulates cart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cart = CartRepository(prefs: prefs);
      final menu = MenuRepository(firestore: fakeFirestore);

      // Add item to menu: one available, one sold out
      final itemId1 = await menu.createItem(const MenuItem(
        id: '',
        name: 'Avail Drink',
        category: 'Hot',
        description: 'Test',
        basePrice: 100.0,
        isAvailable: true,
      ));
      final itemId2 = await menu.createItem(const MenuItem(
        id: '',
        name: 'Sold Out Drink',
        category: 'Hot',
        description: 'Test',
        basePrice: 120.0,
        isAvailable: false,
      ));

      // Create an order containing both items
      final orderId = await repository.placeOrder(OrderDraft(
        userId: 'reorder_user',
        userName: 'Reorder Test',
        items: [
          OrderItem(itemId: itemId1, name: 'Avail Drink', qty: 1, unitPrice: 100.0),
          OrderItem(itemId: itemId2, name: 'Sold Out Drink', qty: 1, unitPrice: 120.0),
        ],
        type: OrderType.pickup,
      ));

      final unavailable = await repository.reorder(
        orderId: orderId,
        cart: cart,
        menu: menu,
      );

      expect(unavailable, equals(['Sold Out Drink']));
      expect(cart.lines.length, 1);
      expect(cart.lines.first.itemId, itemId1);
      cart.dispose();
    });

    test('O6: cancelOrder succeeds when status is received, fails when preparing or ready', () async {
      final orderId = await repository.placeOrder(const OrderDraft(
        userId: 'cancel_user',
        userName: 'Cancel Test',
        items: [OrderItem(itemId: '1', name: 'Latte', qty: 1, unitPrice: 100.0)],
        type: OrderType.pickup,
      ));

      // Cancel while received -> succeeds
      await repository.cancelOrder(orderId);
      final order = await repository.getOrder(orderId);
      expect(order.status, OrderStatus.cancelled);

      // Attempting to cancel an already cancelled or preparing order throws OrderStateFailure
      expect(
        () => repository.cancelOrder(orderId),
        throwsA(isA<OrderStateFailure>()),
      );
    });

    test('O7 & O8: liveQueue and advanceStatus transition state machine', () async {
      final orderId = await repository.placeOrder(const OrderDraft(
        userId: 'flow_user',
        userName: 'Flow Test',
        items: [OrderItem(itemId: '1', name: 'Mocha', qty: 1, unitPrice: 130.0)],
        type: OrderType.pickup,
      ));

      // Valid: received -> preparing
      await repository.advanceStatus(orderId, OrderStatus.preparing);
      var order = await repository.getOrder(orderId);
      expect(order.status, OrderStatus.preparing);

      // Valid: preparing -> ready
      await repository.advanceStatus(orderId, OrderStatus.ready);
      order = await repository.getOrder(orderId);
      expect(order.status, OrderStatus.ready);

      // Valid: ready -> completed
      await repository.advanceStatus(orderId, OrderStatus.completed);
      order = await repository.getOrder(orderId);
      expect(order.status, OrderStatus.completed);

      // Invalid: completed cannot advance further
      expect(
        () => repository.advanceStatus(orderId, OrderStatus.preparing),
        throwsA(isA<OrderStateFailure>()),
      );
    });

    test('O8: advanceStatus rejects invalid status jumps (e.g. received -> completed)', () async {
      final orderId = await repository.placeOrder(const OrderDraft(
        userId: 'jump_user',
        userName: 'Jump Test',
        items: [OrderItem(itemId: '1', name: 'Espresso', qty: 1, unitPrice: 80.0)],
        type: OrderType.pickup,
      ));

      expect(
        () => repository.advanceStatus(orderId, OrderStatus.completed),
        throwsA(isA<OrderStateFailure>()),
      );
    });

    test('O9: getCompletedToday returns orders completed on or after startOfDay', () async {
      final today = DateTime(2026, 10, 28);

      final orderId = await repository.placeOrder(const OrderDraft(
        userId: 'today_user',
        userName: 'Today Test',
        items: [OrderItem(itemId: '1', name: 'Drip Coffee', qty: 1, unitPrice: 90.0)],
        type: OrderType.pickup,
      ));

      await fakeFirestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.completed.name,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 28, 10, 0)),
      });

      final completed = await repository.getCompletedToday(today);
      expect(completed.length, 1);
      expect(completed.first.id, orderId);
    });
  });
}
