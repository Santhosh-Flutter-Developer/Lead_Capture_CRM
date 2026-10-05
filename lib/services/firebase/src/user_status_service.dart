import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/models/models.dart';

class UserStatusService {
  /// Realtime Database listeners crash the Windows runner (native C++ SDK
  /// delivers callbacks from a non-platform thread). Presence is skipped on
  /// Windows until the plugin is stable there.
  static bool get _unsupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  // Lazy: don't touch FirebaseDatabase.instance at all on Windows.
  static FirebaseDatabase get _database => FirebaseDatabase.instance;

  static Future<void> setOnline(String uid) async {
    if (uid.isEmpty || _unsupported) return;

    final presenceRef = _database.ref("status/$uid");
    final connectedRef = _database.ref(".info/connected");

    connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        await presenceRef.onDisconnect().set({
          "isOnline": false,
          "lastSeen": ServerValue.timestamp,
        });

        await presenceRef.set({
          "isOnline": true,
          "lastSeen": ServerValue.timestamp,
        });
      }
    });
  }

  static Future<void> setOffline(String uid) async {
    if (uid.isEmpty || _unsupported) return;
    await _database.ref("status/$uid").set({
      "isOnline": false,
      "lastSeen": ServerValue.timestamp,
    });
  }

  static Stream<UserStatusModel?> streamStatus(String uid) {
    if (uid.isEmpty || _unsupported) return const Stream.empty();
    return _database.ref("status/$uid").onValue.map((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final map = Map<String, dynamic>.from(data);
        return UserStatusModel.fromMap(map);
      }
      return null;
    });
  }
}