import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class DealService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> createDeal({required DealModel deal}) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();
      // Ensure the creator is in workflow
      if (uid != null && !deal.workFlow.contains(uid)) {
        deal.workFlow.add(uid);
      }

      // Save deal to Firestore
      final userDoc = firebase.users.doc(cid);
      final dealsRef = userDoc.collection(Collections.deals.name);

      // Generate deal number if not provided
      int dealNumber = deal.dealNumber ?? 1;
      var lastDealSnapshot = await dealsRef
          .orderBy('dealNumber', descending: true)
          .limit(1)
          .get();
      if (lastDealSnapshot.docs.isNotEmpty) {
        dealNumber =
            (lastDealSnapshot.docs.first.data()['dealNumber'] ?? 0) + 1;
      }

      var dealData = deal.toMap();
      dealData['dealNumber'] = dealNumber;
      dealData.remove('uid');
      var dealDoc = await dealsRef.add(dealData);

      await addDealHistory(dealUid: dealDoc.id, action: 'Deal Created');

      // Collect workflow users for notifications
      List<String> users = deal.workFlow.toSet().toList();
      
      // Also notify users with deal create/view permissions
      List<String> usersWithPermission = await RoleService.getUsersWithPermission(
        page: 'Deals',
        permissionCheck: (perm) => perm.canCreate || perm.canView,
      );
      users.addAll(usersWithPermission);

      List<String> fcmIds = [];
      List<String> toUids = [];

      for (var i in users) {
        var userFcmIds = await AuthService.getUserFcmIds(uid: i);

        if (userFcmIds.isNotEmpty) {
          fcmIds.addAll(userFcmIds);
          toUids.add(i);
        }
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Deal : ${deal.dealName}',
        body: 'New deal created by ${user.name}',
        toFcms: fcmIds,
        toUids: users,
        senderId: await Spdb.getUid(),
        type: NotificationType.deal,
        payload: {'dealId': dealDoc.id},
      );

      await PostNotificationService.sendNotification(model: notif);
    } catch (e, st) {
      debugPrint("Error creating deal: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error creating deal: $e';
    }
  }

  static Future<void> updateDeal({
    required String uid,
    required DealModel deal,
  }) async {
    try {
      var cid = await Spdb.getCid();

      // Update deal in Firestore
      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.deals.name}',
        uid,
        deal.toUpdateMap(),
        activity: '${deal.dealName} has been updated',
      );

      List<String> users = deal.workFlow.toSet().toList();

      List<String> fcmIds = [];
      List<String> toUids = [];

      for (var i in users) {
        var userFcmIds = await AuthService.getUserFcmIds(uid: i);
        if (userFcmIds.isNotEmpty) {
          fcmIds.addAll(userFcmIds);
          toUids.add(i);
        }
      }

      var user = await Spdb.getUser();

      await addDealHistory(dealUid: uid, action: 'Deal Updated');

      // Also notify users with deal edit/view permissions
      List<String> usersWithPermission = await RoleService.getUsersWithPermission(
        page: 'Deals',
        permissionCheck: (perm) => perm.canEdit || perm.canView,
      );
      users.addAll(usersWithPermission);
      users = users.toSet().toList();

      // Recalculate FCM IDs with updated user list
      fcmIds = [];
      toUids = [];
      for (var i in users) {
        var userFcmIds = await AuthService.getUserFcmIds(uid: i);
        if (userFcmIds.isNotEmpty) {
          fcmIds.addAll(userFcmIds);
          toUids.add(i);
        }
      }

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Deal : ${deal.dealName}',
        body: 'Deal has been updated by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.deal,
        payload: {'dealId': uid},
      );

      PostNotificationService.sendNotification(model: notif);
    } catch (e, st) {
      debugPrint("Error updating deal: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error updating deal: $e';
    }
  }

  static Future<DealModel> getDeal({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var dealDoc = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(uid)
          .get();

      if (dealDoc.exists) {
        var dealData = dealDoc.data();
        if (dealData != null) {
          var deal = DealModel.fromMap(dealDoc.id, dealData);
          return deal;
        } else {
          throw 'Deal data is empty';
        }
      } else {
        throw 'Deal not found';
      }
    } catch (e, st) {
      debugPrint("Error fetching deal: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error fetching deal: $e';
    }
  }

  static Future<Map<DealStatusModel, List<DealModel>>> getDealByGroup({
    required List<DealModel> dealList,
  }) async {
    try {
      List<DealStatusModel> dealStatusList =
          await DealStatusService.getAllDealStatus();

      Map<DealStatusModel, List<DealModel>> groupedDeals = {
        for (var status in dealStatusList) status: [],
      };

      for (var deal in dealList) {
        final matchingStatus = dealStatusList.firstWhere(
          (status) => status.uid == deal.dealStatus,
          orElse: () => dealStatusList.first,
        );
        groupedDeals[matchingStatus]!.add(deal);
      }

      return groupedDeals;
    } catch (e, st) {
      debugPrint("Error grouping deals: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error grouping deals: $e';
    }
  }

  static Future<void> updateDealStatus({
    required String uid,
    required String dealStatus,
  }) async {
    try {
      var cid = await Spdb.getCid();
      await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(uid)
          .update({'dealStatus': dealStatus});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error updating deal status: $e\n$st");
      throw 'Error updating deal status: $e';
    }
  }

  static Future<void> deleteDeal({required String uid}) async {
    try {
      final cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
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
        activity: '${data['dealName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.deals.name}',
        collection: '${Collections.users.name}/$cid/${Collections.deals.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );

      // Notify users with deal delete/view permissions
      List<String> usersWithPermission = await RoleService.getUsersWithPermission(
        page: 'Deals',
        permissionCheck: (perm) => perm.canDelete || perm.canView,
      );

      if (usersWithPermission.isNotEmpty) {
        List<String> fcmIds = [];
        for (var i in usersWithPermission) {
          fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
        }

        var user = await Spdb.getUser();
        var notif = NotificationModel(
          collectionId: await Spdb.getCid() ?? '',
          title: 'Deal : ${data['dealName'] ?? 'N/A'}',
          body: 'Deal has been deleted by ${user.name}',
          createdAt: DateTime.now(),
          toFcms: fcmIds,
          toUids: usersWithPermission,
          senderId: await Spdb.getUid(),
          type: NotificationType.deal,
          payload: {'dealId': uid},
        );

        await PostNotificationService.sendNotification(model: notif);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('Error deleting deal: $e\n$st');
      rethrow;
    }
  }

  static Future<void> restoreDeal(DealModel deal) async {
    try {
      final firebase = FirebaseConfig();
      final cid = await Spdb.getCid();

      await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(deal.uid)
          .set(deal.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future isDealStatusAssigned(String s) async {}

  static Future<void> deleteDealComment({
    required String dealUid,
    required String commentUid,
  }) async {
    try {
      final cid = await Spdb.getCid();
      if (cid == null) throw "Missing cid";

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(dealUid)
          .collection('comments')
          .doc(commentUid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      docRef.reference.delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting deal comment: $e\n$st");
      rethrow;
    }
  }

  static Future<void> addDealComment({
    required String dealUid,
    required DealCommentModel commentText,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();
      if (cid == null || uid == null) throw "Missing cid or uid";

      final commentsRef = firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(dealUid)
          .collection('comments');

      final commentData = {
        'comment': commentText,
        'createdBy': {'uid': uid, 'name': (await Spdb.getUser()).name},
        'createdAt': FieldValue.serverTimestamp(),
      };

      await commentsRef.add(commentData);

      await addDealHistory(
        dealUid: dealUid,
        action: 'Comment Added: $commentText',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error adding deal comment: $e\n$st");
      rethrow;
    }
  }

  static Future<void> editDealComment({
    required String dealUid,
    required String commentUid,
    required String commentText,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      if (cid == null || uid == null) throw "Missing cid or uid";

      final commentsRef = firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(dealUid)
          .collection('comments')
          .doc(commentUid);

      final commentData = {'comment': commentText};

      await commentsRef.update(commentData);
      await addDealHistory(
        dealUid: dealUid,
        action: 'Comment Updated: $commentText',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error updating deal comment: $e\n$st");
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getDealComments({
    required String dealUid,
  }) async {
    try {
      final cid = await Spdb.getCid();
      if (cid == null) throw "Missing cid";

      final commentsRef = firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(dealUid)
          .collection('comments');

      final querySnapshot = await commentsRef
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error fetching deal comments: $e\n$st");
      rethrow;
    }
  }

  static Future<void> addDealHistory({
    required String dealUid,
    required String action,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      final historyRef = firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(dealUid)
          .collection('history');

      final history = DealHistoryModel(
        userId: user.uid,
        updateDisposition: action,
      );

      await historyRef.add(history.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error adding deal history: $e\n$st");
      rethrow;
    }
  }

  static Future<int> getUserDealsCount({required String userId}) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .where('workFlow', arrayContains: userId)
          .get();

      return snapshot.docs.length;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting user deals count: $e';
    }
  }

  static Future<List<DealModel>> getAllDeals() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .get();

      List<DealModel> deals = querySnapshot.docs.map((doc) {
        return DealModel.fromMap(doc.id, doc.data());
      }).toList();

      deals.sort((a, b) => a.dealName.compareTo(b.dealName));

      return deals;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching projects: $e';
    }
  }
}
