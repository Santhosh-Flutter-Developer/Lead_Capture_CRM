import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class AdminProfile extends StatefulWidget {
  final AdminModel admin;
  const AdminProfile({super.key, required this.admin});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  PermissionModel? _permissions;
  late AdminModel _admin;

  @override
  void initState() {
    super.initState();
    _admin = widget.admin;
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Admin');
    if (mounted) setState(() {});
  }

  Future<void> _openEdit({required double width}) async {
    final uid = _admin.uid;
    if (uid == null || uid.isEmpty) {
      FlushBar.show(
        context,
        'Unable to edit this admin profile',
        isSuccess: false,
      );
      return;
    }

    final result = kIsMobile || width < 1000
        ? await Sheet.showSheet(
            context,
            widget: AdminUpdate(id: uid, admin: _admin),
          )
        : await GeneralDialog.showRTLSheet(
            context,
            AdminUpdate(id: uid, admin: _admin),
          );

    if (result != true) return;

    try {
      final latest = await AdminService.getAdmin(uid: uid);
      if (latest != null && mounted) {
        setState(() {
          _admin = latest;
        });
      }
    } catch (_) {}
  }

  Future<bool> _canEditAdmin() async {
    final currentUid = await Spdb.getUid();
    if (_admin.uid != null && _admin.uid == currentUid) return true;
    return _permissions?.canEdit ?? false;
  }

  Future<void> _changeProfileImage() async {
    final uid = _admin.uid;
    if (uid == null || uid.isEmpty) return;

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
    );

    if (pickedImage == null) return;
    FlushBar.show(context, "Uploading profile picture...");

    try {
      String downloadUrl = await xFileToUploadUrl(
        pickedImage,
        StorageFolder.adminProfile,
      );

      final updatedAdmin = _admin.copyWith(profileImageUrl: downloadUrl);
      await AdminService.updateAdmin(id: uid, data: updatedAdmin);

      // Update local session if this is the logged-in admin
      final currentUid = await Spdb.getUid();
      final cid = await Spdb.getCid();
      if (currentUid == uid && cid != null) {
        await Spdb.setAdminLogin(model: updatedAdmin, cid: cid);
      }

      if (mounted) {
        setState(() => _admin = updatedAdmin);
        FlushBar.show(
          context,
          "Profile picture updated successfully",
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        FlushBar.show(
          context,
          "Failed to update profile picture: $e",
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final uid = _admin.uid;
    if (uid == null || uid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Profile Photo"),
        content: const Text("Are you sure you want to remove this photo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    FlushBar.show(context, "Removing profile picture...");

    try {
      await AdminService.deleteAdminProfileImage(uid: uid);

      final updated = _admin.copyWith(profileImageUrl: '');

      // Update local session if this is the logged-in admin
      final currentUid = await Spdb.getUid();
      final cid = await Spdb.getCid();
      if (currentUid == uid && cid != null) {
        await Spdb.setAdminLogin(model: updated, cid: cid);
      }

      if (mounted) {
        setState(() => _admin = updated);
        FlushBar.show(context, "Profile removed", isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        FlushBar.show(context, "Remove failed: $e", isSuccess: false);
      }
    }
  }

  void _viewFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.trash, color: Colors.red),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _removeProfileImage();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Profile Photo",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return FutureBuilder<bool>(
      future: _canEditAdmin(),
      builder: (context, snapshot) {
        final canEdit = snapshot.data ?? false;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            leading: Back(color: Theme.of(context).colorScheme.onSurface),
            title: Text(
              "Admin Profile",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: Theme.of(context).colorScheme.outlineVariant,
                height: 1,
              ),
            ),
            actions: [
              IconButton(
                onPressed: canEdit ?(){
                   _openEdit(width: width);
                } : null,
                tooltip: canEdit ? 'Edit Admin' : 'No edit permission',
                icon: Icon(
                  Iconsax.edit,
                  color: canEdit
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileCard(context, canEdit),
                const SizedBox(height: 22),
                _buildDetailsCard(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, bool canEdit) {
    final image = _admin.profileImageUrl;
    final hasImage = image != null && image.isNotEmpty;

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: AppColors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: hasImage ? () => _viewFullImage(image) : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        width: 4,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      backgroundImage: hasImage
                          ? NetworkImage(image)
                          : const NetworkImage(AppStrings.emptyProfilePhotoUrl)
                                as ImageProvider,
                    ),
                  ),
                ),
                if (canEdit)
                  Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _changeProfileImage,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Icon(
                          Iconsax.image,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              _admin.name,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            Chip(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              label: Text(
                _admin.isActive ? 'Active' : 'Inactive',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: _admin.isActive
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: AppColors.black12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, "Admin Details"),
            const SizedBox(height: 12),

            _detailRow(
              context: context,
              icon: Icons.email_outlined,
              label: 'Email',
              value: _admin.email,
            ),
            _divider(),

            _detailRow(
              context: context,
              icon: Icons.phone,
              label: 'Mobile Number',
              value: _admin.mobileNumber,
            ),
            _divider(),

            _detailRow(
              context: context,
              icon: Icons.verified_user_outlined,
              label: 'Status',
              value: _admin.isActive ? 'Active' : 'Inactive',
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _detailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Theme.of(context).dividerColor),
    );
  }
}
