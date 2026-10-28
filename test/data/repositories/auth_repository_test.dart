import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/repositories/auth_repository.dart';

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
  });
}
