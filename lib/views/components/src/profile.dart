import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/constants/constants.dart';

/// Profile screen now supports only Admin users after employee-related features removal.
class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  AdminModel? _admin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    setState(() => _isLoading = true);
    final admin = await Spdb.getAdmin();
    if (mounted) {
      setState(() {
        _admin = admin;
        _isLoading = false;
      });
    }
  }

  /// Change admin profile image.
  Future<void> _changeProfileImage() async {
    if (_admin?.uid == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 65);
    if (picked == null) return;
    FlushBar.show(context, "Uploading profile picture...");
    try {
      final downloadUrl = await xFileToUploadUrl(picked, StorageFolder.adminProfile);
      final updated = _admin!.copyWith(profileImageUrl: downloadUrl);
      await AdminService.updateAdmin(id: updated.uid!, data: updated);
      final currentUid = await Spdb.getUid();
      final cid = await Spdb.getCid();
      if (currentUid == updated.uid && cid != null) {
        await Spdb.setAdminLogin(model: updated, cid: cid);
      }
      if (mounted) {
        setState(() => _admin = updated);
        FlushBar.show(context, "Profile picture updated successfully", isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        FlushBar.show(context, "Failed to update profile picture: $e", isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: Back(color: Theme.of(context).colorScheme.onSurface),
          title: const Text('My Profile'),
        ),
        body: const Center(child: WaitingLoading()),
      );
    }
    final admin = _admin!;
    // Reuse existing AdminProfile widget for detailed UI.
    return AdminProfile(admin: admin);
  }
}
