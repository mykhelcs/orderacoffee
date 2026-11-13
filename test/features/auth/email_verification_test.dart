import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/auth/email_verification_screen.dart';

class _MockAuthRepo extends AuthRepository {
  final _controller = StreamController<User?>.broadcast();
  String? lastCode;

  @override
  Stream<User?> watchAuthState() => _controller.stream;

  @override
  Future<String> sendEmailVerificationCode(String email) async {
    lastCode = '654321';
    return lastCode!;
  }

  @override
  Future<bool> verifyEmailCode({required String email, required String code}) async {
    if (code == '654321') return true;
    throw const ValidationFailure('Invalid 6-digit code. Please check your email and try again.');
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    return UserProfile(
      uid: 'user-abc',
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
      isEmailVerified: true,
    );
  }

  void dispose() => _controller.close();
}

class _MockUserRepo extends UserRepository {}

void main() {
  group('Email Verification Flow Tests', () {
    late _MockAuthRepo mockAuth;
    late _MockUserRepo mockUser;
    late ProviderContainer container;

    setUp(() {
      mockAuth = _MockAuthRepo();
      mockUser = _MockUserRepo();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          userRepositoryProvider.overrideWithValue(mockUser),
        ],
      );
    });

    tearDown(() {
      mockAuth.dispose();
      container.dispose();
    });

    test('initiateSignUp sends 6-digit code and populates pending state', () async {
      final notifier = container.read(authProvider.notifier);
      final code = await notifier.initiateSignUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      expect(code, '654321');
      final state = container.read(authProvider);
      expect(state.pendingEmail, 'maria@coughfee.ph');
      expect(state.isVerificationSent, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('prepareChangeEmail preserves pendingRegistration while clearing pendingEmail', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.initiateSignUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      expect(container.read(authProvider).pendingEmail, 'maria@coughfee.ph');
      expect(container.read(authProvider).pendingRegistration?['name'], 'Maria Clara');

      notifier.prepareChangeEmail();

      final state = container.read(authProvider);
      expect(state.pendingEmail, '');
      expect(state.isVerificationSent, isFalse);
      expect(state.pendingRegistration?['name'], 'Maria Clara');
      expect(state.pendingRegistration?['phone'], '+63 917 123 4567');
      expect(state.pendingRegistration?['password'], 'password123');
    });

    test('confirmEmailVerification succeeds with valid code and creates profile', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.initiateSignUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      final result = await notifier.confirmEmailVerification('654321');
      expect(result, isTrue);

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.profile?.name, 'Maria Clara');
      expect(state.profile?.email, 'maria@coughfee.ph');
      expect(state.profile?.isEmailVerified, isTrue);
    });

    test('confirmEmailVerification throws ValidationFailure on wrong code', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.initiateSignUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      expect(
        () => notifier.confirmEmailVerification('000000'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    testWidgets('EmailVerificationScreen does NOT display code on screen and handles code input', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = container.read(authProvider.notifier);
      await notifier.initiateSignUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EmailVerificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and email subtitle
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('maria@coughfee.ph'), findsOneWidget);

      // Verify OTP code is NEVER displayed in UI
      expect(find.textContaining('Preview code:'), findsNothing);
      expect(find.text('Auto-fill'), findsNothing);

      // Verify delivery notice is shown
      expect(find.textContaining('check your email inbox'), findsOneWidget);

      // Check all 6 OTP boxes
      for (int i = 0; i < 6; i++) {
        expect(find.byKey(Key('otp_box_$i')), findsOneWidget);
      }

      // Enter code digit by digit (received via email)
      await tester.enterText(find.byKey(const Key('otp_box_0')), '6');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_1')), '5');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_2')), '4');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_3')), '3');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_4')), '2');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_box_5')), '1');
      await tester.pump();

      // Tap Verify
      await tester.tap(find.text('Verify and Continue'));
      await tester.pumpAndSettle();

      // State should now be authenticated
      expect(container.read(authProvider).isAuthenticated, isTrue);
    });

    testWidgets('EmailVerificationScreen backspace on empty OTP box clears and focuses previous box', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = container.read(authProvider.notifier);
      await notifier.initiateSignUp(
        name: 'Maria Clara',
        email: 'maria@coughfee.ph',
        phone: '+63 917 123 4567',
        password: 'password123',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EmailVerificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('otp_box_0')), '6');
      await tester.pump();

      await tester.tap(find.byKey(const Key('otp_box_1')));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      final box0Field = tester.widget<TextFormField>(find.byKey(const Key('otp_box_0')));
      final box0Editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('otp_box_0')),
          matching: find.byType(EditableText),
        ),
      );
      expect(box0Field.controller?.text, isEmpty);
      expect(box0Editable.focusNode.hasFocus, isTrue);
    });
  });
}
