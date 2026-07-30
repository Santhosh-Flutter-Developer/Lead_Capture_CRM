import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '/models/models.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/views/views.dart';

class DealEdit extends StatefulWidget {
  final String uid;
  const DealEdit({super.key, required this.uid});

  @override
  State<DealEdit> createState() => _DealEditState();
}

class _DealEditState extends State<DealEdit> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _dealNameController = TextEditingController();
  final TextEditingController _dealEmailController = TextEditingController();

  final TextEditingController _dealValueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyWebsiteController =
      TextEditingController();
  final TextEditingController _companyMobileController =
      TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();
  final TextEditingController _companyZipController = TextEditingController();
  final TextEditingController _clientName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _salutation = TextEditingController();
  final TextEditingController _gender = TextEditingController();

  bool _allowFollowUp = true;
  bool _showCompanyDetails = false;

  late Future _future;
  late DealModel _dealModel;

  List<DealStatusModel> _dealStatus = [];
  DealStatusModel? _dealStatusModel;
  List<ClientModel> _clients = [];
  List<ClientModel> _contacts = [];
  ClientModel? _selectedclient;
  ClientModel? _selectedContact;

  RegionModel? _regionModel;
  StateModel? _stateModel;
  CityModel? _cityModel;
  final List<File> _selectedAttachments = [];
  List<FileModel> _uploadedAttachments = [];

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init({
    bool refreshStatus = false,
    bool refreshCompany = false,
    bool refreshContact = false,
  }) async {
    try {
      if (refreshStatus) {
        _dealStatus.clear();
        _dealStatus.addAll(await DealStatusService.getAllDealStatus());
        return;
      }
      if (refreshCompany) {
        _clients = (await ClientService.getAllClients())
            .where((c) => c.isCompany && (c.companyName?.isNotEmpty ?? false))
            .toList();
        return;
      }
      if (refreshContact) {
        _contacts = (await ClientService.getAllClients())
            .where(
              (c) =>
                  c.isCompany == false && (c.clientName?.isNotEmpty ?? false),
            )
            .toList();
        return;
      }
      _dealModel = await DealService.getDeal(uid: widget.uid);

      _dealNameController.text = _dealModel.dealName;
      _dealEmailController.text = _dealModel.dealEmail;
      _dealValueController.text = _dealModel.dealValue.toString();
      _notesController.text = _dealModel.notes;
      _companyNameController.text = _dealModel.companyName ?? '';
      _companyWebsiteController.text = _dealModel.companyWebsite ?? '';
      _companyMobileController.text = _dealModel.companyMobile ?? '';
      _companyAddressController.text = _dealModel.companyAddress ?? '';
      _companyZipController.text = _dealModel.companyZipCode ?? '';
      _clientName.text = _dealModel.clientName ?? '';
      _email.text = _dealModel.clientEmail ?? '';
      _mobile.text = _dealModel.clientMobile ?? '';
      _salutation.text = _dealModel.salutation ?? '';
      _gender.text = _dealModel.clientGender ?? '';

      _regionModel = _dealModel.companyCountry;
      _stateModel = _dealModel.companyState;
      _cityModel = _dealModel.companyCity;

      if (_dealModel.dealStatus != null && _dealModel.dealStatus!.isNotEmpty) {
        try {
          _dealStatusModel = await DealStatusService.getDealStatus(
            uid: _dealModel.dealStatus!,
          );
        } catch (e) {
          // If UID fetch fails, try by name
          try {
            _dealStatusModel = await DealStatusService.getByNameOrCreate(
              name: _dealModel.dealStatus!,
            );
          } catch (e2) {
            debugPrint("Failed to resolve deal status: $_dealModel.dealStatus");
          }
        }
      } else {
        _dealStatusModel = null;
      }

      _allowFollowUp = _dealModel.allowFollowUp;
      _uploadedAttachments = _dealModel.attachments;

      _dealStatus = await DealStatusService.getAllDealStatus();
      _clients = (await ClientService.getAllClients())
          .where((c) => c.isCompany && (c.companyName?.isNotEmpty ?? false))
          .toList();
      _contacts = (await ClientService.getAllClients())
          .where(
            (c) => c.isCompany == false && (c.clientName?.isNotEmpty ?? false),
          )
          .toList();
      if (_dealModel.clientId?.isNotEmpty == true) {
        final resolvedClient = await ClientService.getClient(
          uid: _dealModel.clientId!,
        );
        if (resolvedClient.isCompany) {
          _selectedclient = resolvedClient;
        } else {
          _selectedContact = resolvedClient;
        }
      }
      _selectedclient ??= _clients.cast<ClientModel?>().firstWhere(
        (c) => c?.companyName == _dealModel.companyName,
        orElse: () => null,
      );
      _selectedContact ??= _contacts.cast<ClientModel?>().firstWhere(
        (c) => c?.clientName == _dealModel.clientName,
        orElse: () => null,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  @override
  void dispose() {
    _dealNameController.dispose();
    _dealEmailController.dispose();
    _dealValueController.dispose();
    _notesController.dispose();
    _companyNameController.dispose();
    _companyWebsiteController.dispose();
    _companyMobileController.dispose();
    _companyAddressController.dispose();
    _companyZipController.dispose();
    _clientName.dispose();
    _email.dispose();
    _mobile.dispose();
    _gender.dispose();
    _salutation.dispose();
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
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return ErrorDisplay(error: snapshot.error.toString());
            } else {
              return Column(
                children: [
                  FormWidgets.buildHeader(
                    context: context,
                    title: "Update Deals",
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildSectionCard(
                              "Deal Details",
                              LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildDealDetails(constraints, 3),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              "Company Details",
                              LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildCompanyDetails(constraints, 3),
                              ),
                              expandable: true,
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              "Contact Details",
                              LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildContactDetails(constraints, 3),
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildSectionCard(
                              "Attachments",
                              LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildAttachmentDetails(constraints, 3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: true,
        ),
      ),
    );
  }

  Widget _buildDealDetails(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double spacing = 16;
    const double minColumnWidth = 220;

    final bool canGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + spacing * (gridCounts - 1));
    final double itemWidth = canGrid
        ? (currentWidth - spacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Deal Name',
            controller: _dealNameController,
            hintText: 'Enter Deal Name',
            isRequired: true,
            valid: (input) =>
                input == null || input.isEmpty ? '* Deal Name is required' : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: const FormFields(
            label: 'Deal Email',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        SizedBox(
                width: itemWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FormDropdownSearch(
                        key: ValueKey('deal_status_${_dealStatus.length}'),
                        label: 'Deal Status',
                        initialItem: _dealStatusModel?.name,
                        items: _dealStatus.map((e) => e.name).toList(),
                        onChanged: (value) {
                          _dealStatusModel = _dealStatus.firstWhere(
                            (element) => element.name == value,
                          );
                        },
                        validator: (value) =>
                            value == null ? "* Required" : null,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    InkWell(
                      onTap: () async {
                        dynamic val;
                        if (kIsMobile) {
                          val = await Sheet.showSheet(
                            context,
                            widget: const DealStatusCreate(),
                          );
                        } else {
                          val = await GeneralDialog.showRTLSheet(
                            context,
                            const DealStatusCreate(),
                          );
                        }
                        if (val is Map && val["status"] == true) {
                          await _init(refreshStatus: true);
                          setState(() {});
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(5.0),
                          child: Icon(Icons.add),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label:
                'Deal Value ${_regionModel != null ? '(${_regionModel?.currencySymbol})' : ''}',
            controller: _dealValueController,
            hintText: 'Enter Value',
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: 'Allow Follow Up',
            items: const ['Yes', 'No'],
            initialItem: _allowFollowUp ? 'Yes' : 'No',
            onChanged: (value) =>
                _allowFollowUp = value == 'Yes' ? true : false,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Notes',
            controller: _notesController,
            hintText: 'Enter notes...',
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildContactDetails(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double spacing = 16.0;
    const double minWidth = 220.0;
    final bool canGrid =
        currentWidth >= (minWidth * gridCounts + spacing * (gridCounts - 1));
    final double itemWidth = canGrid
        ? (currentWidth - spacing * (gridCounts - 1)) / gridCounts
        : currentWidth;
    return Wrap(
      spacing: spacing,
      runSpacing: 10,
      children: [
        SizedBox(
                width: itemWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FormDropdownSearch(
                        key: ValueKey('contact_${_contacts.length}'),
                        label: 'Name',
                        isRequired: true,
                        initialItem: _clientName.text,
                        items: _contacts.map((e) => e.clientName).toList(),
                        onChanged: (value) {
                          _selectedContact = _contacts
                              .cast<ClientModel?>()
                              .firstWhere(
                                (cat) => cat?.clientName == value,
                                orElse: () => null,
                              );
                          _clientName.text = _selectedContact?.clientName ?? '';
                          _email.text = _selectedContact?.email ?? "";
                          _mobile.text = _selectedContact?.mobileNumber ?? "";
                          _salutation.text = _selectedContact?.salutation ?? '';
                          _gender.text = _selectedContact?.gender ?? '';
                        },
                        validator: (value) =>
                            value == null ? "* Required" : null,
                      ),
                    ),
                    SizedBox(width: 8.0),
                    InkWell(
                      onTap: () async {
                        final form = ContactCreate();
                        dynamic val;
                        if (kIsMobile) {
                          val = await Sheet.showSheet(context, widget: form);
                        } else {
                          val = await GeneralDialog.showRTLSheet(context, form);
                        }
                        if (val is Map && val["status"] == true) {
                          await _init(refreshContact: true);
                          if (val["contact"] != null) {
                            _selectedContact = val["contact"];
                            _clientName.text =
                                _selectedContact?.clientName ?? '';
                            _email.text = _selectedContact?.email ?? "";
                            _mobile.text = _selectedContact?.mobileNumber ?? "";
                            _salutation.text =
                                _selectedContact?.salutation ?? '';
                            _gender.text = _selectedContact?.gender ?? '';
                          }
                          setState(() {});
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            key: ValueKey(_salutation.text),
            label: "Salutation",
            initialItem: _salutation.text,
            items: const ["Mr.", "Mrs.", "Ms.", "Dr."],
            onChanged: (v) => _salutation.text = v,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Email",
            controller: _email,
            valid: (input) {
              if (input == null || input.isEmpty) {
                return null; // Not required
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Mobile",
            controller: _mobile,
            isRequired: true,
            valid: (input) {
              if (input == null || input.isEmpty) {
                return '* Mobile is required';
              }
              if (!RegExp(r'^\d+$').hasMatch(input)) {
                return 'Mobile must contain only digits';
              }
              if (input.length != 10) {
                return 'Mobile must be exactly 10 digits';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: "Gender",
            key: ValueKey(_gender.text),
            initialItem: _gender.text,
            items: const ["Male", "Female", "Other"],
            onChanged: (v) => _gender.text = v,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyDetails(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double spacing = 16;
    const double minColumnWidth = 220;

    final bool canGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + spacing * (gridCounts - 1));
    final double itemWidth = canGrid
        ? (currentWidth - spacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        SizedBox(
                width: itemWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FormDropdownSearch(
                        key: ValueKey('company_${_clients.length}'),
                        label: 'Company Name',
                        isRequired: true,
                        initialItem: _selectedclient?.companyName,
                        items: _clients.map((e) => e.companyName).toList(),
                        onChanged: (value) {
                          _selectedclient = _clients
                              .cast<ClientModel?>()
                              .firstWhere(
                                (cat) => cat?.companyName == value,
                                orElse: () => null,
                              );
                          _companyWebsiteController.text =
                              _selectedclient?.officialWebsite ?? '';
                          _companyMobileController.text =
                              _selectedclient?.officePhoneNo ?? "";
                          _regionModel = _selectedclient?.country;
                          _stateModel = _selectedclient?.state;
                          _cityModel = _selectedclient?.city;
                          _companyZipController.text =
                              _selectedclient?.postalCode ?? "";
                          _companyAddressController.text =
                              _selectedclient?.companyAddress ?? "";
                        },
                        validator: (value) =>
                            value == null ? "* Required" : null,
                      ),
                    ),
                    SizedBox(width: 8.0),
                    InkWell(
                      onTap: () async {
                        final form = CompanyCreate();
                        dynamic val;
                        if (kIsMobile) {
                          val = await Sheet.showSheet(context, widget: form);
                        } else {
                          val = await GeneralDialog.showRTLSheet(context, form);
                        }
                        if (val is Map && val["status"] == true) {
                          await _init(refreshCompany: true);
                          if (val["company"] != null) {
                            _selectedclient = val["company"];
                            _companyWebsiteController.text =
                                _selectedclient?.officialWebsite ?? '';
                            _companyMobileController.text =
                                _selectedclient?.officePhoneNo ?? "";
                            _regionModel = _selectedclient?.country;
                            _stateModel = _selectedclient?.state;
                            _cityModel = _selectedclient?.city;
                            _companyZipController.text =
                                _selectedclient?.postalCode ?? "";
                            _companyAddressController.text =
                                _selectedclient?.companyAddress ?? "";
                          }
                          setState(() {});
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(5.0),
                          child: Icon(Icons.add),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Website',
            controller: _companyWebsiteController,
            hintText: 'Enter Website',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Mobile',
            controller: _companyMobileController,
            hintText: 'Enter Mobile',
            keyboardType: TextInputType.phone,
            isRequired: true,
            valid: (input) {
              if (input == null || input.isEmpty) {
                return '* Mobile is required';
              }
              if (!RegExp(r'^\d+$').hasMatch(input)) {
                return 'Mobile must contain only digits';
              }
              if (input.length != 10) {
                return 'Mobile must be exactly 10 digits';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: CustomFutureSearchableDropdown<RegionModel>(
            label: 'Country',
            initialValue: _regionModel,
            asyncItems: () async {
              var countries = await RegionService.getCountries();
              return countries;
            },
            itemAsString: (countries) => countries.name,
            onChanged: (selectedCountry) async {
              _regionModel = selectedCountry;
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: CustomFutureSearchableDropdown<StateModel>(
            label: 'State',
            initialValue: _stateModel,
            asyncItems: () async {
              if (_regionModel == null) return [];
              var states = await RegionService.getStates(
                regionId: _regionModel?.uid ?? '',
              );
              return states;
            },
            itemAsString: (countries) => countries.name,
            onChanged: (selectedState) async {
              _stateModel = selectedState;
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: CustomFutureSearchableDropdown<CityModel>(
            label: 'City',
            initialValue: _cityModel,
            asyncItems: () async {
              if (_regionModel == null || _stateModel == null) return [];
              var cities = await RegionService.getCities(
                regionId: _regionModel?.uid ?? '',
                stateId: _stateModel?.uid ?? '',
              );
              return cities;
            },
            itemAsString: (cities) => cities.name,
            onChanged: (selectedCity) async {
              _cityModel = selectedCity;
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Postal Code',
            controller: _companyZipController,
            hintText: 'Enter Postal Code',
            keyboardType: TextInputType.number,
            valid: (input) {
              if (input == null || input.isEmpty) return null;
              if (!RegExp(r'^\d{6}$').hasMatch(input)) {
                return 'Must be 6 digits';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Address',
            controller: _companyAddressController,
            hintText: 'Enter Address',
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentDetails(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double spacing = 16;
    const double minColumnWidth = 220;

    final bool canGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + spacing * (gridCounts - 1));
    final double itemWidth = canGrid
        ? (currentWidth - spacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Attachments",
            hintText: "Tap to select files",
            suffixIcon: const Icon(Iconsax.document_upload),
            readOnly: true,
            onTap: () async {
              var files = await FilePick.pickFiles(context);
              if (files != null && files.isNotEmpty) {
                _selectedAttachments.addAll(files as Iterable<File>);
                setState(() {});
              }
            },
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          children: [..._selectedAttachments, ..._uploadedAttachments].map((
            file,
          ) {
            return Chip(
              label: file is File
                  ? Text(
                      path.basename(file.path),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : file is FileModel
                  ? Text(
                      file.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : const SizedBox(),
              onDeleted: () async {
                if (file is FileModel) {
                  try {
                    futureLoading(context);
                    await StorageService.deleteImage(file.url);
                    _uploadedAttachments.remove(file);
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } catch (e, st) {
                    await ErrorService.recordError(e, st);
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    FlushBar.show(context, e.toString(), isSuccess: false);
                  }
                } else {
                  _selectedAttachments.remove(file);
                }
                setState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    Widget child, {
    bool expandable = false,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 7,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: expandable
                  ? () => setState(
                      () => _showCompanyDetails = !_showCompanyDetails,
                    )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (expandable)
                    Icon(
                      _showCompanyDetails
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                ],
              ),
            ),
            if (!expandable || _showCompanyDetails) ...[
              const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        List<FileModel> attachments = _uploadedAttachments;
        if (_selectedAttachments.isNotEmpty) {
          List<String> urls = await StorageService.uploadFilesInBatch(
            files: _selectedAttachments,
            folder: StorageFolder.dealAttachments,
          );

          for (var i = 0; i < _selectedAttachments.length; i++) {
            var j = _selectedAttachments[i];
            var mimeType = lookupMimeType(j.path) ?? '';

            attachments.add(
              FileModel(
                name: path.basename(j.path),
                extension: path.basename(j.path).split('.').last,
                size: j.lengthSync(),
                url: urls[i],
                mimeType: mimeType,
              ),
            );
          }
        }
        final workflow = await EmployeeService.getUserWorkflow();
        ClientModel clientModel = ClientModel(
          clientName: _clientName.text.trim(),
          email: _email.text.trim(),
          // password: '',
          mobileNumber: _mobile.text.trim(),
          salutation: _salutation.text.trim(),
          gender: _gender.text,
          loginAllowed: false,
          receiveEmailNotifications: false,
          companyName: _companyNameController.text.trim(),
          officePhoneNo: _companyMobileController.text,
          officialWebsite: _companyWebsiteController.text.trim(),
          postalCode: _companyZipController.text.trim(),
          companyAddress: _companyAddressController.text.trim(),
          country: _regionModel,
          state: _stateModel,
          city: _cityModel,
          createdBy: await Spdb.getUser(),
          isCompany: true,
        );

        var clientId = _dealModel.clientId;
        if (clientId != null) {
          await ClientService.editClient(client: clientModel, uid: clientId);
        } else {
          clientId = await ClientService.createClient(client: clientModel);
        }

        final dealModel = _dealModel.copyWith(
          dealName: _dealNameController.text.trim(),
          dealEmail: _dealEmailController.text.trim(),
          dealValue: double.tryParse(_dealValueController.text) ?? 0.0,
          allowFollowUp: _allowFollowUp,
          dealStatus: _dealStatusModel?.uid,
          notes: _notesController.text.trim(),
          attachments: attachments,
          companyName: _companyNameController.text.trim(),
          companyWebsite: _companyWebsiteController.text.trim(),
          companyMobile: _companyMobileController.text.trim(),
          companyAddress: _companyAddressController.text.trim(),
          companyZipCode: _companyZipController.text.trim(),
          clientName: _clientName.text.trim(),
          clientEmail: _email.text.trim(),
          clientGender: _gender.text.trim(),
          clientMobile: _mobile.text.trim(),
          salutation: _salutation.text.trim(),
          companyCountry: _regionModel,
          companyState: _stateModel,
          companyCity: _cityModel,
          workFlow: workflow,
          clientId: clientId,
        );

        await DealService.updateDeal(uid: widget.uid, deal: dealModel);

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);
        FlushBar.show(context, 'Deal updated successfully!', isSuccess: true);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }
}
