import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class DealStatusService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createDealStatus({
    required DealStatusModel dealStatus,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var lastOrderNumber = 0;
      var lastDoc = await firebase.users
          .doc(cid)
          .collection(Collections.dealStatus.name)
          .orderBy('orderNumber', descending: true)
          .limit(1)
          .get();

      if (lastDoc.docs.isNotEmpty) {
        lastOrderNumber = lastDoc.docs.first.data()['orderNumber'] ?? 0;
      }

      lastOrderNumber = lastOrderNumber + 1;

      var dealStatusMap = dealStatus.toMap();
      dealStatusMap['orderNumber'] = lastOrderNumber;

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.dealStatus.name}',
        dealStatusMap,
        activity: '${dealStatus.name} has been added as a deal status',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating dealStatus: $e';
    }
  }

  static Future<void> editDealStatus({
    required String uid,
    required DealStatusModel dealStatus,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.dealStatus.name}',
        uid,
        dealStatus.toUpdateMap(),
        activity: '${dealStatus.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating dealStatus: $e';
    }
  }

  static Future<DealStatusModel> getDealStatus({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var dealStatusDoc = await firebase.users
          .doc(cid)
          .collection(Collections.dealStatus.name)
          .doc(uid)
          .get();

      if (dealStatusDoc.exists) {
        var dealStatusData = dealStatusDoc.data();
        if (dealStatusData != null) {
          var dealStatus = DealStatusModel.fromMap(
            dealStatusDoc.id,
            dealStatusData,
          );
          return dealStatus;
        } else {
          throw 'Deal Status data is empty';
        }
      } else {
        throw 'Deal Status not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating dealStatus: $e';
    }
  }

  static Future<List<DealStatusModel>> getAllDealStatus() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.dealStatus.name)
          .orderBy('orderNumber', descending: false)
          .get();

      List<DealStatusModel> dealStatus = querySnapshot.docs.map((doc) {
        return DealStatusModel.fromMap(doc.id, doc.data());
      }).toList();

      return dealStatus;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching dealStatus: $e';
    }
  }

  static Future<void> updateDealStatusReorder({
    required List<DealStatusModel> dealStatusList,
  }) async {
    try {
      var cid = await Spdb.getCid();

      for (var i in dealStatusList) {
        await CommonService.update(
          '${Collections.users.name}/$cid/${Collections.dealStatus.name}',
          i.uid ?? '',
          {'orderNumber': i.orderNumber},
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating dealStatus: $e';
    }
  }

  static Future<bool> isDealStatusAssigned(String statusUid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .where('dealStatus', isEqualTo: statusUid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking deal status assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deleteDealStatus({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.dealStatus.name)
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
        activity: '${data['name'].toString().decrypt} has been deleted',
        description:
            'User has deleted an entry in ${Collections.dealStatus.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.dealStatus.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting deal status: $e\n$st");
      throw 'Error deleting deal status: $e';
    }
  }

  static Future<void> restoreDealStatus(DealStatusModel status) async {
    var cid = await Spdb.getCid();

    final uid = status.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.dealStatus.name)
        .doc(uid)
        .set(status.toMap());
  }
}
