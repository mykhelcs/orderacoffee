import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/auth/login_screen.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';

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
  Future<UserProfile> signInWithGoogle({
    String? fallbackEmail,
    String? fallbackName,
  }) async {
    if (fallbackEmail == null || fallbackEmail.isEmpty) {
      throw const AuthFailure('Requires Gmail popup selection', 'popup-required');
    }
    final email = fallbackEmail;
    final name = fallbackName ?? 'Google User';
    return UserProfile(
      uid: 'google-u-1',
      name: name,
      email: email,
      phone: '',
      role: 'customer',
      isEmailVerified: true,
    );
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
      SharedPreferences.setMockInitialValues({});
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

    test('signInWithGoogle authenticates user, sets lastLoginMethod to google, and preserves it across signOut', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signInWithGoogle(
        fallbackEmail: 'mykhel@gmail.com',
        fallbackName: 'Mykhel Gmail',
      );

      final signedInState = container.read(authProvider);
      expect(signedInState.isAuthenticated, isTrue);
      expect(signedInState.profile?.email, 'mykhel@gmail.com');
      expect(signedInState.lastLoginMethod, 'google');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_login_method'), 'google');

      await notifier.signOut();
      final signedOutState = container.read(authProvider);
      expect(signedOutState.isAuthenticated, isFalse);
      expect(signedOutState.lastLoginMethod, 'google');
    });

    testWidgets('LoginScreen displays Sign in with Google button, pops up Gmail connection, and shows Last used badge on upper right', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Home Dashboard')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: appLightTheme,
            darkTheme: appDarkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, Sign in with Google button is shown, and Last used badge is not visible
      expect(find.byKey(const Key('google_sign_in_button')), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byKey(const Key('google_last_used_badge')), findsNothing);

      // Tap Sign in with Google -> triggers Gmail sign-in popup
      await tester.ensureVisible(find.byKey(const Key('google_sign_in_button')));
      await tester.tap(find.byKey(const Key('google_sign_in_button')));
      await tester.pumpAndSettle();

      // Verify the Gmail login connection popup is displayed
      expect(find.byKey(const Key('gmail_popup_dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('gmail_popup_email_field')),
        'glennmykhel@gmail.com',
      );
      await tester.tap(find.byKey(const Key('gmail_popup_continue_button')));
      await tester.pumpAndSettle();

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).profile?.email, 'glennmykhel@gmail.com');
      expect(container.read(authProvider).lastLoginMethod, 'google');

      // Sign out and return to /login
      await container.read(authProvider.notifier).signOut();
      router.go('/login');
      await tester.pumpAndSettle();

      // Now the upper-right "Last used" badge container is displayed on the Sign in with Google button
      expect(find.byKey(const Key('google_last_used_badge')), findsOneWidget);
      expect(find.text('Last used'), findsOneWidget);
    });
  });
}
