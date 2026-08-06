import 'package:shared_preferences/shared_preferences.dart';
import '/models/models.dart';
import '/services/services.dart';

class PermissionService {
  static const _createKey = 'perm_create';
  static const _editKey = 'perm_edit';
  static const _deleteKey = 'perm_delete';
  static const _viewKey = 'perm_view';
  static const _exportKey = 'perm_export';
  static const _importKey = 'perm_import';

  /// Save Permissions
  static Future<void> savePermissions(List<PermissionModel> permissions) async {
    final prefs = await SharedPreferences.getInstance();

    for (var i in permissions) {
      await prefs.setBool('${_createKey}_${i.page}', i.canCreate);
      await prefs.setBool('${_editKey}_${i.page}', i.canEdit);
      await prefs.setBool('${_deleteKey}_${i.page}', i.canDelete);
      await prefs.setBool('${_viewKey}_${i.page}', i.canView);
      await prefs.setBool('${_exportKey}_${i.page}', i.canExport);
      await prefs.setBool('${_importKey}_${i.page}', i.canImport);
    }
  }

  static Future<PermissionModel?> getPermissions(String page) async {
    var isAdmin = await Spdb.isAdminLoggedIn();
    if (isAdmin) {
      return PermissionModel(
        page: page,
        canCreate: true,
        canDelete: true,
        canEdit: true,
        canView: true,
        canExport: true,
        canImport: true,
      );
    }

    final prefs = await SharedPreferences.getInstance();

    final canCreate = prefs.getBool('${_createKey}_$page') ?? false;
    final canEdit = prefs.getBool('${_editKey}_$page') ?? false;
    // Delete is admin-only — non-admin users never get delete permission.
    const canDelete = false;
    final canView = prefs.getBool('${_viewKey}_$page') ?? false;
    final canExport = prefs.getBool('${_exportKey}_$page') ?? true;
    final canImport = prefs.getBool('${_importKey}_$page') ?? true;

    if (canCreate || canEdit || canDelete || canView) {
      return PermissionModel(
        page: page,
        canCreate: canCreate,
        canDelete: canDelete,
        canEdit: canEdit,
        canView: canView,
        canExport: canExport,
        canImport: canImport,
      );
    }

    return null;
  }
}
