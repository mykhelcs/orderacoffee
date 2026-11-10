import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/backend/seed/seed_menu_data.dart';
import '../models/menu_item.dart';

class MenuRepository {
  MenuRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  // In-memory & disk client cache for slow network / offline readiness
  static List<MenuItem> _memoryCache = [];
  static const String _kMenuCacheKey = 'cafego_cached_menu_items';

  /// Preloads cached menu from local disk storage into memory
  static Future<List<MenuItem>> loadFromDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kMenuCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr) as List;
        _memoryCache = decoded.map<MenuItem>((m) {
          final itemMap = Map<String, dynamic>.from(m as Map);
          final itemId = itemMap['id'] as String? ?? '';
          return MenuItem.fromMap(itemMap, id: itemId);
        }).toList();
      }
    } catch (_) {}
    return _memoryCache;
  }

  /// Persists menu items to local disk storage
  static Future<void> saveToDiskCache(List<MenuItem> items) async {
    try {
      _memoryCache = items;
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items.map((i) => i.toMap()).toList());
      await prefs.setString(_kMenuCacheKey, jsonStr);
    } catch (_) {}
  }

  FirebaseFirestore? get firestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseStorage? get storage {
    if (_storage != null) return _storage;
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _menuCol {
    final fs = firestore;
    if (fs == null) return null;
    return fs.collection('menu');
  }

  /// Seeds initial menu items if the menu collection is empty or missing default items.
  Future<void> seedIfEmpty() async {
    try {
      await syncMenuToFirestore(force: false);
    } catch (e) {
      debugPrint('[Firebase Menu Sync] Initial startup sync: $e');
    }
  }

  /// Explicitly uploads and syncs all 37 classy menu catalog items to Cloud Firestore.
  Future<int> syncMenuToFirestore({bool force = false}) async {
    final col = _menuCol;
    final fs = firestore;
    if (col == null || fs == null) {
      debugPrint('[Firebase Sync] Firestore is not initialized.');
      return 0;
    }

    try {
      if (!force) {
        final existing = await col.limit(1).get();
        if (existing.docs.isNotEmpty) {
          debugPrint('[Firebase Sync] Menu already exists in Firestore (${existing.docs.length}+ items).');
          return existing.docs.length;
        }
      }

      final batch = fs.batch();
      final altCol = fs.collection('menu_items');
      int count = 0;

      for (final item in kDefaultMenuItems) {
        final docRef = col.doc(item.id);
        final data = {
          ...item.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        batch.set(docRef, data, SetOptions(merge: true));
        batch.set(altCol.doc(item.id), data, SetOptions(merge: true));
        count++;
      }

      await batch.commit();
      debugPrint(
          '[Firebase Sync] Successfully synced $count menu products to Cloud Firestore (menu & menu_items)!');
      return count;
    } catch (e) {
      debugPrint('[Firebase Sync Error] Failed to sync menu to Firestore: $e');
      rethrow;
    }
  }

  /// M1: List visible menu items (live stream, ordered by category)
  Stream<List<MenuItem>> watchMenu() {
    final col = _menuCol;
    if (col == null) {
      return Stream.value(
        _memoryCache.isNotEmpty
            ? _memoryCache.where((item) => !item.isHidden).toList()
            : const [],
      );
    }
    try {
      return col.snapshots().map((s) {
        final items = s.docs
            .map(MenuItem.fromFirestore)
            .where((item) => !item.isHidden)
            .toList();
        items.sort((a, b) => a.category.compareTo(b.category));
        if (items.isNotEmpty) {
          saveToDiskCache(items);
        }
        return items;
      }).handleError((_) =>
          _memoryCache.where((item) => !item.isHidden).toList());
    } catch (_) {
      return Stream.value(
        _memoryCache.where((item) => !item.isHidden).toList(),
      );
    }
  }

  /// M1-Admin: List all menu items including hidden ones for Admin Catalog management
  Stream<List<MenuItem>> watchAllMenu() {
    final col = _menuCol;
    if (col == null) return Stream.value(const []);
    try {
      return col.snapshots().map((s) {
        final items = s.docs.map(MenuItem.fromFirestore).toList();
        items.sort((a, b) => a.category.compareTo(b.category));
        return items;
      }).handleError((_) => const <MenuItem>[]);
    } catch (_) {
      return Stream.value(const []);
    }
  }

  /// M2: List visible items by category (live stream)
  Stream<List<MenuItem>> watchByCategory(String category) {
    final col = _menuCol;
    if (col == null) return Stream.value(const []);
    try {
      return col.snapshots().map((s) => s.docs
          .map(MenuItem.fromFirestore)
          .where((item) => !item.isHidden && item.category == category)
          .toList()).handleError((_) => const <MenuItem>[]);
    } catch (_) {
      return Stream.value(const []);
    }
  }

  /// M3: Get single menu item by ID (with fallback to client memory/disk cache)
  Future<MenuItem> getItem(String itemId) async {
    final col = _menuCol;
    if (col == null) {
      final cached = _memoryCache.where((i) => i.id == itemId).firstOrNull;
      if (cached != null) return cached;
      throw NotFoundFailure('Menu item not found: $itemId');
    }
    try {
      final doc = await col.doc(itemId).get();
      if (!doc.exists) {
        final cached = _memoryCache.where((i) => i.id == itemId).firstOrNull;
        if (cached != null) return cached;
        throw NotFoundFailure('Menu item not found: $itemId');
      }
      return MenuItem.fromFirestore(doc);
    } catch (e) {
      final cached = _memoryCache.where((i) => i.id == itemId).firstOrNull;
      if (cached != null) return cached;
      if (e is NotFoundFailure) rethrow;
      throw NotFoundFailure('Menu item not found: $itemId');
    }
  }

  /// M4: Search menu items by query string (case-insensitive on name & category)
  Future<List<MenuItem>> searchMenu(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final col = _menuCol;
    if (col == null) return const [];

    final snapshot = await col.where('isHidden', isEqualTo: false).get();
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
    final col = _menuCol;
    if (col == null) throw const ValidationFailure('Firestore is not initialized');
    try {
      final docRef = await col.add({
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
    final col = _menuCol;
    if (col == null) return;
    try {
      await col.doc(id).update({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to update menu item: $e');
    }
  }

  /// M7: Toggle sold out (isAvailable) (Admin)
  Future<void> toggleSoldOut(String id, bool isAvailable) async {
    final col = _menuCol;
    if (col == null) return;
    try {
      await col.doc(id).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to toggle sold out: $e');
    }
  }

  /// M8: Hide / unhide item (Admin)
  Future<void> toggleHidden(String id, bool isHidden) async {
    final col = _menuCol;
    if (col == null) return;
    try {
      await col.doc(id).update({
        'isHidden': isHidden,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to toggle hidden: $e');
    }
  }

  /// M9: Delete item (Admin)
  Future<void> deleteItem(String id) async {
    final col = _menuCol;
    if (col == null) return;
    try {
      await col.doc(id).delete();
    } catch (e) {
      throw ValidationFailure('Failed to delete menu item: $e');
    }
  }

  /// M10: Upload photo to Firebase Storage and update imageUrl in Firestore (Admin)
  Future<String> uploadPhoto(String id, Uint8List photoBytes, {String mimeType = 'image/jpeg'}) async {
    final st = storage;
    if (st == null) throw const ValidationFailure('Firebase Storage is not initialized');
    try {
      final ref = st.ref('menu/$id.jpg');
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
    final st = storage;
    if (st == null) return;
    try {
      final ref = st.ref('menu/$id.jpg');
      await ref.delete();
      await updateItem(id, {'imageUrl': null});
    } catch (e) {
      throw ValidationFailure('Failed to delete photo: $e');
    }
  }
}
