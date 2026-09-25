import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class ContactUpdate extends StatefulWidget {
  final String uid;
  const ContactUpdate({super.key, required this.uid});

  @override
  State<ContactUpdate> createState() => _ContactUpdateState();
}

class _ContactUpdateState extends State<ContactUpdate> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mobile = TextEditingController();

  String? _salutation;
  String? _gender;
  String? _language;
  bool _loginAllowed = true;
  bool _receiveEmailNotifications = true;

  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
  bool _oldImageRemoved = false;

  ClientModel? _client;
  late Future _future;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    _future = _load();
    super.initState();
  }

  Future<void> _load() async {
    try {
      _client = await ClientService.getClient(uid: widget.uid);

      if (_client != null) {
        _name.text = _client!.clientName ?? '';
        _email.text = _client!.email ?? '';
        _password.text = _client!.password ?? '';
        _mobile.text = _client!.mobileNumber ?? '';
        _salutation = _client!.salutation;
        _gender = _client!.gender;
        _language = _client!.changeLanguage;
        _loginAllowed = _client!.loginAllowed ?? true;
        _receiveEmailNotifications = _client!.receiveEmailNotifications ?? true;
        _profileImageUrl = _client!.profilePictureUrl;
      }
    } catch (e, st) {
      debugPrint("Error loading contact: $e\n$st");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Iconsax.edit, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Contact",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update this contact's details and photo",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const WaitingLoading();
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildSectionCard(
                            icon: Iconsax.user,
                            title: "Contact Details",
                            subtitle: "Update the contact's core details",
                            child: _contactFields(),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            icon: Iconsax.gallery,
                            title: "Profile Picture",
                            subtitle: "Optional, shown across the CRM",
                            child: Center(child: _buildProfileImage()),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          label: "Update",
          icon: Iconsax.edit,
          onSubmit: _submit,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required String label,
    required IconData icon,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double currentWidth = constraints.maxWidth;
        const double horizontalSpacing = 16.0;
        const double verticalSpacing = 8.0;
        const double minColumnWidth = 220.0;
        const int gridCounts = 2;

        final bool canShowGrid =
            currentWidth >=
            (minColumnWidth * gridCounts +
                horizontalSpacing * (gridCounts - 1));

        final double itemWidth = canShowGrid
            ? (currentWidth - horizontalSpacing * (gridCounts - 1)) /
                  gridCounts
            : currentWidth;

        return Wrap(
          spacing: horizontalSpacing,
          runSpacing: verticalSpacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: FormDropdownSearch(
                label: "Salutation",
                items: const ["Mr.", "Mrs.", "Ms.", "Dr."],
                initialItem: _salutation,
                onChanged: (v) => _salutation = v as String?,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Name",
                controller: _name,
                prefixIcon: const Icon(Iconsax.user, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Email",
                controller: _email,
                prefixIcon: const Icon(Iconsax.sms, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Mobile",
                controller: _mobile,
                prefixIcon: const Icon(Iconsax.call, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormDropdownSearch(
                label: "Gender",
                items: const ["Male", "Female", "Other"],
                initialItem: _gender,
                onChanged: (v) => _gender = v as String?,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage() {
    return ImagePickerWidget(
      image: _profileImage,
      imageBytes: _profileImageBytes,
      networkImage: _profileImageUrl,
      label: "Upload Profile",
      onChanged: (file) {
        setState(() {
          _profileImage = file;
          if (_profileImageUrl != null) {
            _oldImageRemoved = true;
            _profileImageUrl = null;
          }
        });
        if (kIsWeb) {
          file.readAsBytes().then(
            (b) => setState(() => _profileImageBytes = b),
          );
        }
      },
      onRemove: () {
        _profileImage = null;
        _profileImageUrl = null;
        _oldImageRemoved = true;
        setState(() {});
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    futureLoading(context);

    try {
      String? imageUrl = _profileImageUrl;
      if (_profileImage != null) {
        imageUrl = await xFileToUploadUrl(
          _profileImage!,
          StorageFolder.clientPhotos,
        );
      }

      if (_oldImageRemoved) {
        await ClientService.deleteClientProfileImage(uid: widget.uid);
      }

      final updated = _client!.copyWith(
        salutation: _salutation,
        clientName: _name.text,
        email: _email.text,
        password: _password.text,
        mobileNumber: _mobile.text,
        gender: _gender,
        changeLanguage: _language,
        loginAllowed: _loginAllowed,
        receiveEmailNotifications: _receiveEmailNotifications,
        profilePictureUrl: imageUrl,
        updatedAt: DateTime.now(),
      );

      await ClientService.editClient(client: updated, uid: widget.uid);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);
      FlushBar.show(context, "Contact updated", isSuccess: true);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
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


class CompanyUpdate extends StatefulWidget {
  final String uid;
  const CompanyUpdate({super.key, required this.uid});

  @override
  State<CompanyUpdate> createState() => _CompanyUpdateState();
}

class _CompanyUpdateState extends State<CompanyUpdate> {
  final _formKey = GlobalKey<FormState>();
  late final String? uid;
  final _companyName = TextEditingController();
  final _website = TextEditingController();
  final _gst = TextEditingController();
  final _phone = TextEditingController();
  final _postal = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  XFile? _logo;
  Uint8List? _logoBytes;
  String? _logoUrl;
  bool _oldLogoRemoved = false;

  ClientModel? _client;
  late Future _future;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();

    if (widget.uid.isNotEmpty) {
      _future = _load();
    } else {
      _future = Future.value();
    }
  }

  Future<void> _load() async {
    if (widget.uid.isEmpty) return;

    try {
      _client = await ClientService.getClient(uid: widget.uid);

      _companyName.text = _client!.companyName ?? '';
      _website.text = _client!.officialWebsite ?? '';
      _gst.text = _client!.gstVatNumber ?? '';
      _phone.text = _client!.officePhoneNo ?? '';
      _postal.text = _client!.postalCode ?? '';
      _address.text = _client!.companyAddress ?? '';
      _note.text = _client!.notes ?? '';
      _logoUrl = _client!.companyLogoUrl;
    } catch (e, st) {
      debugPrint("Error loading company: $e\n$st");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Iconsax.edit, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Company",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update this company's details and logo",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const WaitingLoading();
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildSectionCard(
                            icon: Iconsax.buildings,
                            title: "Company Information",
                            subtitle: "Update the company's core details",
                            child: _companyFields(),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            icon: Iconsax.gallery,
                            title: "Company Logo",
                            subtitle: "Optional, shown across the CRM",
                            child: Center(child: _buildLogo()),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          label: "Update",
          icon: Iconsax.edit,
          onSubmit: _submit,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required String label,
    required IconData icon,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double currentWidth = constraints.maxWidth;
        const double horizontalSpacing = 16.0;
        const double verticalSpacing = 8.0;
        const double minColumnWidth = 220.0;
        const int gridCounts = 2;

        final bool canShowGrid =
            currentWidth >=
            (minColumnWidth * gridCounts +
                horizontalSpacing * (gridCounts - 1));

        final double itemWidth = canShowGrid
            ? (currentWidth - horizontalSpacing * (gridCounts - 1)) /
                  gridCounts
            : currentWidth;

        return Wrap(
          spacing: horizontalSpacing,
          runSpacing: verticalSpacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Company Name",
                controller: _companyName,
                prefixIcon: const Icon(Iconsax.buildings, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Website",
                controller: _website,
                prefixIcon: const Icon(Iconsax.global, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "GST/VAT",
                controller: _gst,
                prefixIcon: const Icon(Iconsax.document_text_1, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Office Phone",
                controller: _phone,
                prefixIcon: const Icon(Iconsax.call, size: 18),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Postal Code",
                controller: _postal,
                isRequired: true,
                prefixIcon: const Icon(Iconsax.location, size: 18),
                valid: (input) =>
                    Validation.validPostalCode(input: input, isReq: true),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FormFields(
                label: "Address",
                controller: _address,
                maxLines: 2,
                prefixIcon: const Icon(Iconsax.gps, size: 18),
              ),
            ),
            SizedBox(
              width: currentWidth,
              child: FormFields(
                label: "Note",
                controller: _note,
                maxLines: 3,
                prefixIcon: const Icon(Iconsax.document_text, size: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return ImagePickerWidget(
      image: _logo,
      imageBytes: _logoBytes,
      networkImage: _logoUrl,
      label: "Upload Logo",
      onChanged: (file) {
        setState(() {
          _logo = file;
          if (_logoUrl != null) {
            _oldLogoRemoved = true;
            _logoUrl = null;
          }
        });
        if (kIsWeb) {
          file.readAsBytes().then((b) => setState(() => _logoBytes = b));
        }
      },
      onRemove: () {
        _logo = null;
        _logoUrl = null;
        _oldLogoRemoved = true;
        setState(() {});
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    futureLoading(context);

    try {
      String? logoUrl = _logoUrl;
      if (_logo != null) {
        logoUrl = await xFileToUploadUrl(
          _logo!,
          StorageFolder.clientCompanyLogos,
        );
      }

      if (_oldLogoRemoved) {
        await ClientService.deleteClientCompanyLogo(uid: widget.uid);
      }

      final updated = _client!.copyWith(
        companyName: _companyName.text,
        officialWebsite: _website.text,
        gstVatNumber: _gst.text,
        officePhoneNo: _phone.text,
        postalCode: _postal.text,
        companyAddress: _address.text,
        notes: _note.text,
        companyLogoUrl: logoUrl,
        updatedAt: DateTime.now(),
      );

      await ClientService.editClient(client: updated, uid: widget.uid);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);
      FlushBar.show(context, "Company updated", isSuccess: true);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
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


class ImagePickerWidget extends StatelessWidget {
  final XFile? image;
  final Uint8List? imageBytes;
  final String? networkImage;
  final String label;
  final VoidCallback onRemove;
  final Function(XFile file) onChanged;

  const ImagePickerWidget({
    super.key,
    required this.image,
    this.imageBytes,
    required this.networkImage,
    required this.label,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = image != null;

    if (hasLocalImage || networkImage != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () async {
              final result = await PickImage.pickFromGallery();
              if (result != null) onChanged(result);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasLocalImage
                  ? (kIsWeb
                        ? Image.memory(
                            imageBytes ?? Uint8List(0),
                            height: 140,
                            width: 140,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(image!.path),
                            height: 140,
                            width: 140,
                            fit: BoxFit.cover,
                          ))
                  : CachedNetworkImage(
                      imageUrl: networkImage!,
                      placeholder: (_, _) => Shimmer.fromColors(
                        baseColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        highlightColor: Theme.of(context).colorScheme.surface,
                        child: Container(
                          height: 140,
                          width: 140,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      errorWidget: (_, _, _) => const Icon(Icons.error),
                      height: 140,
                      width: 140,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.error,
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () async {
        final result = await PickImage.pickFromGallery();
        if (result != null) onChanged(result);
      },
      child: DottedBorder(
        child: Container(
          height: 140,
          width: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.gallery,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}