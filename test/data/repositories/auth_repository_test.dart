import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/backend/services/smtp_config.dart';
import 'package:orderacoffee/backend/services/smtp_service.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';

class _FakeSmtpService extends SmtpService {
  @override
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    return true;
  }
}

class _FailingSmtpService extends SmtpService {
  @override
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    return false;
  }
}

void main() {
  group('AuthRepository (A1 - A7)', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late AuthRepository repository;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      fakeFirestore = FakeFirebaseFirestore();
      repository = AuthRepository(
        auth: mockAuth,
        firestore: fakeFirestore,
        smtpService: _FakeSmtpService(),
      );
    });

    test('A1: signUp creates user in auth and initializes profile doc in Firestore', () async {
      final profile = await repository.signUp(
        email: 'test@coffee.com',
        password: 'password123',
        name: 'Coffee Lover',
        phone: '0987654321',
      );

      expect(profile.email, 'test@coffee.com');
      expect(profile.name, 'Coffee Lover');
      expect(profile.role, 'customer');
      expect(profile.stamps, 0);
      expect(profile.favorites, isEmpty);

      final userDoc = await fakeFirestore.collection('users').doc(profile.uid).get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['role'], 'customer');
      expect(userDoc.data()?['name'], 'Coffee Lover');
      expect(userDoc.data()?.containsKey('passwordHash'), isFalse);
      expect(userDoc.data()?.containsKey('password'), isFalse);
    });

    test('A2 & A5: logIn authenticates user and triggers authStateChanges', () async {
      // Create user first
      final created = await repository.signUp(
        email: 'login@coffee.com',
        password: 'securePassword!',
        name: 'Login User',
        phone: '0911222333',
      );

      await repository.logOut();
      expect(repository.currentUser, isNull);

      final loggedInUser = await repository.logIn(
        email: 'login@coffee.com',
        password: 'securePassword!',
      );

      expect(loggedInUser.uid, created.uid);
      expect(repository.currentUser?.uid, created.uid);
    });

    test('A3: logOut clears the current user session', () async {
      await repository.signUp(
        email: 'logout@coffee.com',
        password: 'password123',
        name: 'Logout Test',
        phone: '0900000000',
      );

      expect(repository.currentUser, isNotNull);
      await repository.logOut();
      expect(repository.currentUser, isNull);
    });

    test('A4: resetPassword completes without throwing', () async {
      expect(
        () => repository.resetPassword('reset@coffee.com'),
        returnsNormally,
      );
    });

    test('A6: readRole returns customer by default from Firestore doc', () async {
      final user = await repository.signUp(
        email: 'role@coffee.com',
        password: 'password123',
        name: 'Role User',
        phone: '0900000001',
      );

      final role = await repository.readRole(user.uid);
      expect(role, 'customer');
    });

    test('A6: readRole throws NotFoundFailure if doc does not exist', () async {
      expect(
        () => repository.readRole('non_existent_uid'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('A7: deleteAccount removes profile from Firestore and deletes auth user', () async {
      final user = await repository.signUp(
        email: 'delete@coffee.com',
        password: 'password123',
        name: 'Delete User',
        phone: '0999999999',
      );

      final uid = user.uid;
      expect((await fakeFirestore.collection('users').doc(uid).get()).exists, isTrue);

      await repository.deleteAccount();

      expect(repository.currentUser, isNull);
      expect((await fakeFirestore.collection('users').doc(uid).get()).exists, isFalse);
    });

    test('A7: deleteAccount throws AuthFailure if no user is signed in', () async {
      expect(
        () => repository.deleteAccount(),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('sendEmailVerificationCode generates 6-digit code and stores in Firestore', () async {
      final code = await repository.sendEmailVerificationCode('verify@coffee.com');
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);

      final doc = await fakeFirestore.collection('email_verifications').doc('verify@coffee.com').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?.containsKey('code'), isFalse);
      expect(doc.data()?['codeHash'], isA<String>());
      expect((doc.data()?['codeHash'] as String).length, 64);
      expect(doc.data()?['verified'], isFalse);
    });

    test('verifyEmailCode validates valid code successfully', () async {
      final code = await repository.sendEmailVerificationCode('verify2@coffee.com');
      final result = await repository.verifyEmailCode(email: 'verify2@coffee.com', code: code);
      expect(result, isTrue);

      final doc = await fakeFirestore.collection('email_verifications').doc('verify2@coffee.com').get();
      expect(doc.data()?['verified'], isTrue);
    });

    test('verifyEmailCode throws ValidationFailure on incorrect code', () async {
      await repository.sendEmailVerificationCode('verify3@coffee.com');
      expect(
        () => repository.verifyEmailCode(email: 'verify3@coffee.com', code: '000000'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('SmtpConfig does not embed hardcoded credentials by default', () {
      expect(SmtpConfig.username, isEmpty);
      expect(SmtpConfig.password, isEmpty);
      expect(SmtpConfig.cleanPassword, isEmpty);
      expect(SmtpConfig.isConfigured, isFalse);
    });

    test('SmtpService retries fallback port 465 SSL when primary SMTP attempt fails', () async {
      int attempts = 0;
      final List<int> portsTried = [];
      final service = SmtpService(
        username: 'test@gmail.com',
        password: 'test-app-password',
        sendFunction: (Message msg, SmtpServer server) async {
          attempts++;
          portsTried.add(server.port);
          if (attempts == 1) {
            throw Exception('Primary port 587 blocked');
          }
          return SendReport(msg, DateTime.now(), DateTime.now(), DateTime.now());
        },
      );

      final sent = await service.sendOtpEmail(
        recipientEmail: 'customer@gmail.com',
        otpCode: '123456',
      );
      expect(sent, isTrue);
      expect(attempts, 2);
      expect(portsTried, containsAll([587, 465]));
    });

    test('sendEmailVerificationCode throws AuthFailure when SMTP dispatch fails', () async {
      final failingRepo = AuthRepository(
        auth: mockAuth,
        firestore: fakeFirestore,
        smtpService: _FailingSmtpService(),
      );

      expect(
        () => failingRepo.sendEmailVerificationCode('fail@coffee.com'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('signInWithGoogle authenticates and initializes Google user profile in Firestore', () async {
      final profile = await repository.signInWithGoogle(
        fallbackEmail: 'googleuser@gmail.com',
        fallbackName: 'Google Coffee User',
      );

      expect(profile.email, 'googleuser@gmail.com');
      expect(profile.name, 'Google Coffee User');
      expect(profile.isEmailVerified, isTrue);

      final doc = await fakeFirestore.collection('users').doc(profile.uid).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['email'], 'googleuser@gmail.com');
    });
  });
}
