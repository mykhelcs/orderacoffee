import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/data/repositories/favorites_repository.dart';
import 'package:orderacoffee/data/repositories/menu_repository.dart';

void main() {
  group('FavoritesRepository (F1 - F3)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FavoritesRepository favoritesRepo;
    late MenuRepository menuRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      favoritesRepo = FavoritesRepository(firestore: fakeFirestore);
      menuRepo = MenuRepository(firestore: fakeFirestore);
    });

    test('F1, F2 & F3: addFavorite, removeFavorite and listFavorites', () async {
      // Create user doc
      await fakeFirestore.collection('users').doc('user_fav').set({
        'name': 'Favorite Lover',
        'favorites': <String>[],
      });

      // Create menu items
      final item1Id = await menuRepo.createItem(const MenuItem(
        id: '',
        name: 'Favorite Latte',
        category: 'Hot Coffee',
        description: 'Best seller',
        basePrice: 120.0,
      ));
      final item2Id = await menuRepo.createItem(const MenuItem(
        id: '',
        name: 'Favorite Cold Brew',
        category: 'Cold Coffee',
        description: 'Smooth steep',
        basePrice: 130.0,
      ));

      // Add favorites
      await favoritesRepo.addFavorite('user_fav', item1Id);
      await favoritesRepo.addFavorite('user_fav', item2Id);

      var favorites = await favoritesRepo.listFavorites('user_fav');
      expect(favorites.length, 2);
      expect(favorites.map((f) => f.id).toSet(), equals({item1Id, item2Id}));

      // Remove one favorite
      await favoritesRepo.removeFavorite('user_fav', item1Id);

      favorites = await favoritesRepo.listFavorites('user_fav');
      expect(favorites.length, 1);
      expect(favorites.first.id, item2Id);
    });

    test('F3: listFavorites returns empty list when user has no favorites', () async {
      await fakeFirestore.collection('users').doc('empty_fav_user').set({
        'name': 'Empty User',
        'favorites': <String>[],
      });

      final favorites = await favoritesRepo.listFavorites('empty_fav_user');
      expect(favorites, isEmpty);
    });
  });
}
