import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/data/repositories/menu_repository.dart';

void main() {
  group('MenuRepository (M1 - M9)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MenuRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = MenuRepository(firestore: fakeFirestore);
    });

    test('M5 & M3: createItem adds item and getItem retrieves it', () async {
      const item = MenuItem(
        id: '',
        name: 'Cappuccino',
        category: 'Hot Coffee',
        description: 'Rich espresso with steamed milk foam',
        basePrice: 110.0,
      );

      final id = await repository.createItem(item);
      expect(id, isNotEmpty);

      final fetched = await repository.getItem(id);
      expect(fetched.name, 'Cappuccino');
      expect(fetched.category, 'Hot Coffee');
      expect(fetched.basePrice, 110.0);
      expect(fetched.isAvailable, isTrue);
      expect(fetched.isHidden, isFalse);
    });

    test('M3: getItem throws NotFoundFailure if item does not exist', () async {
      expect(
        () => repository.getItem('non_existent_item_id'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('M1: watchMenu streams visible items and excludes hidden ones', () async {
      await repository.createItem(const MenuItem(
        id: '',
        name: 'Espresso',
        category: 'Hot Coffee',
        description: 'Single shot',
        basePrice: 80.0,
        isHidden: false,
      ));
      await repository.createItem(const MenuItem(
        id: '',
        name: 'Secret Roast',
        category: 'Special',
        description: 'Staff only',
        basePrice: 150.0,
        isHidden: true,
      ));

      final items = await repository.watchMenu().first;
      expect(items.length, 1);
      expect(items.first.name, 'Espresso');
    });

    test('M2: watchByCategory filters by specified category', () async {
      await repository.createItem(const MenuItem(
        id: '',
        name: 'Americano',
        category: 'Hot Coffee',
        description: 'Diluted espresso',
        basePrice: 90.0,
      ));
      await repository.createItem(const MenuItem(
        id: '',
        name: 'Iced Latte',
        category: 'Cold Coffee',
        description: 'Cold espresso and milk',
        basePrice: 120.0,
      ));

      final hotItems = await repository.watchByCategory('Hot Coffee').first;
      expect(hotItems.length, 1);
      expect(hotItems.first.name, 'Americano');
    });

    test('M4: searchMenu matches query in name, category, or description', () async {
      await repository.createItem(const MenuItem(
        id: '',
        name: 'Matcha Latte',
        category: 'Tea',
        description: 'Ceremonial grade matcha',
        basePrice: 140.0,
      ));
      await repository.createItem(const MenuItem(
        id: '',
        name: 'Mocha',
        category: 'Hot Coffee',
        description: 'With rich chocolate',
        basePrice: 130.0,
      ));

      final nameSearch = await repository.searchMenu('matcha');
      expect(nameSearch.length, 1);
      expect(nameSearch.first.name, 'Matcha Latte');

      final descSearch = await repository.searchMenu('chocolate');
      expect(descSearch.length, 1);
      expect(descSearch.first.name, 'Mocha');

      final emptySearch = await repository.searchMenu('   ');
      expect(emptySearch, isEmpty);
    });

    test('M6: updateItem updates item properties', () async {
      final id = await repository.createItem(const MenuItem(
        id: '',
        name: 'Original Item',
        category: 'Pastry',
        description: 'Fresh croissant',
        basePrice: 75.0,
      ));

      await repository.updateItem(id, {
        'basePrice': 85.0,
        'description': 'Warm butter croissant',
      });

      final updated = await repository.getItem(id);
      expect(updated.basePrice, 85.0);
      expect(updated.description, 'Warm butter croissant');
    });

    test('M7: toggleSoldOut switches isAvailable flag', () async {
      final id = await repository.createItem(const MenuItem(
        id: '',
        name: 'Limited Pastry',
        category: 'Pastry',
        description: 'Daily special',
        basePrice: 95.0,
      ));

      await repository.toggleSoldOut(id, false);
      var item = await repository.getItem(id);
      expect(item.isAvailable, isFalse);

      await repository.toggleSoldOut(id, true);
      item = await repository.getItem(id);
      expect(item.isAvailable, isTrue);
    });

    test('M8: toggleHidden updates isHidden flag', () async {
      final id = await repository.createItem(const MenuItem(
        id: '',
        name: 'Seasonal Drink',
        category: 'Cold Coffee',
        description: 'Pumpkin spice',
        basePrice: 140.0,
      ));

      await repository.toggleHidden(id, true);
      final item = await repository.getItem(id);
      expect(item.isHidden, isTrue);
    });

    test('M9: deleteItem removes item from collection', () async {
      final id = await repository.createItem(const MenuItem(
        id: '',
        name: 'To Be Deleted',
        category: 'Misc',
        description: 'Temporary',
        basePrice: 50.0,
      ));

      expect((await repository.getItem(id)).name, 'To Be Deleted');

      await repository.deleteItem(id);

      expect(
        () => repository.getItem(id),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
