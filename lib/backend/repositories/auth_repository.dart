import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/backend/services/security.dart';
import 'package:orderacoffee/backend/services/smtp_config.dart';
import 'package:orderacoffee/backend/services/smtp_service.dart';
import '../models/user_profile.dart';

class _InMemoryVerification {
  const _InMemoryVerification({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;
}

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SmtpService? smtpService,
  })  : _auth = auth,
        _firestore = firestore,
        _smtpService = smtpService ?? SmtpService();

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final SmtpService _smtpService;

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

  CollectionReference<Map<String, dynamic>>? get _emailVerificationsCol {
    final fs = firestore;
    if (fs == null) return null;
    return fs.collection('email_verifications');
  }

  static final Map<String, _InMemoryVerification> _inMemoryVerifications = {};

  User? get currentUser => auth?.currentUser;

  Stream<User?> watchAuthState() {
    final a = auth;
    if (a == null) return Stream.value(null);
    return a.authStateChanges();
  }

  /// Sends a 6-digit email authentication code via SMTP and records it.
  Future<String> sendEmailVerificationCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final code = (100000 + Random().nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    final col = _emailVerificationsCol;
    final fs = firestore;
    if (col != null) {
      try {
        await col.doc(cleanEmail).set({
          'email': cleanEmail,
          'code': code,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
          'verified': false,
        });

        // Also queue in Firestore 'mail' collection for trigger-email extension
        if (fs != null) {
          try {
            await fs.collection('mail').add({
              'to': [cleanEmail],
              'message': {
                'subject': 'Your COUGHFEE Verification Code: $code',
                'text': 'Your 6-digit verification code is: $code. It expires in 10 minutes.',
              },
            });
          } catch (_) {}
        }
      } catch (_) {
        _inMemoryVerifications[cleanEmail] = _InMemoryVerification(
          code: code,
          expiresAt: expiresAt,
        );
      }
    } else {
      _inMemoryVerifications[cleanEmail] = _InMemoryVerification(
        code: code,
        expiresAt: expiresAt,
      );
    }

    // Dispatch via SMTP
    final sent = await _smtpService.sendOtpEmail(
      recipientEmail: cleanEmail,
      otpCode: code,
    );

    if (!sent && SmtpConfig.isConfigured) {
      throw const AuthFailure(
        'Failed to deliver verification email. Please check your internet connection or email address.',
      );
    }

    return code;
  }

  /// Verifies a 6-digit email authentication code.
  Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    final col = _emailVerificationsCol;
    if (col != null) {
      try {
        final doc = await col.doc(cleanEmail).get();
        if (doc.exists) {
          final data = doc.data()!;
          final storedCode = data['code'] as String? ?? '';
          final expiresAtTimestamp = data['expiresAt'] as Timestamp?;
          final expiresAt = expiresAtTimestamp?.toDate();

          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            throw const ValidationFailure('Verification code has expired. Please request a new code.');
          }

          if (storedCode != cleanCode) {
            throw const ValidationFailure('Invalid 6-digit code. Please check your email and try again.');
          }

          await col.doc(cleanEmail).update({'verified': true});
          return true;
        }
      } catch (e) {
        if (e is AppException) rethrow;
      }
    }

    final mem = _inMemoryVerifications[cleanEmail];
    if (mem != null) {
      if (DateTime.now().isAfter(mem.expiresAt)) {
        throw const ValidationFailure('Verification code has expired. Please request a new code.');
      }
      if (mem.code != cleanCode) {
        throw const ValidationFailure('Invalid 6-digit code. Please check your email and try again.');
      }
      return true;
    }

    // Default testing code fallback only in debug/preview or when Firestore is unavailable
    if ((kDebugMode || firestore == null) && cleanCode == '123456') {
      return true;
    }

    throw const ValidationFailure('Verification code not found or expired.');
  }

  /// A1: Sign up with email/password, hash password, and initialize user credentials in Firestore
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

    User? user;
    try {
      final credential = await a.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      user = credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Self-healing: if the account was created during an earlier verification attempt
        // where saving the Firestore profile failed, sign in using the provided password
        // so we can recover and complete profile initialization.
        try {
          final signinCred = await a.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          user = signinCred.user;
        } catch (_) {
          throw AuthFailure(
            'The email address is already in use by another account.',
            e.code,
          );
        }
      } else {
        throw AuthFailure(e.message ?? 'Authentication error', e.code);
      }
    }

    if (user == null) {
      throw const AuthFailure('Failed to create user account');
    }

    try {
      await user.updateDisplayName(name.trim());
    } catch (_) {}

    // Hash password using salted SHA-256 before saving to Firestore
    final passwordHash = hashPassword(password, salt: user.uid);

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
      isEmailVerified: true,
    );

    try {
      await col.doc(user.uid).set({
        ...profile.toMap(),
        'passwordHash': passwordHash,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return profile;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthFailure(
          'Database permission denied: Please publish firestore.rules in Firebase Console for project coughfee-app.',
          'permission-denied',
        );
      }
      throw AuthFailure('Failed to initialize user profile: ${e.message}', e.code);
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
