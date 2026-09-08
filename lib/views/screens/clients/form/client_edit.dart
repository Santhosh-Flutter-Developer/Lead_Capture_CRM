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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const WaitingLoading();
          }

          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  FormWidgets.buildHeader(
                    context: context,
                    title: "Update Contact",
                  ),

                  _section("Contact Details", _contactFields()),

                  _section("Profile Picture", _buildProfileImage()),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: FormWidgets.buildBottomBar(
        context: context,
        onSubmit: _submit,
        isEdit: true,
      ),
    );
  }

  Widget _contactFields() {
    return Column(
      children: [
        // Row 1
        Row(
          children: [
            Expanded(
              child: FormDropdownSearch(
                label: "Salutation",
                items: const ["Mr.", "Mrs.", "Ms.", "Dr."],
                initialItem: _salutation,
                onChanged: (v) => _salutation = v as String?,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(label: "Name", controller: _name),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(label: "Email", controller: _email),
            ),
            const SizedBox(width: 16),
            // Expanded(
            //   child: FormFields(
            //     label: "Password",
            //     controller: _password,
            //     hintText: "Leave blank to keep existing",
            //   ),
            // ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2
        Row(
          children: [
            Expanded(
              child: FormFields(label: "Mobile", controller: _mobile),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormDropdownSearch(
                label: "Gender",
                items: const ["Male", "Female", "Other"],
                initialItem: _gender,
                onChanged: (v) => _gender = v as String?,
              ),
            ),
            const SizedBox(width: 16),
            // Expanded(
            //   child: FormDropdownSearch(
            //     label: "Language",
            //     items: AppStrings.spokenLanguages,
            //     initialItem: _language,
            //     onChanged: (v) => _language = v as String?,
            //   ),
            // ),
            // const SizedBox(width: 16),
            // Expanded(
            //   child: FormDropdownSearch(
            //     label: "Login Allowed",
            //     items: const ["Yes", "No"],
            //     initialItem: _loginAllowed ? "Yes" : "No",
            //     onChanged: (v) => _loginAllowed = v == "Yes",
            //   ),
            // ),
          ],
        ),
      ],
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

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            child,
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const WaitingLoading();
          }

          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  FormWidgets.buildHeader(
                    context: context,
                    title: "Update Company",
                  ),

                  _section("Company Information", _companyFields()),

                  _section("Company Logo", _buildLogo()),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: FormWidgets.buildBottomBar(
        context: context,
        onSubmit: _submit,
        isEdit: true,
      ),
    );
  }

  Widget _companyFields() {
    return Column(
      children: [
        // Row 1
        Row(
          children: [
            Expanded(
              child: FormFields(
                label: "Company Name",
                controller: _companyName,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(label: "Website", controller: _website),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(label: "GST/VAT", controller: _gst),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(label: "Office Phone", controller: _phone),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2
        Row(
          children: [
            Expanded(
              child: FormFields(
                label: "Postal Code",
                controller: _postal,
                isRequired: true,
                valid: (input) =>
                    Validation.validPostalCode(input: input, isReq: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(
                label: "Address",
                controller: _address,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormFields(label: "Note", controller: _note, maxLines: 3),
            ),
            const SizedBox(width: 16),
            Expanded(child: Container()),
          ],
        ),
      ],
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

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            child,
          ],
        ),
      ),
    );
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
