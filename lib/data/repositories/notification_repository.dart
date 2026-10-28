import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/errors/failures.dart';
import 'user_repository.dart';

class NotificationRepository {
  NotificationRepository({
    FirebaseMessaging? messaging,
    UserRepository? userRepository,
  })  : _messaging = messaging,
        _userRepository = userRepository;

  final FirebaseMessaging? _messaging;
  final UserRepository? _userRepository;

  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;

  /// N1: Request push notification permission
  Future<NotificationSettings> requestPermission() async {
    try {
      return await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      throw ValidationFailure('Failed to request notification permission: $e');
    }
  }

  /// N2: Register and persist FCM token
  Future<String?> registerToken(String uid) async {
    try {
      final token = await messaging.getToken();
      if (token != null && _userRepository != null) {
        await _userRepository.saveFcmToken(uid, token);
      }
      return token;
    } catch (e) {
      throw ValidationFailure('Failed to register FCM token: $e');
    }
  }

  /// N2: Listen to token refreshes
  Stream<String> watchTokenRefresh() {
    return messaging.onTokenRefresh;
  }
}
