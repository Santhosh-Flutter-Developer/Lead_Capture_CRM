import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/services/services.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String? _apnsToken;
  String? _fcmToken;
  String? _error;
  bool _loading = false;
  AuthorizationStatus? _authStatus;

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Check current permission
      NotificationSettings currentSettings = await messaging
          .getNotificationSettings();
      _authStatus = currentSettings.authorizationStatus;

      // Request permission if not determined or denied
      if (_authStatus == AuthorizationStatus.notDetermined ||
          _authStatus == AuthorizationStatus.denied) {
        NotificationSettings newSettings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _authStatus = newSettings.authorizationStatus;
      }

      if (_authStatus == AuthorizationStatus.denied) {
        setState(() {
          _error = kIsWeb
              ? '❌ Notifications are blocked for this site in your browser. '
                    'Click the padlock icon next to the address bar → Site '
                    'settings → Notifications → Allow, then refresh this page.'
              : '❌ Notification permission denied by user.';
          _loading = false;
        });
        return;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Get APNs token (for iOS only)
      String? apns;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        apns = await messaging.getAPNSToken();
      }

      // Get FCM token (web requires the VAPID key)
      String? fcm = await messaging.getToken(
        vapidKey: kIsWeb ? kVapidKey : null,
      );

      if (fcm == null) {
        setState(() {
          _error = '⚠️ Failed to retrieve FCM token.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _apnsToken = apns;
        _fcmToken = fcm;
        _loading = false;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
      await ErrorService.recordError(e, st);
    }
  }

  void _copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    FlushBar.show(context, 'Token copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: Back(), title: Text('Notification Test Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const WaitingLoading()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔹 FCM Token:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      )
                    else if (_fcmToken != null)
                      SelectableText(
                        _fcmToken!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.black87,
                        ),
                      )
                    else
                      Text(
                        'No FCM token retrieved yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _fcmToken != null
                          ? () => _copyToken(_fcmToken!)
                          : null,
                      icon: const Icon(Icons.copy),
                      label: Text(
                        'Copy FCM Token',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      '🔸 APNs Token (iOS only):',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_apnsToken != null)
                      SelectableText(
                        _apnsToken!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.black87,
                        ),
                      )
                    else
                      Text(
                        'No APNs token retrieved.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _apnsToken != null
                          ? () => _copyToken(_apnsToken!)
                          : null,
                      icon: const Icon(Icons.copy),
                      label: Text(
                        'Copy APNs Token',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _initFirebaseMessaging,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Refresh Tokens',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_authStatus != null)
                      Text(
                        'Permission Status: ${_authStatus.toString().split('.').last}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.blueGrey,
                        ),
                      ),
                    const SizedBox(height: 30),
                    Text(
                      'Tips:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      kIsWeb
                          ? '• FCM token is used to send notifications via Firebase.\n'
                                '• Web push requires the browser notification permission '
                                'to be Allowed for this site.\n'
                                '• If tokens are empty, check the padlock icon → Site '
                                'settings → Notifications, then refresh.'
                          : '• FCM token is used to send notifications via Firebase.\n'
                                '• APNs token is managed internally by Firebase for iOS.\n'
                                '• If tokens are empty, reinstall app or restart device.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.black54),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
