import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/user_profile.dart';
import 'package:orderacoffee/data/repositories/user_repository.dart';

void main() {
  group('UserRepository (U1 - U7)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = UserRepository(firestore: fakeFirestore);
    });

    test('U1 & U2: createProfile writes to Firestore and watchProfile streams updates', () async {
      const profile = UserProfile(
        uid: 'user_100',
        name: 'Carlos Ruiz',
        email: 'carlos@example.com',
        phone: '09123456780',
        role: 'customer',
      );

      await repository.createProfile(profile);

      final fetched = await repository.getProfile('user_100');
      expect(fetched.name, 'Carlos Ruiz');
      expect(fetched.email, 'carlos@example.com');
      expect(fetched.role, 'customer');

      final streamProfile = await repository.watchProfile('user_100').first;
      expect(streamProfile?.uid, 'user_100');
      expect(streamProfile?.name, 'Carlos Ruiz');
    });

    test('U2: getProfile throws NotFoundFailure for non-existent uid', () async {
      expect(
        () => repository.getProfile('unknown_user'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('U3: updateProfile modifies only allowed fields', () async {
      const profile = UserProfile(
        uid: 'user_101',
        name: 'Old Name',
        email: 'user101@example.com',
        phone: '0900000000',
      );
      await repository.createProfile(profile);

      await repository.updateProfile(
        'user_101',
        name: 'New Name',
        phone: '0999888777',
      );

      final updated = await repository.getProfile('user_101');
      expect(updated.name, 'New Name');
      expect(updated.phone, '0999888777');
      expect(updated.role, 'customer');
    });

    test('U4 & U5: addAddress and removeAddress with FieldValue.arrayUnion/Remove', () async {
      const profile = UserProfile(
        uid: 'user_102',
        name: 'Address Tester',
        email: 'addr@example.com',
        phone: '0900000002',
      );
      await repository.createProfile(profile);

      const addr1 = UserAddress(
        id: 'addr_1',
        label: 'Home',
        line1: '123 Baker St',
        city: 'London',
      );
      const addr2 = UserAddress(
        id: 'addr_2',
        label: 'Office',
        line1: '456 Wall St',
        city: 'London',
      );

      // Add addresses
      await repository.addAddress('user_102', addr1);
      await repository.addAddress('user_102', addr2);

      var current = await repository.getProfile('user_102');
      expect(current.addresses.length, 2);

      // Remove one address
      await repository.removeAddress('user_102', addr1);

      current = await repository.getProfile('user_102');
      expect(current.addresses.length, 1);
      expect(current.addresses.first.id, 'addr_2');
    });

    test('U6: saveFcmToken updates fcmToken field', () async {
      const profile = UserProfile(
        uid: 'user_103',
        name: 'FCM Tester',
        email: 'fcm@example.com',
        phone: '0900000003',
      );
      await repository.createProfile(profile);

      await repository.saveFcmToken('user_103', 'mock_token_abc_123');

      final current = await repository.getProfile('user_103');
      expect(current.fcmToken, 'mock_token_abc_123');
    });

    test('U7: listCustomers queries only users with role customer', () async {
      await repository.createProfile(const UserProfile(
        uid: 'cust_1',
        name: 'Cust 1',
        email: 'c1@test.com',
        phone: '111',
        role: 'customer',
      ));
      await repository.createProfile(const UserProfile(
        uid: 'cust_2',
        name: 'Cust 2',
        email: 'c2@test.com',
        phone: '222',
        role: 'customer',
      ));
      await repository.createProfile(const UserProfile(
        uid: 'admin_1',
        name: 'Admin User',
        email: 'admin@test.com',
        phone: '333',
        role: 'admin',
      ));

      final customers = await repository.listCustomers();
      expect(customers.length, 2);
      expect(customers.every((c) => c.role == 'customer'), isTrue);
    });
  });
}
