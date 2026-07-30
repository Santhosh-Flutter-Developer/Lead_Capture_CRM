import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class AdminUpdate extends StatefulWidget {
  final AdminModel admin;
  final String id;

  const AdminUpdate({super.key, required this.admin, required this.id});

  @override
  State<AdminUpdate> createState() => _AdminUpdateState();
}

class _AdminUpdateState extends State<AdminUpdate> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  XFile? _newProfileImage;
  String? _existingProfileUrl;

  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.admin.name;
    _emailController.text = widget.admin.email;
    _passwordController.text = widget.admin.password;
    _mobileController.text = widget.admin.mobileNumber;
    _existingProfileUrl = widget.admin.profileImageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              FormWidgets.buildHeader(context: context, title: "Update Admin"),
              const SizedBox(height: 20),

              _buildSectionCard(
                title: "Admin Details",
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _buildAdminDetails(constraints, 2),
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionCard(
                title: "Profile Picture",
                child: Center(
                  child: _buildProfileImageUploaded("Upload Profile"),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FormWidgets.buildBottomBar(
        context: context,
        onSubmit: _updateAdmin,
        isEdit: true,
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ADMIN DETAILS FIELDS
  Widget _buildAdminDetails(BoxConstraints constraints, int gridCount) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >= (minColumnWidth * 3 + horizontalSpacing * (3 - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (3 - 1)) / 3
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Name",
            controller: _nameController,
            isRequired: true,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Name is required";
              }
              if (value.length < 3) return "Name must be at least 3 characters";
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Email",
            controller: _emailController,
            isRequired: true,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Email is required";
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return "Enter a valid email address";
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Password",
            controller: _passwordController,
            isRequired: true,
            obsecureText: !_passwordVisible,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Password is required";
              }
              if (value.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
            suffixIcon: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              splashRadius: 1,
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              icon: Icon(
                _passwordVisible ? Iconsax.eye : Iconsax.eye_slash,
                size: 20,
              ),
            ),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Mobile Number",
            controller: _mobileController,
            isRequired: true,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Mobile number is required";
              }
              final mobileRegex = RegExp(r'^[0-9]{10}$');
              if (!mobileRegex.hasMatch(value.trim())) {
                return "Enter a valid 10-digit mobile number";
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // PROFILE IMAGE UPLOAD
  Widget _buildProfileImageUploaded(String label) {
    // If new image selected
    if (_newProfileImage != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 140,
              width: 140,
              child: FutureBuilder<Uint8List>(
                future: _newProfileImage!.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _newProfileImage = null),
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    // If existing image available
    if (_existingProfileUrl != null && _existingProfileUrl!.isNotEmpty) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _existingProfileUrl!,
              height: 140,
              width: 140,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(
                    Iconsax.gallery_slash,
                    size: 40,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () async {
                final picked = await PickImage.selectImage(context);
                if (picked != null) {
                  setState(() {
                    _existingProfileUrl = null;
                    _newProfileImage = picked;
                  });
                }
              },
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () async {
        final image = await PickImage.selectImage(context);
        if (image != null) setState(() => _newProfileImage = image);
      },
      child: DottedBorder(
        options: RectDottedBorderOptions(),
        child: Container(
          height: 140,
          width: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.gallery,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  "Upload Profile",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      futureLoading(context);

      String? newImageUrl = _existingProfileUrl;

      if (_newProfileImage != null) {
        newImageUrl = await xFileToUploadUrl(
          _newProfileImage!,
          StorageFolder.adminProfile,
        );
      }

      AdminModel adminModel = AdminModel(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        password: _passwordController.text,
        mobileNumber: _mobileController.text.trim(),
        profileImageUrl: newImageUrl,
        createdBy: await Spdb.getUser(),
      );

      await AdminService.updateAdmin(id: widget.id, data: adminModel);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);
      FlushBar.show(context, "Admin updated successfully", isSuccess: true);
    } catch (e, st) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }
}
