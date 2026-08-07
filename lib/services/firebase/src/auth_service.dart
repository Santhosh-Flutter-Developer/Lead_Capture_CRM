import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';

class AuthService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<Map<String, dynamic>> checkLogin({
    String? employeeId,
    String? email,
    required String password,
  }) async {
    try {
      if (employeeId != null && employeeId.isNotEmpty) {
        var employeeQuery = await FirebaseFirestore.instance
            .collectionGroup(Collections.employees.name)
            .where('employeeId', isEqualTo: employeeId.trim())
            .get();

        if (employeeQuery.docs.isNotEmpty) {
          var doc = employeeQuery.docs.first;
          var userData = doc.data();
          String cid = doc.reference.parent.parent!.id;
          // Verify Password
          if (userData['password'].toString().decrypt != password) {
            return {"status": false, "error": "Invalid password"};
          }

          if (userData['loginAllowed'] == false) {
            return {"status": false, "error": "Your login is disabled!"};
          }

          await _trackDevice(cid: cid, uid: doc.id, isAdmin: false);
          return {
            "status": true,
            "collectionId": cid,
            "uid": doc.id,
            "userData": userData,
          };
        }
      }

      if (email != null && email.isNotEmpty) {
        // First check employee by email (which is stored encrypted)
        var employeeQuery = await FirebaseFirestore.instance
            .collectionGroup(Collections.employees.name)
            .where('email', isEqualTo: email.trim().encrypt)
            .get();

        if (employeeQuery.docs.isEmpty) {
          employeeQuery = await FirebaseFirestore.instance
              .collectionGroup(Collections.employees.name)
              .where('email', isEqualTo: email.trim().toLowerCase().encrypt)
              .get();
        }

        if (employeeQuery.docs.isNotEmpty) {
          var doc = employeeQuery.docs.first;
          var userData = doc.data();
          String cid = doc.reference.parent.parent!.id;
          // Verify Password
          if (userData['password'].toString().decrypt != password) {
            return {"status": false, "error": "Invalid password"};
          }

          if (userData['loginAllowed'] == false) {
            return {"status": false, "error": "Your login is disabled!"};
          }

          await _trackDevice(cid: cid, uid: doc.id, isAdmin: false);
          return {
            "status": true,
            "collectionId": cid,
            "uid": doc.id,
            "userData": userData,
          };
        }

        // Then check admin by email
        var adminQuery = await FirebaseFirestore.instance
            .collectionGroup(Collections.admins.name)
            .where('email', isEqualTo: email.trim().toLowerCase())
            .get();

        if (adminQuery.docs.isNotEmpty) {
          var doc = adminQuery.docs.first;
          var adminData = doc.data();
          String cid = doc.reference.parent.parent!.id;

          // Verify Password
          if (adminData['password'].toString().decrypt != password) {
            return {"status": false, "error": "Invalid password"};
          }

          if (adminData['loginAllowed'] == false) {
            return {"status": false, "error": "Your login is disabled!"};
          }

          await _trackDevice(cid: cid, uid: doc.id, isAdmin: true);

          var companyDoc = await FirebaseFirestore.instance
              .collection(Collections.users.name)
              .doc(cid)
              .get();

          String? companyLogoUrl = companyDoc.data()?['logo'];
          String? companyName = companyDoc.data()?['companyName'];

          // await _trackDevice(cid: cid, uid: doc.id, isAdmin: true);

          return {
            "status": true,
            "collectionId": cid,
            "uid": doc.id,
            "adminData": adminData,
            "companyLogo": companyLogoUrl,
            "companyName": companyName,
          };
        }
      }

      return {"status": false, "error": "No user found"};
    } catch (e, st) {
      debugPrint("Login Error: $e");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<Map<String, dynamic>> registerCompany({
    required String name,
    required String adminEmail,
    required String adminName,
    required String password,
    File? logo,
    Uint8List? logoBytes,
    double? companyLat,
    double? companyLng,
    double? companyRadius,
  }) async {
    try {
      // 1. Create company
      DocumentReference companyRef = firebase.users.doc();
      String companyId = companyRef.id;

      // 2. Upload logo
      String? logoUrl;
      if (kIsWeb && logoBytes != null) {
        // Web: upload bytes
        logoUrl = await StorageService.uploadImageBytes(
          bytes: logoBytes,
          folder: StorageFolder.companyLogo,
          collectionId: companyId,
        );
      } else if (logo != null) {
        logoUrl = await StorageService.uploadImage(
          file: logo,
          folder: StorageFolder.companyLogo,
          collectionId: companyId,
        );
      }

      await companyRef.set({
        'companyName': name,
        'createdAt': FieldValue.serverTimestamp(),
        'logo': logoUrl,
        'status': 'active',
        'companyLat': ?companyLat,
        'companyLng': ?companyLng,
        'companyRadius': ?companyRadius,
      });

      DocumentReference roleRef = companyRef
          .collection(Collections.roles.name)
          .doc();

      final superAdminRole = RoleModel(
        name: RoleModel.superAdminRoleName,
        description: 'System role with full access',
        createdBy: UserDataModel(
          uid: 'Admin',
          name: 'Admin',
          userType: UserType.admin,
        ),
      );
      await roleRef.set(superAdminRole.toMap());

      DocumentReference adminRef = companyRef
          .collection(Collections.admins.name)
          .doc();

      AdminModel admin = AdminModel(
        uid: adminRef.id,
        name: adminName,
        email: adminEmail.trim().toLowerCase(),
        password: password,
        mobileNumber: "",
        createdBy: UserDataModel(
          uid: "Admin",
          name: "Admin",
          userType: UserType.admin,
        ),
      );

      await adminRef.set({
        ...admin.toMap(),
        "roleId": roleRef.id,
        "companyId": companyId,
        "devices": [],
        "loginAllowed": true,
      });

      return {"status": true, "message": "Company registered successfully"};
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      return {"status": false, "error": e.toString()};
    }
  }

  static Future<void> _trackDevice({
    required String cid,
    required String uid,
    required bool isAdmin,
  }) async {
    try {
      var deviceInfo = await DeviceInfo.getDeviceInfo();
      var deviceMap = deviceInfo.toMap();

      final collection = isAdmin
          ? Collections.admins.name
          : Collections.employees.name;

      var userDoc = await firebase.users
          .doc(cid)
          .collection(collection)
          .doc(uid)
          .get();

      if (!userDoc.exists) return;

      List<dynamic> devicesRaw = userDoc.data()?['devices'] ?? [];
      List<DeviceModel> devices = devicesRaw
          .map((e) => DeviceModel.fromMap(e as Map<String, dynamic>))
          .toList();

      bool deviceExists = devices.any(
        (d) => d.toMatchMap().toString() == deviceInfo.toMatchMap().toString(),
      );

      if (deviceExists) {
        devices = devices.map((d) {
          if (d.toMatchMap().toString() == deviceInfo.toMatchMap().toString()) {
            var map = d.toMap();
            if (kIsMobile || kIsWeb) map['fcmId'] = deviceMap['fcmId'];
            map['lastLoginAt'] = DateTime.now().millisecondsSinceEpoch;
            return DeviceModel.fromMap(map);
          }
          return d;
        }).toList();

        await firebase.users.doc(cid).collection(collection).doc(uid).update({
          'devices': devices.map((d) => d.toMap()).toList(),
        });
      } else {
        await firebase.users.doc(cid).collection(collection).doc(uid).update({
          "devices": FieldValue.arrayUnion([deviceMap]),
        });
      }
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<void> removeCurrentDeviceFcm() async {
    if (kIsWeb) return;

    var cid = await Spdb.getCid();
    var uid = await Spdb.getUid();

    try {
      var deviceInfo = await DeviceInfo.getDeviceInfo();
      var userRef = firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .doc(uid);

      var userDoc = await userRef.get();
      if (!userDoc.exists) return;

      List<dynamic> devicesRaw = userDoc.data()?['devices'] ?? [];
      List<DeviceModel> devices = devicesRaw
          .map((e) => DeviceModel.fromMap(e as Map<String, dynamic>))
          .toList();

      devices = devices.map((d) {
        if (d.toMatchMap().toString() == deviceInfo.toMatchMap().toString()) {
          var map = d.toMap();
          map['fcmId'] = null;
          return DeviceModel.fromMap(map);
        }
        return d;
      }).toList();

      await userRef.update({'devices': devices.map((d) => d.toMap()).toList()});
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      debugPrint('Error removing device FCM ID: $e');
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  Future<bool> checkUserEmailExists({
    required String email,
    String? uid,
  }) async {
    try {
      Query<Map<String, dynamic>> query = firebase.users;

      if (uid != null) {
        query = query.where(FieldPath.documentId, isNotEqualTo: uid);
      }

      var companies = await query.get();

      for (var i in companies.docs) {
        if (i.exists) {
          var user = await firebase.users
              .doc(i.id)
              .collection(Collections.employees.name)
              .where('email', isEqualTo: email.trim().encrypt)
              .get();
          if (user.docs.isEmpty) {
            user = await firebase.users
                .doc(i.id)
                .collection(Collections.employees.name)
                .where('email', isEqualTo: email.trim().toLowerCase().encrypt)
                .get();
          }
          if (user.docs.isNotEmpty) {
            return true;
          }
        }
      }

      return false;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<void> resetPassword({
    required Map<String, dynamic> emailData,
    required String newPassword,
  }) async {
    try {
      if (emailData['adminId'] != null) {
        await firebase.users
            .doc(emailData['companyId'])
            .collection(Collections.admins.name)
            .doc(emailData['adminId'])
            .update({'password': newPassword.encrypt});
      } else if (emailData['employeeId'] != null) {
        await firebase.users
            .doc(emailData['companyId'])
            .collection(Collections.employees.name)
            .doc(emailData['employeeId'])
            .update({
              'password': newPassword.encrypt,
              'isInitialPasswordChanged': true,
            });
      }
    } catch (e, st) {
      debugPrint("Error resetting password: $e, $st");
      await ErrorService.recordError(e, st);
    }
  }

  static Future<List<String>> getUserFcmIds({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var userRef = firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .doc(uid);

      var userDoc = await userRef.get();
      if (!userDoc.exists) return [];

      var userData = userDoc.data();

      List<String> fcmIds = [];

      if (userData?['devices'] != null &&
          (userData?['devices'] as List).isNotEmpty) {
        for (var i in userData?['devices']) {
          if (i['fcmId'] != null && i['fcmId'] != '') {
            fcmIds.add(i['fcmId']);
          }
        }
      }

      return fcmIds;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<Map<String, dynamic>?> checkEmailExists({
    required String email,
  }) async {
    try {
      var companies = await firebase.users.get();

      for (var company in companies.docs) {
        var adminQuery = await firebase.users
            .doc(company.id)
            .collection(Collections.admins.name)
            .get();

        if (adminQuery.docs.isNotEmpty) {
          for (var i in adminQuery.docs) {
            var data = i.data();
            if (data['email'] == email.trim().toLowerCase()) {
              final nameValue = data['name'];
              return {
                'companyId': company.id,
                'adminId': i.id,
                'name': (nameValue != null && nameValue is String)
                    ? nameValue.decrypt
                    : '',
                'email': email,
              };
            }
          }
        }

        var employeeQuery = await firebase.users
            .doc(company.id)
            .collection(Collections.employees.name)
            .get();

        if (employeeQuery.docs.isNotEmpty) {
          for (var i in employeeQuery.docs) {
            var data = i.data();
            String decryptedEmail = (data['email'] ?? '').toString().decrypt;
            if (decryptedEmail.trim().toLowerCase() ==
                email.trim().toLowerCase()) {
              final nameValue = data['name'];
              return {
                'companyId': company.id,
                'employeeId': i.id,
                'name': (nameValue != null && nameValue is String)
                    ? nameValue.decrypt
                    : '',
                'email': email,
              };
            }
          }
        }
      }

      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<Map<String, dynamic>> refreshLogin() async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      var employee = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .doc(uid)
          .get();

      if (employee.exists) {
        var uData = employee.data() ?? {};

        return {
          "status": true,
          "collectionId": cid,
          "uid": uid,
          "userData": uData,
        };
      }

      var admin = await firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .doc(uid)
          .get();

      if (admin.exists) {
        final adminData = admin.data() ?? {};

        return {
          "status": true,
          "collectionId": cid,
          "uid": admin.id,
          "adminData": adminData,
        };
      }

      return {"status": false, "error": "No user found"};
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<void> saveLoginLogs({required LoginLogsModel log}) async {
    try {
      var cid = await Spdb.getCid();
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.loginLogs.name}',
        log.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating log: $e';
    }
  }

  static Future<void> saveActivityLogs({required ActivityLogModel log}) async {
    try {
      var cid = await Spdb.getCid();
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        log.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating log: $e";
    }
  }
}
