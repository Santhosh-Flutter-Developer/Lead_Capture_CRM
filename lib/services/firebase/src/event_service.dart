import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class EventService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> createEvent({
    required EventModel event,
    String? docId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.events.name}',
        event.toMap(),
        docId: docId,
        activity: '${event.eventName} has been added as a event',
      );

      final users = <String>{
        ...event.eventAttendes,
        event.createdBy.uid,
      }.where((e) => e.isNotEmpty).toList();

      final fcmIds = <String>[];
      for (var i in users) {
        final userFcmIds = await AuthService.getUserFcmIds(uid: i);
        if (userFcmIds.isNotEmpty) {
          fcmIds.addAll(userFcmIds);
        }
      }

      final user = await Spdb.getUser();
      await PostNotificationService.sendNotification(
        model: NotificationModel(
          collectionId: cid ?? '',
          title: 'Event : ${event.eventName}',
          body: 'New event created by ${user.name}',
          toFcms: fcmIds,
          toUids: users,
          senderId: await Spdb.getUid(),
          type: NotificationType.info,
          payload: {},
        ),
      );

      // Create reminders for all attendees
      for (var attendeeId in users) {
        var attendeeFcmIds = await AuthService.getUserFcmIds(uid: attendeeId);
        
        // Set reminder to be sent at event start time
        final reminderTime = event.eventDateTime;
        
        ReminderService.createReminder(
          scheduledAt: reminderTime,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Event Reminder',
            body: 'Event starting now: ${event.eventName} at ${_formatDateTime(event.eventDateTime)}',
            toFcms: attendeeFcmIds,
            toUids: [attendeeId],
            payload: {'eventId': event.uid},
            type: NotificationType.eventReminder,
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating event: $e';
    }
  }

  static Future<void> editEvent({
    required String uid,
    required EventModel event,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.events.name}',
        uid,
        event.toUpdateMap(),
        activity: '${event.eventName} has been updated',
      );

      // Update reminders for all attendees
      final users = <String>{
        ...event.eventAttendes,
        event.createdBy.uid,
      }.where((e) => e.isNotEmpty).toList();

      for (var attendeeId in users) {
        var attendeeFcmIds = await AuthService.getUserFcmIds(uid: attendeeId);
        
        // Set reminder to be sent at event start time
        final reminderTime = event.eventDateTime;
        
        ReminderService.createReminder(
          scheduledAt: reminderTime,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Event Reminder',
            body: 'Event starting now: ${event.eventName} at ${_formatDateTime(event.eventDateTime)}',
            toFcms: attendeeFcmIds,
            toUids: [attendeeId],
            payload: {'eventId': uid},
            type: NotificationType.eventReminder,
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating event: $e';
    }
  }

  static Future<EventModel> getEvent({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var eventDoc = await firebase.users
          .doc(cid)
          .collection(Collections.events.name)
          .doc(uid)
          .get();

      if (eventDoc.exists) {
        var eventData = eventDoc.data();
        if (eventData != null) {
          var event = EventModel.fromMap(eventDoc.id, eventData);
          return event;
        } else {
          throw 'Event data is empty';
        }
      } else {
        throw 'Event not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating event: $e';
    }
  }

  static Future<List<EventModel>> getAllEvents() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.events.name)
          .get();

      List<EventModel> events = querySnapshot.docs.map((doc) {
        return EventModel.fromMap(doc.id, doc.data());
      }).toList();

      events.sort((a, b) => a.eventName.compareTo(b.eventName));

      return events;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching events: $e';
    }
  }

  static Future<bool> isEventAssigned(String uid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .where('event', isEqualTo: uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking event assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deleteEvent({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.events.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['eventName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.events.name}',
        collection: '${Collections.users.name}/$cid/${Collections.events.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting event: $e\n$st");
      throw 'Error deleting event: $e';
    }
  }
}
