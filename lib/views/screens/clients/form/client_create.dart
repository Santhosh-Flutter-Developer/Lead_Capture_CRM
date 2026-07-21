import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '/utils/src/pick_image.dart' show xFileToUploadUrl;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';

class ContactCreate extends StatefulWidget {
  const ContactCreate({super.key});

  @override
  State<ContactCreate> createState() => _ContactCreateState();
}

class _ContactCreateState extends State<ContactCreate> {
  final _formKey = GlobalKey<FormState>();

  final _clientName = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();

  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  String? _salutation;
  String? _gender;

  final bool _loginAllowed = true;
  final bool _emailNotify = true;

  @override
  void dispose() {
    _clientName.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
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
        body: SingleChildScrollView(
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  FormWidgets.buildHeader(
                    context: context,
                    title: "Create Contact",
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: "Contact Details",
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildContactFormFields(constraints, 4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: "Profile Photo",
                    child: Center(child: _buildProfileUploader()),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submit,
          isEdit: false,
        ),
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

  Widget _buildContactFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;
    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
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
            onChanged: (v) => _salutation = v,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Name",
            controller: _clientName,
            isRequired: true,
            valid: (input) =>
                Validation.validName(input: input, label: 'Name', isReq: true),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Email",
            controller: _email,
            // isRequired: true,
            valid: (input) => Validation.validEmail(input: input, isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Mobile",
            controller: _mobile,
            valid: (input) =>
                Validation.validMobileNumber(input: input, isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: "Gender",
            items: const ["Male", "Female", "Other"],
            onChanged: (v) => _gender = v,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileUploader() {
    if (_profileImage != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () async {
              final result = await PickImage.pickFromGallery();
              if (result != null) {
                setState(() => _profileImage = result);
                if (kIsWeb) {
                  result.readAsBytes().then(
                    (b) => setState(() => _profileImageBytes = b),
                  );
                }
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.memory(
                      _profileImageBytes ?? Uint8List(0),
                      height: 130,
                      width: 130,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_profileImage!.path),
                      height: 130,
                      width: 130,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _profileImage = null;
                  _profileImageBytes = null;
                });
              },
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
        if (result != null) {
          setState(() => _profileImage = result);
          if (kIsWeb)
            result.readAsBytes().then(
              (b) => setState(() => _profileImageBytes = b),
            );
        }
      },
      child: DottedBorder(
        options: RectDottedBorderOptions(),
        child: Container(
          height: 130,
          width: 130,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  "Upload Photo",
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

  Future<void> _submit() async {
    try {
      if (!_formKey.currentState!.validate()) return;

      futureLoading(context);

      final imageUrl = _profileImage == null
          ? null
          : await xFileToUploadUrl(_profileImage!, StorageFolder.clientPhotos);

      final client = ClientModel(
        salutation: _salutation,
        clientName: _clientName.text.trim(),
        email: _email.text.trim(),
        mobileNumber: _mobile.text,
        gender: _gender,
        loginAllowed: _loginAllowed,
        receiveEmailNotifications: _emailNotify,
        profilePictureUrl: imageUrl,
        createdBy: await Spdb.getUser(),
        isCompany: false,
      );

      await ClientService.createClient(client: client);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, {"status": true, "contact": client});
      FlushBar.show(context, "Contact created", isSuccess: true);
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}

class CompanyCreate extends StatefulWidget {
  const CompanyCreate({super.key});

  @override
  State<CompanyCreate> createState() => _CompanyCreateState();
}

class _CompanyCreateState extends State<CompanyCreate> {
  final _formKey = GlobalKey<FormState>();

  final _companyName = TextEditingController();
  final _website = TextEditingController();
  final _gst = TextEditingController();
  final _phone = TextEditingController();
  final _postal = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  XFile? _logo;
  Uint8List? _logoBytes;

  @override
  void dispose() {
    _companyName.dispose();
    _website.dispose();
    _gst.dispose();
    _phone.dispose();
    _postal.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
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
        body: SingleChildScrollView(
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  FormWidgets.buildHeader(
                    context: context,
                    title: "Create Company",
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: "Company Information",
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildCompanyFormFields(constraints, 4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: "Company Logo",
                    child: Center(child: _buildLogoUploader()),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submit,
          isEdit: false,
        ),
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

  Widget _buildCompanyFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;
    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
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
            isRequired: true,
            valid: (input) => Validation.commonValidation(
              input: input,
              label: 'Company Name',
              isReq: true,
            ),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Website",
            controller: _website,
            valid: (input) =>
                Validation.validUrl(input: input ?? '', isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "GST / VAT",
            controller: _gst,
            valid: (input) =>
                Validation.validGstVat(input: input, isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Office Phone",
            controller: _phone,
            valid: (input) =>
                Validation.validMobileNumber(input: input, isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Postal Code",
            controller: _postal,
            isRequired: true,
            valid: (input) =>
                Validation.validPostalCode(input: input, isReq: true),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Company Address",
            controller: _address,
            maxLines: 2,
            isRequired: true,
            valid: (input) =>
                Validation.validAddress(input: input ?? '', isReq: true),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(label: "Note", controller: _note, maxLines: 2),
        ),
      ],
    );
  }

  Widget _buildLogoUploader() {
    if (_logo != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () async {
              final result = await PickImage.pickFromGallery();
              if (result != null) {
                setState(() => _logo = result);
                if (kIsWeb) {
                  result.readAsBytes().then(
                    (b) => setState(() => _logoBytes = b),
                  );
                }
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.memory(
                      _logoBytes ?? Uint8List(0),
                      height: 130,
                      width: 130,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_logo!.path),
                      height: 130,
                      width: 130,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _logo = null;
                  _logoBytes = null;
                });
              },
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
        if (result != null) {
          setState(() => _logo = result);
          if (kIsWeb)
            result.readAsBytes().then((b) => setState(() => _logoBytes = b));
        }
      },
      child: DottedBorder(
        options: RectDottedBorderOptions(),
        child: Container(
          height: 130,
          width: 130,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  "Upload Logo",
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

  Future<void> _submit() async {
    try {
      if (!_formKey.currentState!.validate()) return;

      futureLoading(context);

      final logoUrl = _logo == null
          ? null
          : await xFileToUploadUrl(_logo!, StorageFolder.clientCompanyLogos);

      final company = ClientModel(
        companyName: _companyName.text.trim(),
        officialWebsite: _website.text.trim(),
        gstVatNumber: _gst.text.trim(),
        officePhoneNo: _phone.text.trim(),
        postalCode: _postal.text.trim(),
        companyAddress: _address.text.trim(),
        notes: _note.text.trim(),
        companyLogoUrl: logoUrl,
        createdBy: await Spdb.getUser(),
        isCompany: true,
      );

      await ClientService.createClient(client: company);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, {"status": true, "company": company});
      FlushBar.show(context, "Company created", isSuccess: true);
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}
