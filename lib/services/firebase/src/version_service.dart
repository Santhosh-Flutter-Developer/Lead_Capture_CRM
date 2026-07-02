import 'dart:io';
import '/models/models.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/services/services.dart';

class VersionService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static VersionModel? _versionModel;

  static Future<void> init() async {
    try {
      _versionModel = await _checkForUpdates();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<VersionModel?> _checkForUpdates() async {
    try {
      String? cid = await Spdb.getCid();

      if (cid == null) return null;

      String platform;

      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else if (Platform.isWindows) {
        platform = 'windows';
      } else if (Platform.isMacOS) {
        platform = 'macos';
      } else {
        platform = 'web';
      }

      var versionDoc = await firebase.users
          .doc(cid)
          .collection(Collections.version.name)
          .where('platform', isEqualTo: platform)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (versionDoc.docs.isEmpty) return null;
      var versionData = versionDoc.docs.first.data();

      var versionModel = VersionModel.fromMap(versionData);

      var currentVersion = AppPackageInfo.version;

      var latestVersion = versionData['version'].toString();

      if (_isNewer(currentVersion, latestVersion)) {
        versionModel.isUpdateNeed = true;
      }

      return versionModel;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static bool _isNewer(String current, String latest) {
    List<int> c = _normalizeVersion(current);
    List<int> l = _normalizeVersion(latest);

    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _normalizeVersion(String v) {
    List<String> parts = v.split('.');

    while (parts.length < 3) {
      parts.add('0');
    }
    if (parts.length > 3) {
      parts = parts.sublist(0, 3);
    }

    return parts.map((e) => int.tryParse(e) ?? 0).toList();
  }

  static VersionModel? get version => _versionModel;
}
