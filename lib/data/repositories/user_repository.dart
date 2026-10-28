import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository({this._firestore});

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      firestore.collection('users');

  /// U1: Create user profile
  Future<void> createProfile(UserProfile profile) async {
    try {
      await _usersCol.doc(profile.uid).set({
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ValidationFailure('Failed to create profile: $e');
    }
  }

  /// U2: Watch user profile (live stream)
  Stream<UserProfile?> watchProfile(String uid) {
    return _usersCol.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  /// U2 (Future): Get profile once
  Future<UserProfile> getProfile(String uid) async {
    final doc = await _usersCol.doc(uid).get();
    if (!doc.exists) {
      throw const NotFoundFailure('User profile not found');
    }
    return UserProfile.fromFirestore(doc);
  }

  /// U3: Update profile fields (name, phone only - role and stamps are protected)
  Future<void> updateProfile(
    String uid, {
    String? name,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (phone != null) updates['phone'] = phone.trim();

    if (updates.isEmpty) return;

    try {
      await _usersCol.doc(uid).update(updates);
    } catch (e) {
      throw ValidationFailure('Failed to update profile: $e');
    }
  }

  /// U4: Add address via FieldValue.arrayUnion
  Future<void> addAddress(String uid, UserAddress address) async {
    try {
      await _usersCol.doc(uid).update({
        'addresses': FieldValue.arrayUnion([address.toMap()]),
      });
    } catch (e) {
      throw ValidationFailure('Failed to add address: $e');
    }
  }

  /// U5: Remove address via FieldValue.arrayRemove
  Future<void> removeAddress(String uid, UserAddress address) async {
    try {
      await _usersCol.doc(uid).update({
        'addresses': FieldValue.arrayRemove([address.toMap()]),
      });
    } catch (e) {
      throw ValidationFailure('Failed to remove address: $e');
    }
  }

  /// U6: Save FCM token
  Future<void> saveFcmToken(String uid, String token) async {
    try {
      await _usersCol.doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      throw ValidationFailure('Failed to save FCM token: $e');
    }
  }

  /// U7: List customers (Admin only)
  Future<List<UserProfile>> listCustomers() async {
    try {
      final snapshot = await _usersCol.where('role', isEqualTo: 'customer').get();
      return snapshot.docs.map(UserProfile.fromFirestore).toList();
    } catch (e) {
      throw PermissionFailure('Failed to list customers: $e');
    }
  }
}
