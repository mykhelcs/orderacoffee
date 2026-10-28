import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/data/models/cart_line.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/features/cart/cart_provider.dart';

void main() {
  group('CartNotifier Tests', () {
    late ProviderContainer container;

    const testItemLatte = MenuItem(
      id: 'spanish-latte',
      name: 'Spanish Latte',
      category: 'Iced Coffee',
      description: 'Espresso with sweet milk',
      basePrice: 145.0,
      isAvailable: true,
    );

    const testItemCroissant = MenuItem(
      id: 'croissant',
      name: 'Butter Croissant',
      category: 'Pastry',
      description: 'Baked fresh',
      basePrice: 95.0,
      isAvailable: true,
    );

    const testItemAmericano = MenuItem(
      id: 'americano',
      name: 'Americano',
      category: 'Hot Coffee',
      description: 'Hot water & espresso',
      basePrice: 110.0,
      isAvailable: true,
    );

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial cart state is empty', () {
      final state = container.read(cartProvider);
      expect(state.lines, isEmpty);
      expect(state.total, 0.0);
      expect(state.itemCount, 0);
    });

    test('addLine adds an item with base price and extra options', () {
      final notifier = container.read(cartProvider.notifier);

      const cust = CartCustomizations(
        size: SizeOption(label: 'Large', delta: 25),
        milk: MilkOption(label: 'Oat', delta: 30),
        addOns: [AddOnOption(label: 'Extra shot', price: 40)],
        sugar: '50%',
        ice: 'Regular',
      );

      notifier.addLine(testItemLatte, cust, 2, note: 'Warm milk');

      final state = container.read(cartProvider);
      expect(state.lines.length, 1);
      final line = state.lines.first;
      expect(line.name, 'Spanish Latte');
      expect(line.qty, 2);
      expect(line.note, 'Warm milk');
      // Unit price: 145 + 25 + 30 + 40 = 240
      expect(line.unitPrice, 240.0);
      // Line total: 240 * 2 = 480
      expect(line.lineTotal, 480.0);
      expect(state.total, 480.0);
      expect(state.itemCount, 2);
    });

    test('updateQty modifies quantity and updates cart total', () {
      final notifier = container.read(cartProvider.notifier);

      notifier.addLine(testItemCroissant, const CartCustomizations(), 1);
      var state = container.read(cartProvider);
      final lineId = state.lines.first.id;
      expect(state.total, 95.0);

      notifier.updateQty(lineId, 3);
      state = container.read(cartProvider);
      expect(state.lines.first.qty, 3);
      expect(state.total, 285.0);
      expect(state.itemCount, 3);
    });

    test('updateQty to 0 removes line from cart', () {
      final notifier = container.read(cartProvider.notifier);

      notifier.addLine(testItemAmericano, const CartCustomizations(), 1);
      var state = container.read(cartProvider);
      final lineId = state.lines.first.id;
      expect(state.lines.length, 1);

      notifier.updateQty(lineId, 0);
      state = container.read(cartProvider);
      expect(state.lines, isEmpty);
      expect(state.total, 0.0);
    });

    test('removeLine removes specified item', () {
      final notifier = container.read(cartProvider.notifier);

      notifier.addLine(testItemLatte, const CartCustomizations(), 1);
      notifier.addLine(testItemAmericano, const CartCustomizations(), 1);
      var state = container.read(cartProvider);
      expect(state.lines.length, 2);

      final lineIdToRemove = state.lines.first.id;
      notifier.removeLine(lineIdToRemove);

      state = container.read(cartProvider);
      expect(state.lines.length, 1);
      expect(state.lines.first.id, isNot(lineIdToRemove));
    });

    test('clear empties all items from cart', () {
      final notifier = container.read(cartProvider.notifier);
      notifier.addLine(testItemLatte, const CartCustomizations(), 1);
      notifier.addLine(testItemCroissant, const CartCustomizations(), 2);
      expect(container.read(cartProvider).lines.length, 2);

      notifier.clear();
      expect(container.read(cartProvider).lines, isEmpty);
      expect(container.read(cartProvider).total, 0.0);
    });
  });
}
