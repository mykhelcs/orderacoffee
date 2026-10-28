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

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      firestore.collection('users');

  User? get currentUser => auth.currentUser;

  Stream<User?> watchAuthState() => auth.authStateChanges();

  /// A1: Sign up with email/password and initialize user profile
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Failed to create user account');
      }

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

      await _usersCol.doc(user.uid).set({
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
    try {
      final credential = await auth.signInWithEmailAndPassword(
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
    try {
      await auth.signOut();
    } catch (e) {
      throw AuthFailure('Failed to sign out: $e');
    }
  }

  /// A4: Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Password reset failed', e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  /// A6: Read user role ('customer' or 'admin')
  Future<String> readRole(String uid) async {
    try {
      final user = auth.currentUser;
      if (user != null && user.uid == uid) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.claims?['admin'] == true) {
          return 'admin';
        }
      }

      final doc = await _usersCol.doc(uid).get();
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
    final user = auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No authenticated user to delete');
    }

    try {
      final uid = user.uid;
      await _usersCol.doc(uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Failed to delete account', e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthFailure('Failed to delete account: $e');
    }
  }
}
