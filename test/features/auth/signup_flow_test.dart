import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/auth/email_verification_screen.dart';
import 'package:orderacoffee/frontend/features/auth/signup_screen.dart';
import 'package:orderacoffee/frontend/widgets/philippine_phone_field.dart';

class _FakeAuthRepo extends AuthRepository {
  final _controller = StreamController<User?>.broadcast();
  String? generatedCode;

  @override
  Stream<User?> watchAuthState() => _controller.stream;

  @override
  Future<String> sendEmailVerificationCode(String email) async {
    generatedCode = '888999';
    return generatedCode!;
  }

  @override
  Future<bool> verifyEmailCode({required String email, required String code}) async {
    if (code == '888999') return true;
    throw Exception('Wrong code');
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    return UserProfile(
      uid: 'user-xyz',
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
      isEmailVerified: true,
    );
  }

  void dispose() => _controller.close();
}

class _FakeUserRepo extends UserRepository {}

void main() {
  group('SignUp to Email Verification and Dashboard Routing Flow', () {
    late _FakeAuthRepo fakeAuth;
    late _FakeUserRepo fakeUser;
    late ProviderContainer container;

    setUp(() {
      fakeAuth = _FakeAuthRepo();
      fakeUser = _FakeUserRepo();
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

    testWidgets('Full registration flow with change-email info retention, hidden code, and dashboard routing',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/signup',
        routes: [
          GoRoute(
            path: '/signup',
            builder: (context, state) => const SignUpScreen(),
          ),
          GoRoute(
            path: '/verify-email',
            builder: (context, state) => const EmailVerificationScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Dashboard Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SignUpScreen rendered with PhilippinePhoneField
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byType(PhilippinePhoneField), findsOneWidget);
      expect(find.text('+63'), findsOneWidget);

      // 1. Enter initial information with typo in email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Maria Clara'),
        'Maria Clara',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'maria@coughfee.ph'),
        'wrong@coughfee.ph',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '9XX XXX XXXX'),
        '09171234567',
      );
      await tester.pump();
      expect(find.text('917 123 4567'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 6 characters'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Re-enter your password'),
        'secret123',
      );

      // Tap Sign up
      await tester.ensureVisible(find.text('Sign up'));
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      // 2. Arrived on /verify-email screen
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('wrong@coughfee.ph'), findsOneWidget);

      // Verify NO on-screen code or auto-fill is displayed
      expect(find.textContaining('Preview code:'), findsNothing);
      expect(find.text('Auto-fill'), findsNothing);

      // 3. User taps "Change email address"
      await tester.tap(find.text('Change email address'));
      await tester.pumpAndSettle();

      // 4. Back on /signup: Verify Name, Phone, and Passwords are preserved, only Email is empty
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Maria Clara'), findsOneWidget);
      expect(find.text('917 123 4567'), findsOneWidget);
      expect(find.text('secret123'), findsNWidgets(2)); // password & confirm password
      expect(find.text('wrong@coughfee.ph'), findsNothing); // email cleared for re-entry

      // 5. Enter corrected email and submit
      await tester.enterText(
        find.widgetWithText(TextFormField, 'maria@coughfee.ph'),
        'correct@coughfee.ph',
      );

      await tester.ensureVisible(find.text('Sign up'));
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      // 6. Back on /verify-email with corrected email
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('correct@coughfee.ph'), findsOneWidget);

      // 7. Enter 6-digit code received via email
      await tester.enterText(find.byKey(const Key('otp_box_0')), '8');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_1')), '8');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_2')), '8');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_3')), '9');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_4')), '9');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_5')), '9');
      await tester.pump();

      await tester.ensureVisible(find.text('Verify and Continue'));
      await tester.tap(find.text('Verify and Continue'));
      await tester.pumpAndSettle();

      // 8. Routed to dashboard
      expect(find.text('Dashboard Screen'), findsOneWidget);
      expect(container.read(authProvider).isAuthenticated, isTrue);
    });
  });
}
