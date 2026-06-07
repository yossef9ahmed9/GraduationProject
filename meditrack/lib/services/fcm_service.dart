import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditrack/services/api_service.dart';

// ─────────────────────────────────────────────────────────────
// Background message handler — must be a top-level function
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this is called.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────
// FcmService
// ─────────────────────────────────────────────────────────────
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;

  // Local notifications (foreground)
  final _localNotif = FlutterLocalNotificationsPlugin();

  // Callbacks for in-app handling
  void Function(String title, String body, Map<String, dynamic> data)?
      onMessageReceived;

  // ── Initialise ──────────────────────────────────────────────
  Future<void> init({
    required String userEmail,
    required String authToken,
  }) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (iOS / Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'meditrack_alerts',
      'MediTrack Alerts',
      description: 'Chat messages, emergencies and dispatches',
      importance: Importance.high,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init local notifications plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotif.initialize(initSettings);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((message) {
      _handleMessage(message, foreground: true);
    });

    // Notification tap while app in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message, foreground: false);
    });

    // Get token and register with backend
    await _registerToken(userEmail: userEmail, authToken: authToken);
  }

  // ── Register FCM token with our backend ─────────────────────
  Future<void> _registerToken({
    required String userEmail,
    required String authToken,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FCM] ❌ getToken() returned null');
        return;
      }
      debugPrint('[FCM] ✅ Device token obtained: ${token.substring(0, 20)}...');

      final result = await apiService.registerFcmToken(userEmail, token);
      if (result.ok) {
        debugPrint('[FCM] ✅ Token registered with backend for $userEmail');
      } else {
        debugPrint('[FCM] ❌ Backend registration failed: ${result.error} (${result.statusCode})');
      }

      // Refresh token if it rotates
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] 🔄 Token refreshed, re-registering...');
        apiService.registerFcmToken(userEmail, newToken);
      });
    } catch (e) {
      debugPrint('[FCM] ❌ Token registration exception: $e');
    }
  }

  // ── Handle incoming message ──────────────────────────────────
  void _handleMessage(RemoteMessage message, {required bool foreground}) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'MediTrack';
    final body  = notification?.body  ?? data['body']  ?? '';

    debugPrint('[FCM] Message received — title=$title foreground=$foreground');

    // Show local notification when app is in foreground
    if (foreground) {
      _showLocalNotification(title: title, body: body, data: data);
    }

    // Notify in-app listeners (e.g. NotificationProvider)
    onMessageReceived?.call(title, body, data);
  }

  // ── Show a local heads-up notification ──────────────────────
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'meditrack_alerts',
      'MediTrack Alerts',
      channelDescription: 'Chat messages, emergencies and dispatches',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }
}

final fcmService = FcmService.instance;
