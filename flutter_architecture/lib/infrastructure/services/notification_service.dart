import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';

/// Service responsible for handling app notifications
/// Supports both local notifications and Firebase Cloud Messaging
class NotificationService {
  final _logger = Logger('NotificationService');
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _firebaseMessaging;

  // Notification channels
  static const String _mushReminderChannelId = 'mushroom_reminders';
  static const String _expertVerificationChannelId = 'expert_verification';
  static const String _communityChannelId = 'community_notifications';
  static const String _foragingChannelId = 'foraging_notifications';

  /// Initialize notification services
  Future<void> initialize() async {
    _logger.info('Initializing notification service');

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Setup local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createAndroidNotificationChannels();
    }

    // Setup Firebase Cloud Messaging (if available)
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      await _requestNotificationPermissions();

      // Setup FCM handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Get FCM token
      final token = await _firebaseMessaging?.getToken();
      _logger.info('FCM token: $token');
    } catch (e) {
      _logger.warning('Firebase messaging initialization failed: $e');
      _logger.info('Running in offline-only mode');
    }
  }

  /// Create Android notification channels
  Future<void> _createAndroidNotificationChannels() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _mushReminderChannelId,
            'Mushroom Reminders',
            description:
                'Reminders about mushroom seasons and foraging opportunities',
            importance: Importance.high,
          ),
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _expertVerificationChannelId,
            'Expert Verification',
            description:
                'Notifications about expert verification of mushroom identifications',
            importance: Importance.high,
          ),
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _communityChannelId,
            'Community',
            description: 'Community alerts and forum notifications',
            importance: Importance.defaultImportance,
          ),
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _foragingChannelId,
            'Foraging',
            description: 'Foraging site and tracking notifications',
            importance: Importance.low,
          ),
        );
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    // iOS permissions
    if (Platform.isIOS) {
      await _firebaseMessaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Android permissions handled through manifest
  }

  /// Handle foreground FCM messages
  void _handleForegroundMessage(RemoteMessage message) {
    _logger.info('Received foreground message: ${message.messageId}');

    // Extract notification content
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Show local notification for the received FCM message
      showNotification(
        title: notification.title ?? 'MushroomMaster',
        body: notification.body ?? '',
        channelId: _getChannelForNotificationType(data['type']),
        payload: data.toString(),
      );
    }
  }

  /// Handle when a user taps on a notification that opened the app
  void _handleMessageOpenedApp(RemoteMessage message) {
    _logger.info('App opened from notification: ${message.messageId}');
    // This can be used to navigate to specific screens based on notification data
  }

  /// Determine notification channel based on notification type
  String _getChannelForNotificationType(String? type) {
    switch (type) {
      case 'expert_verification':
        return _expertVerificationChannelId;
      case 'community':
        return _communityChannelId;
      case 'foraging':
        return _foragingChannelId;
      default:
        return _mushReminderChannelId;
    }
  }

  /// Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String channelId = _mushReminderChannelId,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _mushReminderChannelId,
      'Mushroom Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond, // Unique ID
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Schedule a notification for the future
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String channelId = _mushReminderChannelId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Scheduled Notification',
      icon: '@mipmap/ic_launcher',
    );

    const iOSDetails = DarwinNotificationDetails();

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecond,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// iOS notification callback
  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    _logger.info('Received iOS local notification: $title');
  }

  /// Notification response callback
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _logger.info('Notification response: ${response.payload}');
    // Handle notification taps here - can add navigation logic
  }

  /// Subscribe to a Firebase topic (e.g., for region-specific notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging?.subscribeToTopic(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (e) {
      _logger.warning('Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribe from a Firebase topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging?.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.warning('Failed to unsubscribe from topic: $e');
    }
  }
}

/// Background message handler for Firebase Cloud Messaging
/// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No access to context from background handlers
  print('Handling background message: ${message.messageId}');

  // Simple logging only - complex operations should be done when app is open
}
