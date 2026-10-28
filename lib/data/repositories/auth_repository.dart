import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/failures.dart';
import '../models/user_profile.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth? get auth {
    if (_auth != null) return _auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get firestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _usersCol {
    final fs = firestore;
    if (fs == null) return null;
    return fs.collection('users');
  }

  User? get currentUser => auth?.currentUser;

  Stream<User?> watchAuthState() {
    final a = auth;
    if (a == null) return Stream.value(null);
    return a.authStateChanges();
  }

  /// A1: Sign up with email/password and initialize user profile in Firestore
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final a = auth;
    final col = _usersCol;
    if (a == null || col == null) {
      throw const AuthFailure('Firebase is not initialized');
    }

    try {
      final credential = await a.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Failed to create user account');
      }

      await user.updateDisplayName(name.trim());

      final profile = UserProfile(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: 'customer',
        favorites: const [],
        stamps: 0,
        addresses: const [],
        createdAt: DateTime.now(),
      );

      await col.doc(user.uid).set({
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Authentication error', e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  /// A2: Log in with email and password
  Future<User> logIn({
    required String email,
    required String password,
  }) async {
    final a = auth;
    if (a == null) {
      throw const AuthFailure('Firebase is not initialized');
    }

    try {
      final credential = await a.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('User not found after sign in');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Failed to log in', e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  /// A3: Log out current user
  Future<void> logOut() async {
    final a = auth;
    if (a == null) return;
    try {
      await a.signOut();
    } catch (e) {
      throw AuthFailure('Failed to sign out: $e');
    }
  }

  /// A4: Send password reset email
  Future<void> resetPassword(String email) async {
    final a = auth;
    if (a == null) {
      throw const AuthFailure('Firebase is not initialized');
    }
    try {
      await a.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Password reset failed', e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  /// A6: Read user role ('customer' or 'admin')
  Future<String> readRole(String uid) async {
    final a = auth;
    final col = _usersCol;
    if (a == null || col == null) return 'customer';

    try {
      final user = a.currentUser;
      if (user != null && user.uid == uid) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.claims?['admin'] == true) {
          return 'admin';
        }
      }

      final doc = await col.doc(uid).get();
      if (!doc.exists) {
        throw const NotFoundFailure('User profile not found');
      }
      return (doc.data()?['role'] as String?) ?? 'customer';
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure('Failed to read role: $e');
    }
  }

  /// A7: Delete account and profile document
  Future<void> deleteAccount() async {
    final a = auth;
    final col = _usersCol;
    if (a == null || col == null) return;

    final user = a.currentUser;
    if (user == null) {
      throw const AuthFailure('No authenticated user to delete');
    }

    try {
      final uid = user.uid;
      await col.doc(uid).delete();
      await user.delete();
      await a.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Failed to delete account', e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure(e.toString());
    }
  }
}
