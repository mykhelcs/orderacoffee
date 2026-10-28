import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderacoffee/data/models/user_profile.dart';
import 'package:orderacoffee/data/repositories/notification_repository.dart';
import 'package:orderacoffee/data/repositories/user_repository.dart';

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

void main() {
  group('NotificationRepository (N1 - N2)', () {
    late MockFirebaseMessaging mockMessaging;
    late FakeFirebaseFirestore fakeFirestore;
    late UserRepository userRepo;
    late NotificationRepository notificationRepo;

    setUp(() {
      mockMessaging = MockFirebaseMessaging();
      fakeFirestore = FakeFirebaseFirestore();
      userRepo = UserRepository(firestore: fakeFirestore);
      notificationRepo = NotificationRepository(
        messaging: mockMessaging,
        userRepository: userRepo,
      );
    });

    test('N2: registerToken retrieves FCM token and updates user profile', () async {
      await userRepo.createProfile(const UserProfile(
        uid: 'user_fcm',
        name: 'FCM Tester',
        email: 'fcm@test.com',
        phone: '123',
      ));

      when(() => mockMessaging.getToken()).thenAnswer((_) async => 'device_token_xyz_999');

      final token = await notificationRepo.registerToken('user_fcm');
      expect(token, 'device_token_xyz_999');

      final profile = await userRepo.getProfile('user_fcm');
      expect(profile.fcmToken, 'device_token_xyz_999');
    });

    test('N2: watchTokenRefresh delegates to messaging stream', () {
      when(() => mockMessaging.onTokenRefresh).thenAnswer((_) => Stream.value('refreshed_token_456'));

      expect(notificationRepo.watchTokenRefresh(), emits('refreshed_token_456'));
    });
  });
}
