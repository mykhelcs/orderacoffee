import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/features/menu/menu_provider.dart';

void main() {
  group('MenuProvider Tests', () {
    late ProviderContainer container;

    const sampleItems = [
      MenuItem(
        id: 'cold-brew',
        name: 'Cold Brew',
        category: 'Iced Coffee',
        description: 'Slow-steeped concentrate',
        basePrice: 150.0,
        isAvailable: true,
      ),
      MenuItem(
        id: 'matcha',
        name: 'Iced Matcha',
        category: 'Iced Coffee',
        description: 'Ceremonial-grade matcha',
        basePrice: 155.0,
        isAvailable: false,
      ),
      MenuItem(
        id: 'spanish-latte',
        name: 'Spanish Latte',
        category: 'Hot Coffee',
        description: 'Espresso with sweetened milk',
        basePrice: 145.0,
        isAvailable: true,
      ),
    ];

    setUp(() {
      container = ProviderContainer(
        overrides: [
          menuStreamProvider.overrideWith((ref) => Stream.value(sampleItems)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial filter state is All with empty query', () {
      final filter = container.read(menuFilterProvider);
      expect(filter.category, 'All');
      expect(filter.query, '');
    });

    test('filter by category updates filtered items', () async {
      await container.read(menuStreamProvider.future);

      container.read(menuFilterProvider.notifier).setCategory('Iced Coffee');
      final items = container.read(filteredMenuProvider);

      expect(items.length, 2);
      for (final item in items) {
        expect(item.category, 'Iced Coffee');
      }
      expect(items.map((i) => i.id), containsAll(['cold-brew', 'matcha']));
    });

    test('filter by query performs case-insensitive search', () async {
      await container.read(menuStreamProvider.future);

      container.read(menuFilterProvider.notifier).setQuery('latte');
      final items = container.read(filteredMenuProvider);

      expect(items.length, 1);
      expect(items.first.name, 'Spanish Latte');
    });

    test('sold out items (matcha) are included with isAvailable == false', () async {
      await container.read(menuStreamProvider.future);

      container.read(menuFilterProvider.notifier).setCategory('Iced Coffee');
      final items = container.read(filteredMenuProvider);

      final matcha = items.firstWhere((i) => i.id == 'matcha');
      expect(matcha.isAvailable, isFalse);
    });

    test('reset filter restores default category All and empty query', () {
      final notifier = container.read(menuFilterProvider.notifier);
      notifier.setCategory('Pastry');
      notifier.setQuery('croissant');

      notifier.reset();
      final filter = container.read(menuFilterProvider);
      expect(filter.category, 'All');
      expect(filter.query, '');
    });
  });
}
