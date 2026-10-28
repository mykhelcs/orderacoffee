import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/user_profile.dart';
import 'package:orderacoffee/data/repositories/auth_repository.dart';
import 'package:orderacoffee/data/repositories/user_repository.dart';
import 'package:orderacoffee/features/auth/auth_provider.dart';

class _FakeAuthRepository extends AuthRepository {
  final _controller = StreamController<User?>.broadcast();
  UserProfile? _registeredProfile;

  @override
  Stream<User?> watchAuthState() => _controller.stream;

  @override
  Future<User> logIn({required String email, required String password}) async {
    if (password == 'wrong-pass') {
      throw const AuthFailure('Invalid credentials');
    }
    // Return dummy user or throw
    throw const AuthFailure('Firebase not initialized');
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _registeredProfile = UserProfile(
      uid: 'u-123',
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
    );
    return _registeredProfile!;
  }

  @override
  Future<void> logOut() async {
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

class _FakeUserRepository extends UserRepository {
  @override
  Future<UserProfile> getProfile(String uid) async {
    return UserProfile(
      uid: uid,
      name: 'Juan dela Cruz',
      email: 'juan@coughfee.ph',
      phone: '+63 912 345 6789',
      role: 'customer',
    );
  }
}

void main() {
  group('AuthNotifier Tests', () {
    late ProviderContainer container;
    late _FakeAuthRepository fakeAuth;
    late _FakeUserRepository fakeUser;

    setUp(() {
      fakeAuth = _FakeAuthRepository();
      fakeUser = _FakeUserRepository();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          userRepositoryProvider.overrideWithValue(fakeUser),
        ],
      );
    });

    tearDown(() {
      fakeAuth.dispose();
      container.dispose();
    });

    test('initial state is unauthenticated', () {
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.profile, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('signIn with valid credentials succeeds via fallback and updates state', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('juan@coughfee.ph', 'password123');

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.profile, isNotNull);
      expect(state.profile!.email, 'juan@coughfee.ph');
      expect(state.profile!.name, 'Juan dela Cruz');
      expect(state.isAdmin, isFalse);
    });

    test('signIn with admin credentials succeeds and recognizes admin', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('admin@coughfee.ph', 'admin123');

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isAdmin, isTrue);
    });

    test('signIn with wrong password throws AuthFailure', () async {
      final notifier = container.read(authProvider.notifier);
      expect(
        () => notifier.signIn('juan@coughfee.ph', 'wrong-pass'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('signUp creates new account and sets state', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.profile!.name, 'Maria Clara');
      expect(state.profile!.email, 'maria@coughfee.ph');
    });

    test('signOut clears authenticated profile', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('juan@coughfee.ph', 'password123');
      expect(container.read(authProvider).isAuthenticated, isTrue);

      await notifier.signOut();
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.profile, isNull);
    });
  });
}
