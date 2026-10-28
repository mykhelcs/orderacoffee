import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../models/menu_item.dart';

class FavoritesRepository {
  FavoritesRepository({this._firestore});

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _menuCol =>
      firestore.collection('menu');

  /// F1: Add item to user favorites
  Future<void> addFavorite(String uid, String itemId) async {
    try {
      await _usersCol.doc(uid).update({
        'favorites': FieldValue.arrayUnion([itemId]),
      });
    } catch (e) {
      throw ValidationFailure('Failed to add favorite: $e');
    }
  }

  /// F2: Remove item from user favorites
  Future<void> removeFavorite(String uid, String itemId) async {
    try {
      await _usersCol.doc(uid).update({
        'favorites': FieldValue.arrayRemove([itemId]),
      });
    } catch (e) {
      throw ValidationFailure('Failed to remove favorite: $e');
    }
  }

  /// F3: List user's favorite menu items (chunked in batches of 30 for Firestore whereIn limit)
  Future<List<MenuItem>> listFavorites(String uid) async {
    try {
      final userDoc = await _usersCol.doc(uid).get();
      if (!userDoc.exists) {
        throw const NotFoundFailure('User not found');
      }

      final rawFavorites = userDoc.data()?['favorites'] as List<dynamic>? ?? [];
      final itemIds = rawFavorites.map((e) => e.toString()).toSet().toList();

      if (itemIds.isEmpty) return const [];

      final results = <MenuItem>[];

      // Firestore whereIn has a limit of 30 values
      const chunkSize = 30;
      for (var i = 0; i < itemIds.length; i += chunkSize) {
        final end = (i + chunkSize < itemIds.length) ? i + chunkSize : itemIds.length;
        final chunk = itemIds.sublist(i, end);

        final snapshot = await _menuCol
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        results.addAll(snapshot.docs.map(MenuItem.fromFirestore));
      }

      return results;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ValidationFailure('Failed to list favorites: $e');
    }
  }
}
