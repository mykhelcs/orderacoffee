import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/errors/failures.dart';
import '../models/menu_item.dart';

class MenuRepository {
  MenuRepository({
    FirebaseFirestore? firestore,
    this._storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _menuCol =>
      _firestore.collection('menu');

  /// M1: List visible menu items (live stream, ordered by category)
  Stream<List<MenuItem>> watchMenu() {
    return _menuCol
        .where('isHidden', isEqualTo: false)
        .orderBy('category')
        .snapshots()
        .map((s) => s.docs.map(MenuItem.fromFirestore).toList());
  }

  /// M2: List visible items by category (live stream)
  Stream<List<MenuItem>> watchByCategory(String category) {
    return _menuCol
        .where('isHidden', isEqualTo: false)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((s) => s.docs.map(MenuItem.fromFirestore).toList());
  }

  /// M3: Get single menu item by ID
  Future<MenuItem> getItem(String itemId) async {
    final doc = await _menuCol.doc(itemId).get();
    if (!doc.exists) {
      throw NotFoundFailure('Menu item not found: $itemId');
    }
    return MenuItem.fromFirestore(doc);
  }

  /// M4: Search menu items by query string (case-insensitive on name & category)
  Future<List<MenuItem>> searchMenu(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final snapshot = await _menuCol.where('isHidden', isEqualTo: false).get();
    return snapshot.docs
        .map(MenuItem.fromFirestore)
        .where((item) =>
            item.name.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q))
        .toList();
  }

  /// M5: Create item (Admin)
  Future<String> createItem(MenuItem item) async {
    try {
      final docRef = await _menuCol.add({
        ...item.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw ValidationFailure('Failed to create menu item: $e');
    }
  }

  /// M6: Update item patch (Admin)
  Future<void> updateItem(String id, Map<String, dynamic> patch) async {
    try {
      await _menuCol.doc(id).update({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to update menu item: $e');
    }
  }

  /// M7: Toggle sold out (isAvailable) (Admin)
  Future<void> toggleSoldOut(String id, bool isAvailable) async {
    try {
      await _menuCol.doc(id).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to toggle sold out: $e');
    }
  }

  /// M8: Hide / unhide item (Admin)
  Future<void> toggleHidden(String id, bool isHidden) async {
    try {
      await _menuCol.doc(id).update({
        'isHidden': isHidden,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to toggle hidden: $e');
    }
  }

  /// M9: Delete item (Admin)
  Future<void> deleteItem(String id) async {
    try {
      await _menuCol.doc(id).delete();
    } catch (e) {
      throw ValidationFailure('Failed to delete menu item: $e');
    }
  }

  /// M10: Upload photo to Firebase Storage and update imageUrl in Firestore (Admin)
  Future<String> uploadPhoto(String id, Uint8List photoBytes, {String mimeType = 'image/jpeg'}) async {
    try {
      final ref = storage.ref('menu/$id.jpg');
      final metadata = SettableMetadata(contentType: mimeType);
      await ref.putData(photoBytes, metadata);
      final downloadUrl = await ref.getDownloadURL();
      await updateItem(id, {'imageUrl': downloadUrl});
      return downloadUrl;
    } catch (e) {
      throw ValidationFailure('Failed to upload photo: $e');
    }
  }

  /// M11: Delete photo from Storage and clear imageUrl (Admin)
  Future<void> deletePhoto(String id) async {
    try {
      final ref = storage.ref('menu/$id.jpg');
      await ref.delete();
      await updateItem(id, {'imageUrl': null});
    } catch (e) {
      throw ValidationFailure('Failed to delete photo: $e');
    }
  }
}
