import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/cart_line.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/data/models/order.dart';
import 'package:orderacoffee/data/models/sales_summary.dart';
import 'package:orderacoffee/data/models/user_profile.dart';

void main() {
  group('UserProfile & UserAddress Model', () {
    test('UserAddress serialization and equality', () {
      const address = UserAddress(
        id: 'addr_1',
        label: 'Home',
        line1: '123 Main St',
        city: 'Metropolis',
        notes: 'Gate code 1234',
      );

      final map = address.toMap();
      final fromMap = UserAddress.fromMap(map);
      expect(fromMap, equals(address));
      expect(fromMap.hashCode, equals(address.hashCode));

      final updated = address.copyWith(city: 'Gotham');
      expect(updated.city, 'Gotham');
      expect(updated.label, 'Home');
    });

    test('UserProfile serialization, role checks, and fallback parsing', () {
      final now = DateTime.now();
      final profile = UserProfile(
        uid: 'user_1',
        name: 'Jane Doe',
        email: 'jane@example.com',
        phone: '09123456789',
        role: 'customer',
        favorites: const ['item_1', 'item_2'],
        stamps: 4,
        addresses: const [
          UserAddress(id: 'a1', label: 'Office', line1: 'Corporate Tower', city: 'Metro'),
        ],
        createdAt: now,
      );

      expect(profile.isCustomer, isTrue);
      expect(profile.isAdmin, isFalse);

      final map = profile.toMap();
      final fromMap = UserProfile.fromMap(map, uid: 'user_1');
      expect(fromMap.uid, profile.uid);
      expect(fromMap.name, profile.name);
      expect(fromMap.stamps, 4);
      expect(fromMap.favorites, equals(['item_1', 'item_2']));
      expect(fromMap.addresses.length, 1);
    });
  });

  group('MenuItem & MenuOptions Model', () {
    test('MenuItem pricing and nested options serialization', () {
      const sizeL = SizeOption(label: 'Large', delta: 20.0);
      const milkOat = MilkOption(label: 'Oat', delta: 30.0);
      const extraShot = AddOnOption(label: 'Extra Shot', price: 25.0);

      const options = MenuOptions(
        sizes: [sizeL],
        milks: [milkOat],
        sugar: ['0%', '50%', '100%'],
        ice: ['Less', 'Regular'],
        addOns: [extraShot],
      );

      const item = MenuItem(
        id: 'm1',
        name: 'Iced Latte',
        category: 'Cold Coffee',
        description: 'Smooth espresso with milk',
        basePrice: 120.0,
        options: options,
      );

      final map = item.toMap();
      final fromMap = MenuItem.fromMap(map, id: 'm1');
      expect(fromMap.id, 'm1');
      expect(fromMap.name, 'Iced Latte');
      expect(fromMap.basePrice, 120.0);
      expect(fromMap.options.sizes.first.delta, 20.0);
      expect(fromMap.options.milks.first.delta, 30.0);
      expect(fromMap.options.addOns.first.price, 25.0);
    });
  });

  group('CartLine & CartCustomizations Model', () {
    test('Unit price calculation with sizes, milks, and addOns', () {
      const size = SizeOption(label: 'Large', delta: 25.0);
      const milk = MilkOption(label: 'Almond', delta: 35.0);
      const addOn1 = AddOnOption(label: 'Caramel Drizzle', price: 15.0);
      const addOn2 = AddOnOption(label: 'Vanilla Syrup', price: 20.0);

      const cust = CartCustomizations(
        size: size,
        milk: milk,
        sugar: '50%',
        ice: 'Regular',
        addOns: [addOn1, addOn2],
      );

      expect(cust.extraPrice, 25.0 + 35.0 + 15.0 + 20.0); // 95.0

      const line = CartLine(
        id: 'line_1',
        itemId: 'latte',
        name: 'Spanish Latte',
        basePrice: 130.0,
        customizations: cust,
        qty: 2,
      );

      expect(line.unitPrice, 130.0 + 95.0); // 225.0
      expect(line.lineTotal, 225.0 * 2); // 450.0

      final map = line.toMap();
      final restored = CartLine.fromMap(map);
      expect(restored.unitPrice, line.unitPrice);
      expect(restored.lineTotal, line.lineTotal);
    });
  });

  group('Order & OrderDraft Model', () {
    test('OrderDraft validation for empty items, dine-in without table, and delivery without address', () {
      // Empty items
      const emptyDraft = OrderDraft(
        userId: 'u1',
        userName: 'Alice',
        items: [],
        type: OrderType.pickup,
      );
      expect(() => emptyDraft.validate(), throwsA(isA<ValidationFailure>()));

      const item = OrderItem(
        itemId: 'c1',
        name: 'Brewed Coffee',
        qty: 1,
        unitPrice: 100.0,
      );

      // Dine-in missing tableNo
      const dineInMissingTable = OrderDraft(
        userId: 'u1',
        userName: 'Alice',
        items: [item],
        type: OrderType.dineIn,
        tableNo: null,
      );
      expect(() => dineInMissingTable.validate(), throwsA(isA<ValidationFailure>()));

      // Delivery missing address
      const deliveryMissingAddr = OrderDraft(
        userId: 'u1',
        userName: 'Alice',
        items: [item],
        type: OrderType.delivery,
        address: '',
      );
      expect(() => deliveryMissingAddr.validate(), throwsA(isA<ValidationFailure>()));

      // Valid draft
      const validDraft = OrderDraft(
        userId: 'u1',
        userName: 'Alice',
        items: [item],
        type: OrderType.dineIn,
        tableNo: '12',
      );
      expect(() => validDraft.validate(), returnsNormally);
      expect(validDraft.total, 100.0);
    });

    test('Order serialization and status enum parsing', () {
      const order = Order(
        id: 'ord_1',
        userId: 'u1',
        userName: 'Bob',
        items: [
          OrderItem(itemId: 'i1', name: 'Cold Brew', qty: 2, unitPrice: 110.0),
        ],
        total: 220.0,
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
        status: OrderStatus.received,
      );

      final map = order.toMap();
      final fromMap = Order.fromMap(map, id: 'ord_1');
      expect(fromMap.id, 'ord_1');
      expect(fromMap.status, OrderStatus.received);
      expect(fromMap.total, 220.0);
    });
  });

  group('SalesSummary Model', () {
    test('SalesSummary serialization', () {
      const summary = SalesSummary(
        date: '2026-10-28',
        orderCount: 15,
        revenue: 2540.0,
      );

      final map = summary.toMap();
      final fromMap = SalesSummary.fromMap(map, date: '2026-10-28');
      expect(fromMap.orderCount, 15);
      expect(fromMap.revenue, 2540.0);
      expect(fromMap, equals(summary));
    });
  });
}
