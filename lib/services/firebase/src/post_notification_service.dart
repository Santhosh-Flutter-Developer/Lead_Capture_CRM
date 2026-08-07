import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class PostNotificationService {
  static FirebaseConfig firebase = FirebaseConfig();

  static Future<String?> _getAccessToken() async {
    try {
      final tokenDoc = await firebase.system.doc('serviceToken').get();

      if (tokenDoc.exists) {
        final data = tokenDoc.data()!;
        final expiry = DateTime.fromMillisecondsSinceEpoch(data['expiry']);
        if (DateTime.now().isBefore(
          expiry.subtract(const Duration(minutes: 5)),
        )) {
          debugPrint("Using cached token from Firestore");
          return data['token'];
        }
      }

      var serviceAccountDoc = await firebase.system.doc('serviceAccount').get();
      if (!serviceAccountDoc.exists || serviceAccountDoc.data() == null) {
        debugPrint("Service account document not found or empty");
        return null;
      }
      var serviceAccount = serviceAccountDoc.data()!['account'];

      // otherwise generate new one
      final serviceAccountJson = json.decode(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final credentials = auth.ServiceAccountCredentials.fromJson(
        serviceAccountJson,
      );
      final client = await auth.clientViaServiceAccount(credentials, scopes);

      final newToken = client.credentials.accessToken.data;
      final expiry = client.credentials.accessToken.expiry;
      client.close();

      await firebase.system.doc('serviceToken').set({
        'token': newToken,
        'expiry': expiry.millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint("New token generated and saved");
      return newToken;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Token error: $e\n$st");
      return null;
    }
  }

  static Future<void> sendNotification({
    required NotificationModel model,
  }) async {
    try {
      final String? serverKey = await _getAccessToken();

      // Try to send push notification if server key is available
      if (serverKey != null && model.toFcms.isNotEmpty) {
        String endpointFirebaseCloudMessaging =
            "https://fcm.googleapis.com/v1/projects/leadcapture-79a43/messages:send";

        for (var element in model.toFcms) {
          // IMPORTANT: This is intentionally a DATA-ONLY message (no
          // top-level "notification" block).
          //
          // Why: if a "notification" block is present, Android (and iOS)
          // auto-display the notification from the system tray the instant
          // it's received while the app is backgrounded/killed — BEFORE our
          // background handler even runs. Our background handler then also
          // calls showNotification() via flutter_local_notifications,
          // producing a SECOND notification. That's why duplicates only
          // showed up when the app wasn't in the foreground.
          //
          // With a data-only message, Android never auto-displays anything;
          // our app (foreground onMessage listener OR background handler)
          // is the single place that ever calls showNotification(), so
          // exactly one notification is shown regardless of app state.
          final Map<String, dynamic> message = {
            "message": {
              "android": {
                "priority": "high",
              },
              "apns": {
                "headers": {
                  "apns-priority": "10",
                  // Required so iOS wakes the app to run the background
                  // handler for data-only messages.
                  "apns-push-type": "background",
                },
                "payload": {
                  "aps": {"content-available": 1},
                },
              },
              "token": element,
              "data": {
                // Ensure title/body are always available in `data`, since
                // showNotification() reads data['title'] / data['body'].
                "title": model.title,
                "body": model.body,
                ...model.payload.map(
                  (key, value) => MapEntry(key, value.toString()),
                ),
              },
            },
          };

          try {
            final http.Response response = await http.post(
              Uri.parse(endpointFirebaseCloudMessaging),
              headers: {
                'Authorization': 'Bearer $serverKey',
                'Content-Type': 'application/json',
              },
              body: json.encode(message),
            );

            if (response.statusCode == 200) {
              debugPrint(response.body);
            } else {
              debugPrint(
                "Push notification failed for token $element: "
                "status=${response.statusCode}, body=${response.body}",
              );
            }
          } catch (e) {
            debugPrint("Push notification failed for token $element: $e");
            // Continue with other tokens even if one fails
          }
        }
      } else if (serverKey == null) {
        debugPrint(
          "Push notification skipped: server key not available (service account missing)",
        );
      }

      // Always store notification in database
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.notifications.name}',
        model.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }
}
