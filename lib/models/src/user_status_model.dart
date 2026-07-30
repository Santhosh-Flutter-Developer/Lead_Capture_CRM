import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatusModel {
  final bool isOnline;
  final DateTime? lastSeen;

  UserStatusModel({required this.isOnline, this.lastSeen});

  factory UserStatusModel.fromMap(Map<String, dynamic> map) {
    return UserStatusModel(
      isOnline: map["isOnline"] ?? false,
      lastSeen: map["lastSeen"] != null
          ? (map["lastSeen"] as Timestamp).toDate()
          : null,
    );
  }
}
