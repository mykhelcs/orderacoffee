import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  /// Initialize the notification service
  static Future<void> initialize() async {
    await _instance._initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    if (kDebugMode) {
      print('Notification tapped with payload: ${response.payload}');
    }
  }

  /// Show a local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'com.example.orderacoffee',
      'CafeGO Notifications',
      channelDescription: 'Notifications for CafeGO orders and rewards',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _instance._flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Show milestone notification (loyalty stamps)
  static Future<void> showLoyaltyMilestoneNotification({
    required int stamps,
  }) async {
    String title = 'Loyalty Milestone! 🎉';
    String body;

    if (stamps == 4) {
      body = 'You earned 4 stamps! Collect 4 more for a free drink.';
    } else if (stamps == 8) {
      body = 'Congratulations! You earned 8 stamps! Claim your free drink now!';
    } else {
      return;
    }

    await showLocalNotification(
      id: stamps,
      title: title,
      body: body,
      payload: 'loyalty_milestone_$stamps',
    );
  }
}
