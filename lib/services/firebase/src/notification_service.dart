// ─────────────────────────────────────────────────────────────────────────────
// notification_service.dart
// CHANGED:
//   • Added `initializeForWeb()` method — requests browser notification
//     permission and obtains the FCM web token (VAPID key required).
//   • Wrapped `dart:io` File usage inside `!kIsWeb` guard.
//   • `getToken()` now guards the APNS call with `!kIsWeb`.
//   • `_requestPermission()` iOS-specific code guarded with `!kIsWeb`.
//   • `_downloadAndMakeCircular()` uses `getTemporaryDirectory()` only on
//     non-web; on web returns null immediately (no local filesystem).
//   • Everything else (Firestore streams, chat handler, etc.) unchanged.
//
// HOW TO GET YOUR VAPID KEY:
//   Firebase Console → Project Settings → Cloud Messaging → Web Push certs
//   → Generate Key Pair → copy the key string into kVapidKey below.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '/constants/constants.dart';
import '/firebase_options.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/app/app.dart';
import '/views/screens/calendar/form/event_view.dart';

// Only import dart:io + path_provider on non-web platforms.
// On web these packages either don't exist or have no filesystem access.
import 'notification_service_io.dart'
    if (dart.library.html) 'notification_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VAPID key — replace with your actual key from Firebase Console.
// ─────────────────────────────────────────────────────────────────────────────
const String kVapidKey = 'BElo9iyDmRacZr_hHvqLsXhMjCdn4mE8t6XZve1RD6DlU8g5NUTV1Xl8UiiMXkRmBDklec0WQ8KxPfTAFNSBw5o';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.setupFlutterNotifications();
    await NotificationService.instance.showNotification(message);
  } catch (e, st) {
    await ErrorService.recordError(e, st);
  }
}

/// Returns the FCM token for the current device/browser.
Future<String> getToken() async {
  try {
    if (!kIsWeb) {
      // APNS token required on iOS before FCM token is available
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
    }
    // On web, pass the VAPID key to identify the push subscription.
    String? fcm = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? kVapidKey : null,
    );
    return fcm ?? '';
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    return '';
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  // ── Web initialisation ────────────────────────────────────────────────────
  /// Call this on web instead of initalize().
  /// Requests browser notification permission and sets up message handlers.
  Future<void> initializeForWeb() async {
    try {
      // Request permission — shows browser permission prompt
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Get web push token (requires VAPID key)
      final token = await _messaging.getToken(vapidKey: kVapidKey);
      debugPrint('🌐 Web FCM token: $token');

      // Listen for foreground messages on web
      FirebaseMessaging.onMessage.listen(_handleWebForegroundMessage);

      // Handle notification tap when app was in background / closed
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleBackgroundMessage(message.data);
      });

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage.data);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  void _handleWebForegroundMessage(RemoteMessage message) {
    // On web, flutter_local_notifications is not available.
    // Show an in-app snackbar/dialog instead.
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'You have a new message';

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Mobile initialisation (unchanged) ────────────────────────────────────
  Future<void> initalize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await _requestPermission();
      await setupFlutterNotifications();
      await _setupMessageHandlers();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // iOS-specific — not needed on web
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> setupFlutterNotifications() async {
    // flutter_local_notifications does not support web
    if (kIsWeb) return;

    try {
      if (_isFlutterLocalNotificationsInitialized) return;

      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important notifications',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);

      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      final darwinNotificationCategories = [
        DarwinNotificationCategory(
          'REPLY_CATEGORY',
          actions: [
            DarwinNotificationAction.text(
              'REPLY_ACTION_KEY',
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Type your reply...',
            ),
          ],
        ),
      ];

      final initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: darwinNotificationCategories,
      );

      final initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) async {
          if (details.actionId == 'REPLY_ACTION_KEY') {
            final reply = details.input;
            final payload = convertPayload(details.payload ?? '{}');
            await _replyMessage(payload, reply ?? '');
          } else {
            _handleBackgroundMessage(convertPayload(details.payload ?? '{}'));
          }
        },
      );

      _isFlutterLocalNotificationsInitialized = true;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  final Map<String, List<Message>> _messageHistory = {};

  Future<void> showNotification(RemoteMessage message) async {
    // On web, showNotification is handled by the service worker (SW).
    // Foreground messages are handled by _handleWebForegroundMessage().
    if (kIsWeb) return;

    try {
      final notification = message.notification;
      final data = message.data;
      final type = data['type'];
      final chatId = data['chatId'];
      // IMPORTANT: prefer `data['title']`/`data['body']` over
      // `notification?.title`/`notification?.body`. On Android, when this
      // handler runs from the background isolate, `message.notification` is
      // frequently null (the OS consumes it to draw the system tray icon
      // before Flutter ever sees it) while `message.data` is always intact.
      // Falling back to `notification` first is what caused the sender name
      // to show as "Unknown".
      final senderName = data['title'] ?? notification?.title ?? 'Unknown';
      final messageText = data['body'] ?? notification?.body ?? 'New message';
      final senderImageUrl = data['senderImageUrl'];

      if (type == 'chat' && chatId != null) {
        String? avatarPath = await downloadAvatarCircular(
          senderImageUrl,
          'sender_$chatId',
        );

        final groupKey = 'chat_$chatId';
        final bool isUserReply = data['isReply'] == 'true';

        final me = Person(name: 'You');
        final senderPerson = Person(
          name: isUserReply ? 'You' : senderName,
          icon: avatarPath != null
              ? BitmapFilePathAndroidIcon(avatarPath)
              : null,
        );

        final newMessage = Message(messageText, DateTime.now(), senderPerson);
        _messageHistory.putIfAbsent(groupKey, () => []);
        _messageHistory[groupKey]!.add(newMessage);

        final style = MessagingStyleInformation(
          me,
          messages: _messageHistory[groupKey] ?? [],
          conversationTitle: data['chatTitle'],
          groupConversation: false,
        );

        final notificationDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_channel',
            'Chat Messages',
            channelDescription: 'All chat messages',
            styleInformation: style,
            importance: Importance.max,
            priority: Priority.high,
            groupKey: groupKey,
            onlyAlertOnce: true,
            actions: [
              const AndroidNotificationAction(
                'REPLY_ACTION_KEY',
                'Quick Reply',
                showsUserInterface: true,
                allowGeneratedReplies: true,
                inputs: [
                  AndroidNotificationActionInput(label: 'Type reply...'),
                ],
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'REPLY_CATEGORY',
          ),
        );

        await _localNotifications.show(
          groupKey.hashCode,
          null,
          null,
          notificationDetails,
          payload: json.encode({...data, 'isReply': 'true'}),
        );
        return;
      }

      await _localNotifications.show(
        message.hashCode,
        data['title'] ?? notification?.title ?? 'Notification',
        data['body'] ?? notification?.body ?? 'You have a new message',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'General Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: json.encode(data),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _replyMessage(
    Map<String, dynamic> message,
    String typedDataFromInput,
  ) async {
    try {
      ChatService.sendChatMessage(
        chatId: message["chatId"],
        message: typedDataFromInput,
      );
      showNotification(
        RemoteMessage(
          data: {
            "type": "chat",
            "chatId": message["chatId"],
            "chatTitle": message["chatTitle"],
            "isReply": "true",
          },
          notification: RemoteNotification(
            title: "You",
            body: typedDataFromInput,
          ),
        ),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _setupMessageHandlers() async {
    try {
      FirebaseMessaging.onMessage.listen(showNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleBackgroundMessage(message.data);
      });
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage.data);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  void _handleBackgroundMessage(Map<String, dynamic> message) async {
    var navigator = navigatorKey.currentState;
    if (navigator == null) return;
    bool isAdmin = await Spdb.isAdminLoggedIn();

    navigator.pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => MainScreen(isAdmin: isAdmin)),
      (route) => false,
    );

    await Future.delayed(const Duration(milliseconds: 200));

    if (message['type'] == 'chat') {
      var uid = await Spdb.getUid();
      var chat = json.decode(message['chat']);
      var chatModel = ChatModel.fromMap(chat["uid"], chat);
      navigator.push(
        CupertinoPageRoute(
          builder: (context) => ChatMessages(
            chat: chatModel,
            currentUser: uid ?? '',
            opponentUid: '',
            onOpenChat: null,
          ),
        ),
      );
      return;
    }

    if (message['type'] == 'eventStarted' ||
        message['type'] == 'eventReminder') {
      final eventId = message['eventId'];
      if (eventId != null && eventId.toString().isNotEmpty) {
        try {
          final event = await EventService.getEvent(uid: eventId.toString());
          navigator.push(
            CupertinoPageRoute(
              builder: (context) => EventViewPage(event: event),
            ),
          );
        } catch (e, st) {
          await ErrorService.recordError(e, st);
        }
      }
      return;
    }

    await showDialog(
      context: navigator.context,
      builder: (context) =>
          ConfirmDialog(content: message.toString(), title: "Notification"),
    );
  }

  Map<String, dynamic> convertPayload(String payload) {
    try {
      return json.decode(payload);
    } catch (_) {
      return {};
    }
  }

  Future<void> clearAvatarCache() async {
    if (kIsWeb) return; // No local cache on web
    await clearAvatarCacheNative();
  }
}

// ─── Firestore helpers (platform-agnostic) ───────────────────────────────────

Future<void> deleteNotification(String uid) async {
  try {
    final FirebaseConfig firebase = FirebaseConfig();
    var cid = await Spdb.getCid();
    await firebase.users
        .doc(cid)
        .collection(Collections.notifications.name)
        .doc(uid)
        .delete();
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    throw e.toString();
  }
}

Future<void> restoreNotification(NotificationModel item) async {
  try {
    final FirebaseConfig firebase = FirebaseConfig();
    final cid = await Spdb.getCid();
    await firebase.users
        .doc(cid)
        .collection(Collections.notifications.name)
        .doc(item.uid)
        .set(item.toMap());
  } catch (e, st) {
    await ErrorService.recordError(e, st);
  }
}

Stream<int> getNotificationCount() async* {
  try {
    final firebase = FirebaseConfig();
    final cid = await Spdb.getCid();
    final uid = await Spdb.getUid();
    yield* firebase.users
        .doc(cid)
        .collection(Collections.notifications.name)
        .where('toUids', arrayContains: uid)
        .where('senderId', isNotEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  } catch (e, st) {
    ErrorService.recordError(e, st);
    rethrow;
  }
}