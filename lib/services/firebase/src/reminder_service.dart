import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';
import '/services/services.dart';

class ReminderService {
  static void createReminder({
    required DateTime scheduledAt,
    required NotificationModel notification,
    String? docId,
  }) async {
    ReminderModel reminderModel = ReminderModel(
      notification: notification,
      scheduledAt: scheduledAt,
      isSent: false,
      createdAt: DateTime.now(),
      createdBy: await Spdb.getUser(),
    );
    var firestore = FirebaseFirestore.instance;

    if (docId != null && docId.isNotEmpty) {
      // Deterministic ID so re-creating/editing the same event+recipient+
      // reminder-type overwrites the existing pending reminder instead of
      // stacking a duplicate doc (which previously caused duplicate
      // "Event Started" pushes).
      await firestore.collection('reminders').doc(docId).set(
            reminderModel.toMap(),
          );
    } else {
      await firestore.collection('reminders').add(reminderModel.toMap());
    }
  }
}