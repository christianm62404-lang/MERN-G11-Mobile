import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance._showLocalNotification(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'timetrack_channel',
    'TimeTrack Notifications',
    description: 'Notifications for project and session updates',
    importance: Importance.high,
    playSound: true,
  );

  Function(Map<String, dynamic>)? onNotificationTap;

  Future<void> initialize() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestPermission();
    await _setupLocalNotifications();
    await _saveFcmToken();

    _fcm.onTokenRefresh.listen((token) async {
      await AuthService.instance.saveFcmToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  Future<void> _requestPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            _handleNotificationTap(data);
          } catch (_) {}
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _saveFcmToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await AuthService.instance.saveFcmToken(token);
      debugPrint('FCM Token: $token');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'TimeTrack',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          color: const Color(0xFF004D44),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    onNotificationTap?.call(data);
  }

  Future<String?> getToken() async => await _fcm.getToken();

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  Future<void> showSessionReminder({
    required String projectTitle,
    required String duration,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Session in Progress',
      'Working on "$projectTitle" for $duration',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF004D44),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
