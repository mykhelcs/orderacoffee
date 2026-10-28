import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/cart_line.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/data/models/order.dart';
import 'package:orderacoffee/data/models/user_profile.dart';

void main() {
  group('Production Data Models Tests', () {
    test('MenuItem serialization and copyWith works correctly', () {
      const item = MenuItem(
        id: 'test-latte',
        name: 'Spanish Latte',
        category: 'Iced Coffee',
        description: 'Espresso with sweet milk',
        basePrice: 145.0,
        isAvailable: true,
      );

      final map = item.toMap();
      expect(map['name'], 'Spanish Latte');
      expect(map['category'], 'Iced Coffee');
      expect(map['basePrice'], 145.0);
      expect(map['isAvailable'], isTrue);

      final fromMap = MenuItem.fromMap(map, id: 'test-latte');
      expect(fromMap.id, 'test-latte');
      expect(fromMap.name, item.name);
      expect(fromMap.basePrice, item.basePrice);

      final updated = item.copyWith(isAvailable: false);
      expect(updated.isAvailable, isFalse);
      expect(updated.name, item.name);
    });

    test('OrderDraft validation enforces business rules', () {
      const emptyDraft = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [],
        type: OrderType.pickup,
      );
      expect(() => emptyDraft.validate(), throwsA(isA<ValidationFailure>()));

      const dineInNoTable = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'i1',
            name: 'Coffee',
            qty: 1,
            unitPrice: 100.0,
          ),
        ],
        type: OrderType.dineIn,
        tableNo: '',
      );
      expect(() => dineInNoTable.validate(), throwsA(isA<ValidationFailure>()));

      const deliveryNoAddr = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'i1',
            name: 'Coffee',
            qty: 1,
            unitPrice: 100.0,
          ),
        ],
        type: OrderType.delivery,
        address: '',
      );
      expect(() => deliveryNoAddr.validate(), throwsA(isA<ValidationFailure>()));

      const validPickup = OrderDraft(
        userId: 'u1',
        userName: 'Customer',
        items: [
          OrderItem(
            itemId: 'i1',
            name: 'Coffee',
            qty: 2,
            unitPrice: 100.0,
          ),
        ],
        type: OrderType.pickup,
      );
      expect(() => validPickup.validate(), returnsNormally);
      expect(validPickup.total, 200.0);
    });

    test('Order model serialization and status enum parsing', () {
      expect(OrderStatus.fromString('received'), OrderStatus.received);
      expect(OrderStatus.fromString('preparing'), OrderStatus.preparing);
      expect(OrderStatus.fromString('ready'), OrderStatus.ready);
      expect(OrderStatus.fromString('completed'), OrderStatus.completed);
      expect(OrderStatus.fromString('cancelled'), OrderStatus.cancelled);

      const order = Order(
        id: '#1001',
        userId: 'u123',
        userName: 'Juan',
        items: [
          OrderItem(
            itemId: 'c1',
            name: 'Americano',
            qty: 1,
            unitPrice: 110.0,
          ),
        ],
        total: 110.0,
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
        status: OrderStatus.received,
      );

      final map = order.toMap();
      expect(map['userId'], 'u123');
      expect(map['total'], 110.0);
      expect(map['status'], 'received');

      final deserialized = Order.fromMap(map, id: '#1001');
      expect(deserialized.id, '#1001');
      expect(deserialized.status, OrderStatus.received);
      expect(deserialized.items.first.name, 'Americano');
    });

    test('UserProfile model serialization and role checks', () {
      const customer = UserProfile(
        uid: 'c1',
        name: 'Maria',
        email: 'maria@test.com',
        phone: '+63 912 345 6789',
        role: 'customer',
        stamps: 5,
        favorites: ['spanish-latte'],
      );

      expect(customer.isCustomer, isTrue);
      expect(customer.isAdmin, isFalse);

      final map = customer.toMap();
      final fromMap = UserProfile.fromMap(map, uid: 'c1');
      expect(fromMap.name, 'Maria');
      expect(fromMap.stamps, 5);
      expect(fromMap.favorites, contains('spanish-latte'));

      const admin = UserProfile(
        uid: 'a1',
        name: 'Staff',
        email: 'admin@test.com',
        phone: '+63 900 000 0000',
        role: 'admin',
      );
      expect(admin.isAdmin, isTrue);
    });

    test('CartLine extra price computation', () {
      const cust = CartCustomizations(
        size: SizeOption(label: 'Large', delta: 25.0),
        milk: MilkOption(label: 'Oat', delta: 30.0),
        addOns: [AddOnOption(label: 'Extra shot', price: 40.0)],
      );
      expect(cust.extraPrice, 95.0);

      const line = CartLine(
        id: 'line-1',
        itemId: 'item-1',
        name: 'Cold Brew',
        basePrice: 150.0,
        customizations: cust,
        qty: 2,
      );
      expect(line.unitPrice, 245.0);
      expect(line.lineTotal, 490.0);
    });
  });
}
