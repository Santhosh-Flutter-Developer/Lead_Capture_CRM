import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// import 'package:mime/mime.dart';
// import 'package:path/path.dart' as path;
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class ChatService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static final ValueNotifier<int> _unviewedCount = ValueNotifier<int>(0);

  static Stream<List<MessagesModel>> getChatMessagesStream({
    required String uid,
  }) async* {
    var cid = await Spdb.getCid();
    var userid = await Spdb.getUid();
    yield* firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(uid)
        .collection(Collections.messages.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                var data = doc.data();
                data['uid'] = doc.id;

                final message = MessagesModel.fromMap(doc.id, data);

                if (userid != null && message.deletedFor.contains(userid)) {
                  return null;
                }

                return message;
              })
              .whereType<MessagesModel>()
              .toList();
        });
  }

  static Future<List<MessagesModel>> getChatMessages({
    required String uid,
  }) async {
    var cid = await Spdb.getCid();
    var userid = await Spdb.getUid();

    final snapshot = await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(uid)
        .collection(Collections.messages.name)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;

          final message = MessagesModel.fromMap(doc.id, data);

          if (userid != null && message.deletedFor.contains(userid)) {
            return null;
          }

          return message;
        })
        .whereType<MessagesModel>()
        .toList();
  }

  static Future<List<MessagesModel>> searchMessages({
    required String chatId,
    required String searchTerm,
  }) async {
    var cid = await Spdb.getCid();

    return await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .collection(Collections.messages.name)
        .where('searchKeywords', arrayContains: searchTerm.toLowerCase())
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            var data = doc.data();
            data['uid'] = doc.id;
            return MessagesModel.fromMap(doc.id, data);
          }).toList();
        })
        .first;
  }

  static Future<void> updateSeenChat({
    required String chatId,
    required String messageId,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}/$chatId/${Collections.messages.name}',
        messageId,
        {
          'seenBy': FieldValue.arrayUnion([uid]),
        },
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw "Error updating seen status: $e";
    }
  }

  static Future<void> updateTypingOnChat({
    required String chatId,
    required bool status,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      var mapDoc = {
        'typing': {'status': status, 'userId': uid},
      };

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        chatId,
        mapDoc,
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw "Error updating seen status: $e";
    }
  }

  static Future<MessagesModel> getChatMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .collection(Collections.messages.name)
          .doc(messageId)
          .get(const GetOptions(source: Source.serverAndCache));
      var data = doc.data();
      data!['uid'] = doc.id;
      return MessagesModel.fromMap(doc.id, data);
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<MessagesModel?> deleteChatMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      final messageRef = firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .collection(Collections.messages.name)
          .doc(messageId);

      final doc = await messageRef.get(
        const GetOptions(source: Source.serverAndCache),
      );

      if (!doc.exists) return null;

      final data = doc.data()!;
      final message = MessagesModel.fromMap(doc.id, data);

      // ✅ STEP 1: mark message as deleted for user
      await messageRef.update({
        "deletedFor": FieldValue.arrayUnion([uid]),
      });

      // ✅ STEP 2: check if this is LAST MESSAGE
      final chatRef = firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId);

      final chatDoc = await chatRef.get();
      final chatData = chatDoc.data();

      final lastMessage = chatData?['lastMessage'];

      if (lastMessage != null && lastMessage['messageId'] == messageId) {
        // ✅ STEP 3: find next valid message
        final messagesSnapshot = await firebase.users
            .doc(cid)
            .collection(Collections.chats.name)
            .doc(chatId)
            .collection(Collections.messages.name)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        MessagesModel? newLast;

        for (var doc in messagesSnapshot.docs) {
          final data = doc.data();
          final msg = MessagesModel.fromMap(doc.id, data);

          if (!msg.deletedFor.contains(uid)) {
            newLast = msg;
            break;
          }
        }

        // ✅ STEP 4: update lastMessage
        await chatRef.update({
          "lastMessage": newLast != null
              ? LastMessageModel(
                  messageId: newLast.uid,
                  message: newLast.message,
                  senderId: newLast.senderId,
                  timestamp: newLast.timestamp,
                ).toMap()
              : null,
        });
      }

      return message;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> editChatMessage({
    required String uid,
    required String message,
    required String chatId,
    List<FileModel>? attachments,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var userId = await Spdb.getUid();

      List<String> receivers = [];
      var chatDoc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(uid)
          .get();

      if (chatDoc.exists) {
        var participants = chatDoc.data()?['participants'];
        if (participants != null) {
          receivers = List<String>.from(participants);
          receivers.remove(userId);
        }
      }

      MessagesModel chat = MessagesModel(
        chatId: chatId,
        senderId: userId ?? '',
        receiverId: receivers,
        message: message,
        attachments: attachments ?? [],
        edited: true,
        editHistory: [MessagesEditHistory(message: message)],
      );

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}/$uid/${Collections.messages.name}',
        chatId,
        chat.toEditMap(),
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<void> sendChatMessage({
    required String chatId,
    required String message,
    List<FileModel>? attachments,
    String? replyFor,
    List<MentionModel>? mentions,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var senderId = await Spdb.getUid();

      var chatDoc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .get();

      List<String> receivers = [];
      if (chatDoc.exists) {
        receivers = List<String>.from(chatDoc.data()?['participants'] ?? []);
        receivers.remove(senderId);
      }

      final files = attachments ?? [];

      String lastMsg = message;

      if (files.isNotEmpty && message.trim().isEmpty) {
        final mime = files.first.mimeType;

        if (mime.startsWith('image')) {
          lastMsg = "📷 Photo";
        } else if (mime.startsWith('video')) {
          lastMsg = "🎥 Video";
        } else if (mime.startsWith('audio')) {
          lastMsg = "🎵 Audio";
        } else {
          lastMsg = "📄 Document";
        }
      }

      MessagesModel chat = MessagesModel(
        chatId: chatId,
        senderId: senderId!,
        receiverId: receivers,
        message: message,
        replyFor: replyFor,
        attachments: attachments ?? [],
        mentions: mentions ?? [],
      );

      final docRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.chats.name}/$chatId/${Collections.messages.name}',
        chat.toMap(),
      );

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        chatId,
        {
          "lastMessage": LastMessageModel(
            messageId: docRef.id,
            message: lastMsg,
            senderId: senderId,
            timestamp: DateTime.now(),
          ).toMap(),
          "deletedFor": [],
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw "Error sending chat message: $e";
    }
  }

  static ValueListenable<int> unviewedCount() {
    _startListening();
    return _unviewedCount;
  }

  static void _startListening() async {
    var uid = await Spdb.getUid();
    var cid = await Spdb.getCid();

    FirebaseFirestore.instance
        .collectionGroup(Collections.messages.name)
        .where('receiverId', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
          int totalUnviewed = 0;

          for (var doc in snapshot.docs) {
            if (doc.reference.path.contains("users/$cid/")) {
              List seenBy = doc.data()['seenBy'] ?? [];
              if (!seenBy.contains(uid)) {
                totalUnviewed++;
              }
            }
          }
          _unviewedCount.value = totalUnviewed;
        });
  }

  static Future<void> sendNotification({
    required String chatId,
    required String message,
    bool? isChat,
    String? messageId,
  }) async {
    try {
      var user = await Spdb.getUser();
      var name = user.name;
      var userId = user.uid;
      var chat = await _getChat(uid: chatId);

      List<String> toFcms = [];
      List<String> receivers = [];

      receivers.addAll(chat.participants);
      receivers.removeWhere((uid) => uid == userId);

      for (var receiverId in receivers) {
        var fcmIds = await AuthService.getUserFcmIds(uid: receiverId);
        toFcms.addAll(fcmIds);
      }

      NotificationModel notification = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: chat.isGroupChat ? (chat.title ?? 'Group Chat') : name,
        body: chat.isGroupChat ? '$name: $message' : message,
        toUids: receivers,
        toFcms: toFcms,
        senderId: await Spdb.getUid(),
        type: NotificationType.chat,
        payload: (isChat ?? false)
            ? {
                "type": "chat",
                "chatId": chat.uid,
                "chat": json.encode(chat.toMap()),
                "chatTitle": chat.isGroupChat ? (chat.title ?? 'Group Chat') : name,
                "senderImageUrl": user.profilePic,
              }
            : {},
      );

      PostNotificationService.sendNotification(model: notification);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<ChatModel> _getChat({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(uid)
          .get();
      return ChatModel.fromMap(doc.id, doc.data()!);
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<List<ChatModel>> getChatGroups() async {
    try {
      var cid = await Spdb.getCid();

      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .where('isGroupChat', isEqualTo: true)
          .get();

      List<ChatModel> result = [];

      for (var i in doc.docs) {
        result.add(ChatModel.fromMap(i.id, i.data()));
      }

      return result;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<String?> createGroupChat({required ChatModel model}) async {
    try {
      var cid = await Spdb.getCid();

      var doc = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        model.toMap(),
        activity: '${model.title} has been added as a group chat',
      );

      sendNotification(
        chatId: doc.id,
        message: "Created group chat",
        isChat: true,
      );

      return doc.id;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<String> createIndividualChat({required String userId}) async {
    try {
      final cid = await Spdb.getCid();
      final currentUid = await Spdb.getUid();

      if (currentUid == null || currentUid.isEmpty || userId.isEmpty) {
        throw 'Something went wrong. Please try again later.';
      }

      final participantsKey = ([currentUid, userId]..sort()).join('_');

      final existingChatSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .where('participantsKey', isEqualTo: participantsKey)
          .where('isGroupChat', isEqualTo: false)
          .limit(1)
          .get();

      // If chat already exists → return it
      if (existingChatSnapshot.docs.isNotEmpty) {
        return existingChatSnapshot.docs.first.id;
      }

      // Create chat ONLY if not exists
      final chatModel = ChatModel(
        createdBy: currentUid,
        participants: [currentUid, userId],
        participantsKey: participantsKey,
        createdAt: DateTime.now(),
        lastMessage: null,
        isGroupChat: false,
        isPinned: false,
        isFavorite: false,
      );

      final chatDoc = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        chatModel.toMap(),
      );

      debugPrint("the chat id on servuce id ${chatDoc.id}");

      await sendNotification(
        chatId: chatDoc.id,
        message: "Started chat",
        isChat: true,
      );

      return chatDoc.id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e\n$st");
      throw "Failed to create chat: $e";
    }
  }

  static Stream<int> unviewedChatMessageCount(String chatId) async* {
    var userId = await Spdb.getUid();
    var cid = await Spdb.getCid();

    yield* FirebaseFirestore.instance
        .collectionGroup(Collections.messages.name)
        .where('receiverId', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int totalUnviewed = 0;

          for (var doc in snapshot.docs) {
            if (doc.reference.path.contains("users/$cid/chats/$chatId")) {
              List seenBy = doc.data()['seenBy'] ?? [];
              if (!seenBy.contains(userId)) {
                totalUnviewed++;
              }
            }
          }
          return totalUnviewed;
        });
  }

  static Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    var cid = await Spdb.getCid();
    final ref = FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .collection(Collections.messages.name)
        .doc(messageId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final reactions = Map<String, dynamic>.from(data["reactions"] ?? {});
    final List<dynamic> users = List.from(reactions[emoji] ?? []);
    if (users.contains(userId)) {
      users.remove(userId);
    } else {
      users.add(userId);
    }
    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }
    await ref.update({"reactions": reactions});
  }

  static Future<void> togglePin({
    required String chatId,
    required String messageId,
    required bool value,
  }) async {
    var cid = await Spdb.getCid();
    final ref = FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .collection(Collections.messages.name)
        .doc(messageId);

    await ref.update({'isPinned': value});
  }

  static Future<void> toggleChatPin({
    required String chatId,
    required bool value,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .update({'isPinnedBy.$uid': value, 'updatedAt': DateTime.now()});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> deleteChat({required String chatId}) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      final chatRef = FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId);

      final chatSnap = await chatRef.get();

      if (!chatSnap.exists) return;

      final data = chatSnap.data() as Map<String, dynamic>;

      final createdBy = data['createdBy'];
      final isGroupChat = data['isGroupChat'] ?? false;
      if (isGroupChat && createdBy != uid) {
        throw "Only group creator can delete this chat";
      }

      await chatRef.update({
        'deletedFor': FieldValue.arrayUnion([uid]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // await TrashService.moveToTrash(
      //   docRef: chatRef,
      //   docData: data,
      //   reason: 'chat_deleted',
      // );
      // final messagesRef = chatRef.collection(Collections.messages.name);

      // final messagesSnapshot = await messagesRef.get();
      // final batch = FirebaseFirestore.instance.batch();

      // for (final doc in messagesSnapshot.docs) {
      //   batch.delete(doc.reference);
      // }

      // batch.delete(chatRef);

      // await batch.commit();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> restoreChat(ChatModel chat) async {
    var cid = await Spdb.getCid();

    if (chat.uid == null || chat.uid!.isEmpty) {
      throw Exception("Chat UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chat.uid) 
        .set(chat.toMap());
  }

  static Future<void> toggleChatFavorite({
    required String chatId,
    required bool value,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .update({'isFavoriteBy.$uid': value, 'updatedAt': DateTime.now()});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> forwardMessage({
    required String fromChatId,
    required String messageId,
    required String targetChatId,
    required String currentUser,
  }) async {
    var cid = await Spdb.getCid();

    final msgRef = FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(fromChatId)
        .collection(Collections.messages.name)
        .doc(messageId);

    final snap = await msgRef.get();
    if (!snap.exists) return;

    final msg = snap.data()!;

    await FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(targetChatId)
        .collection(Collections.messages.name)
        .add({
          'text': msg['text'],
          'senderId': currentUser,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'reactions': {},
          'isPinned': false,
          'forwardedFrom': fromChatId,
        });
  }

  static Future<String?> getChatUid(String opponentUserId) async {
    var cid = await Spdb.getCid();
    var currentUserId = await Spdb.getUid();

    if (currentUserId == opponentUserId) return null;

    final key = ([currentUserId, opponentUserId]..sort()).join('_');

    var chat = await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .where('participantsKey', isEqualTo: key)
        .where('isGroupChat', isEqualTo: false)
        .limit(1)
        .get();

    if (chat.docs.isNotEmpty) {
      return chat.docs.first.id;
    }

    var chatId = await createIndividualChat(userId: opponentUserId);
    return chatId;
  }

  static Future<void> updateGroupChat({
    required String chatId,
    required String title,
    String? description,
    required List<String> participantIds,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      if (cid == null || uid == null) {
        throw 'Invalid session';
      }

      final participantsKey = (participantIds..sort()).join('_');

      await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .update({
            'title': title,
            'description': description,
            'participants': participantIds,
            'participantsKey': participantsKey,
            'updatedAt': DateTime.now(),
            'lastMessage': LastMessageModel(
              message: 'Group details updated',
              senderId: uid,
              timestamp: DateTime.now(),
            ).toMap(),
          });
    } catch (e, st) {
      debugPrint('updateGroupChat error: $e\n$st');
      await ErrorService.recordError(e, st);
      throw 'Failed to update group chat';
    }
  }
}
      