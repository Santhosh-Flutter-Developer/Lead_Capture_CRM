import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class EventService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Recipients depend on who created the event:
  ///   • Admin creates the event  → every admin AND every employee gets
  ///     notified (an admin's event is company-wide).
  ///   • Employee creates the event → only that employee + every admin
  ///     get notified (other employees are not involved).
  /// Built from a Set, so the creator never receives a duplicate entry
  /// if they also happen to land in the admin/employee list.
  static Future<List<String>> _getNotificationRecipients({
    required String createdByUid,
    required UserType createdByUserType,
  }) async {
    final admins = await AdminService.getAllAdmins();
    final recipients = <String>{
      createdByUid,
      ...admins.map((a) => a.uid ?? ''),
    };

    if (createdByUserType == UserType.admin) {
      final employees = await EmployeeService.getAllEmployees();
      recipients.addAll(employees.map((e) => e.uid ?? ''));
    }

    recipients.removeWhere((e) => e.isEmpty);

    return recipients.toList();
  }

  static Future<void> createEvent({
    required EventModel event,
    String? docId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      // event.uid is never populated by callers (e.g. event_create.dart
      // constructs EventModel without a uid) — it was `null` this whole
      // time. That meant every reminder docId below collapsed to the
      // literal string "null_<attendeeId>_started" / "..._before15" for
      // EVERY event, so reminders from different events for the same
      // recipient overwrote each other in Firestore before they could
      // fire. Capture the real generated/used doc id here instead.
      final eventDocRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.events.name}',
        event.toMap(),
        docId: docId,
        activity: '${event.eventName} has been added as a event',
      );
      final eventUid = eventDocRef.id;

      final users = await _getNotificationRecipients(
        createdByUid: event.createdBy.uid,
        createdByUserType: event.createdBy.userType,
      );

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
          payload: {'eventId': eventUid},
        ),
      );

      // Create reminders for the same recipients as above:
      //   1) 15 minutes before the event starts
      //   2) at the moment the event starts
      for (var attendeeId in users) {
        var attendeeFcmIds = await AuthService.getUserFcmIds(uid: attendeeId);

        final fifteenMinBefore = event.eventDateTime.subtract(
          const Duration(minutes: 15),
        );

        // Only schedule the 15-min-before reminder if that time hasn't
        // already passed (e.g. event created less than 15 min out).
        if (fifteenMinBefore.isAfter(DateTime.now())) {
          ReminderService.createReminder(
            docId: '${eventUid}_${attendeeId}_before15',
            scheduledAt: fifteenMinBefore,
            notification: NotificationModel(
              collectionId: cid ?? '',
              title: 'Event Reminder',
              body:
                  '${event.eventName} starts in 15 minutes at ${_formatDateTime(event.eventDateTime)}',
              toFcms: attendeeFcmIds,
              toUids: [attendeeId],
              payload: {'eventId': eventUid},
              type: NotificationType.eventReminder,
            ),
          );
        }

        ReminderService.createReminder(
          docId: '${eventUid}_${attendeeId}_started',
          scheduledAt: event.eventDateTime,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Event Started',
            body: 'Event starting now: ${event.eventName} at ${_formatDateTime(event.eventDateTime)}',
            toFcms: attendeeFcmIds,
            toUids: [attendeeId],
            payload: {'eventId': eventUid},
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

      // Update reminders — recipients depend on whether the creator is an
      // admin (company-wide) or an employee (creator + admins only)
      final users = await _getNotificationRecipients(
        createdByUid: event.createdBy.uid,
        createdByUserType: event.createdBy.userType,
      );

      for (var attendeeId in users) {
        var attendeeFcmIds = await AuthService.getUserFcmIds(uid: attendeeId);

        final fifteenMinBefore = event.eventDateTime.subtract(
          const Duration(minutes: 15),
        );

        if (fifteenMinBefore.isAfter(DateTime.now())) {
          ReminderService.createReminder(
            docId: '${uid}_${attendeeId}_before15',
            scheduledAt: fifteenMinBefore,
            notification: NotificationModel(
              collectionId: cid ?? '',
              title: 'Event Reminder',
              body:
                  '${event.eventName} starts in 15 minutes at ${_formatDateTime(event.eventDateTime)}',
              toFcms: attendeeFcmIds,
              toUids: [attendeeId],
              payload: {'eventId': uid},
              type: NotificationType.eventReminder,
            ),
          );
        }

        ReminderService.createReminder(
          docId: '${uid}_${attendeeId}_started',
          scheduledAt: event.eventDateTime,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Event Started',
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