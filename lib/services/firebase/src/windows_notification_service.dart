import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import '/services/services.dart';
import '/app/app.dart';
import '/constants/constants.dart';
import '/views/views.dart';

final AudioPlayer _player = AudioPlayer();

class FirestoreNotificationListener {
  static final FirebaseConfig firebase = FirebaseConfig();
  static final Set<String> _shownIds = {};
  static StreamSubscription? _subscription;

  static Future<void> listenForNotifications() async {
    // Cancel any existing listener before starting a new one
    await _subscription?.cancel();
    _subscription = null;

    var cid = await Spdb.getCid();
    var uid = await Spdb.getUid();

    if (uid != null && cid != null) {
      _subscription = firebase.users
          .doc(cid)
          .collection(Collections.notifications.name)
          .where('toUids', arrayContains: uid.trim())
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((querySnapshot) {
            for (var change in querySnapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                var data = change.doc.data();

                DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
                  data?['createdAt'],
                );

                if (DateTime.now().difference(createdAt).inSeconds < 60) {
                  String docId = change.doc.id;

                  if (_shownIds.contains(docId)) continue;
                  _shownIds.add(docId);

                  String title = data?['title'] ?? 'New Notification';
                  String message =
                      data?['body'] ??
                      data?['message'] ??
                      'You have a new message';

                  LocalNotification notification = LocalNotification(
                    title: title,
                    body: message,
                  );

                  notification.onClick = () async {
                    await windowManager.focus();
                    await windowManager.show();

                    var navigator = navigatorKey.currentState;
                    if (navigator == null) return;
                    bool isAdmin = await Spdb.isAdminLoggedIn();

                    navigator.pushAndRemoveUntil(
                      CupertinoPageRoute(
                        builder: (_) => MainScreen(isAdmin: isAdmin),
                      ),
                      (route) => false,
                    );
                  };
                  notification.show();
                  _playSound();
                }
              }
            }
          });
    }
  }

  static void _playSound() async {
    await _player.play(AssetSource('audio/notify.mp3'), volume: 1.0);
  }

  static Future<void> sendTestNotification() async {
    try {
      LocalNotification notification = LocalNotification(
        title: "Test Notification",
        body: "This is a test notification.",
      );

      notification.onClick = () async {
        await windowManager.focus();
        await windowManager.show();

        var navigator = navigatorKey.currentState;
        if (navigator == null) return;
        bool isAdmin = await Spdb.isAdminLoggedIn();

        navigator.pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => MainScreen(isAdmin: isAdmin)),
          (route) => false,
        );
      };

      notification.show();
    } catch (e) {
      throw 'Error sending test notification: $e';
    }
  }
}
