import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class TicketService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createTicket({
    required CustomerTicketModel ticket,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      if (!ticket.createdBy.contains(uid)) {
        ticket.createdBy.add(uid!);
      }

      final userDoc = firebase.users.doc(cid);
      final ticketsRef = userDoc.collection(Collections.customerTickets.name);

      // Generate ticket number if not provided
      int ticketNumber = ticket.ticketNumber ?? 1;
      var lastTicketSnapshot = await ticketsRef
          .orderBy('ticketNumber', descending: true)
          .limit(1)
          .get();
      if (lastTicketSnapshot.docs.isNotEmpty) {
        ticketNumber =
            (lastTicketSnapshot.docs.first.data()['ticketNumber'] ?? 0) + 1;
      }

      var ticketData = ticket.toMap();
      ticketData['ticketNumber'] = ticketNumber;

      var ticketDoc = await ticketsRef.add(ticketData);

      // Ticket History
      TicketHistoryModel ticketHistoryModel = TicketHistoryModel(
        userId: uid ?? '',
        updateDisposition: 'Ticket Created',
      );

      await ticketDoc
          .collection(Collections.ticketHistory.name)
          .add(ticketHistoryModel.toMap());

      // Collect Users
      List<String> users = [
        ...ticket.assignTo,
        ...ticket.participants,
        ...ticket.createdBy,
        ...ticket.observers,
      ];

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Ticket : ${ticket.ticketTitle}',
        body: 'New ticket created by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.ticket,
        payload: {'ticketId': ticketDoc.id},
      );

      PostNotificationService.sendNotification(model: notif);

      if (ticket.reminder != null) {
        ReminderService.createReminder(
          scheduledAt: ticket.reminder!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Ticket Reminder',
            body: 'Ticket "${ticket.ticketTitle}" reminder',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.ticket,
            payload: {'ticketId': ticketDoc.id},
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error creating ticket: $e';
    }
  }

  static Future<void> updateTicket({
    required String uid,
    required CustomerTicketModel ticket,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var userId = await Spdb.getUid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.customerTickets.name}',
        uid,
        ticket.toUpdateMap(),
        activity: '${ticket.ticketTitle} has been updated',
      );

      TicketHistoryModel ticketHistoryModel = TicketHistoryModel(
        userId: userId ?? '',
        updateDisposition: 'Ticket Updated',
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid)
          .collection(Collections.ticketHistory.name)
          .add(ticketHistoryModel.toMap());

      List<String> users = [
        ...ticket.assignTo,
        ...ticket.participants,
        ...ticket.createdBy,
        ...ticket.observers,
      ];

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Ticket : ${ticket.ticketTitle}',
        body: 'Ticket has updated by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.ticket,
        payload: {'ticketId': uid},
      );

      PostNotificationService.sendNotification(model: notif);

      if (ticket.reminder != null) {
        ReminderService.createReminder(
          scheduledAt: ticket.reminder!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Ticket Reminder',
            body: 'Ticket "${ticket.ticketTitle}" reminder',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.ticket,
            payload: {'ticketId': uid},
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Error updating ticket: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error updating ticket: $e';
    }
  }

  // Delete ticket
  static Future<void> deleteTicket({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['ticketTitle'] ?? 'N/A'} has been deleted',
        description:
            'User has deleted an entry in ${Collections.customerTickets.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.customerTickets.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting ticket: $e';
    }
  }

  static Future<void> restoreTicket(CustomerTicketModel ticket) async {
    try {
      final FirebaseConfig firebase = FirebaseConfig();
      final cid = await Spdb.getCid();

      await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticket.uid)
          .set(ticket.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // Get a single ticket
  static Future<CustomerTicketModel> getTicket({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid)
          .get();

      if (!doc.exists) throw 'Ticket not found';
      return CustomerTicketModel.fromMap(doc.id, doc.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching ticket: $e';
    }
  }

  // Get all tickets
  static Future<List<CustomerTicketModel>> getAllTickets() async {
    try {
      var cid = await Spdb.getCid();
      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .get();

      return snapshot.docs
          .map((doc) => CustomerTicketModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching tickets: $e';
    }
  }

  static Stream<List<TicketHistoryModel>> streamTicketHistory({
    required String cid,
    required String ticketId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .doc(ticketId)
        .collection(Collections.ticketHistory.name)
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TicketHistoryModel.fromMap(d.data()))
              .toList(),
        )
        .asBroadcastStream(); // allows multiple listeners
  }

  static Stream<List<TicketCommentModel>> streamComments({
    required String cid,
    required String ticketId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .doc(ticketId)
        .collection(Collections.ticketComments.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TicketCommentModel.fromMap(d.data()))
              .toList(),
        )
        .asBroadcastStream(); // allows multiple listeners
  }

  static Future<List<TicketHistoryModel>> getTicketHistory({
    required String ticketId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId)
          .collection(Collections.ticketHistory.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((d) => TicketHistoryModel.fromMap(d.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting ticket history: $e';
    }
  }

  static Future<List<TicketCommentModel>> getComments({
    required String ticketId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId)
          .collection(Collections.ticketComments.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((d) => TicketCommentModel.fromMap(d.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting comments: $e';
    }
  }

  static Future<void> addComment({
    required String ticketId,
    required String comment,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      TicketCommentModel commentModel = TicketCommentModel(
        userId: uid ?? '',
        comment: comment,
        timestamp: DateTime.now(),
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId)
          .collection(Collections.ticketComments.name)
          .add(commentModel.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error adding comment: $e';
    }
  }
}
