import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import '/models/models.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/views/views.dart';

class DealCreate extends StatefulWidget {
  final bool? isFromLead;
  final DealModel? prefillDeal;

  const DealCreate({super.key, this.isFromLead, this.prefillDeal});

  @override
  State<DealCreate> createState() => _DealCreateState();
}

class _DealCreateState extends State<DealCreate> {
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
  final TextEditingController _companyCountryController =
      TextEditingController();
  final TextEditingController _companyStateController = TextEditingController();
  final TextEditingController _companyCityController = TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();
  final TextEditingController _companyZipController = TextEditingController();
  final TextEditingController _clientName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _salutation = TextEditingController();
  final TextEditingController _gender = TextEditingController();

  bool _showCompanyDetails = false;
  late Future _future;
  DealStatusModel? _dealStatusModel;

  bool _allowFollowUp = true;

  final List<DealStatusModel> _dealStatus = [];
  List<ClientModel> _clients = [];
  List<ClientModel> _contacts = [];
  ClientModel? _selectedclient;
  ClientModel? _selectedContact;
  RegionModel? _regionModel;
  StateModel? _stateModel;
  CityModel? _cityModel;

  final List<PlatformFile> _selectedAttachments = [];

  @override
  void initState() {
    _future = _init();
    super.initState();

    if (widget.prefillDeal != null) {
      final deal = widget.prefillDeal!;

      _dealNameController.text = deal.dealName;
      _dealEmailController.text = deal.dealEmail;
      _dealValueController.text = deal.dealValue.toString();
      _notesController.text = deal.notes;

      _companyNameController.text = deal.companyName ?? '';
      _companyWebsiteController.text = deal.companyWebsite ?? '';
      _companyMobileController.text = deal.companyMobile ?? '';
      _companyAddressController.text = deal.companyAddress ?? '';
      _companyZipController.text = deal.companyZipCode ?? '';
      _clientName.text = deal.clientName ?? '';
      _email.text = deal.clientEmail ?? '';
      _mobile.text = deal.clientMobile ?? '';
      _gender.text = deal.clientGender ?? '';
      _salutation.text = deal.salutation ?? '';

      _allowFollowUp = deal.allowFollowUp;
      _regionModel = deal.companyCountry;
      _stateModel = deal.companyState;
      _cityModel = deal.companyCity;

      if (deal.attachments.isNotEmpty) {}
    }
  }

  Future<void> _init({bool refreshStatus = false}) async {
    try {
      if (refreshStatus) {
        _dealStatus.clear();
        _dealStatus.addAll(await DealStatusService.getAllDealStatus());
        return;
      }
      _dealStatus.addAll(await DealStatusService.getAllDealStatus());
      _clients = (await ClientService.getAllClients())
          .where((c) => c.isCompany && (c.companyName?.isNotEmpty ?? false))
          .toList();
      _contacts = (await ClientService.getAllClients())
          .where(
            (c) => c.isCompany == false && (c.clientName?.isNotEmpty ?? false),
          )
          .toList();

      if (widget.prefillDeal?.dealStatus != null) {
        _dealStatusModel = await DealStatusService.getDealStatus(
          uid: widget.prefillDeal!.dealStatus!,
        );
      }

      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  @override
  void dispose() {
    _dealNameController.dispose();
    _dealValueController.dispose();
    _notesController.dispose();
    _companyNameController.dispose();
    _companyWebsiteController.dispose();
    _companyMobileController.dispose();
    _companyCountryController.dispose();
    _companyStateController.dispose();
    _companyCityController.dispose();
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
                    title: "Create Deals",
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
          isEdit: false,
        ),
      ),
    );
  }

  Widget _buildDealDetails(BoxConstraints constraints, int gridCounts) {
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
          child: FormFields(
            label: 'Deal Name',
            controller: _dealNameController,
            isRequired: true,
            hintText: 'e.g. New Business Deal',
            valid: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Deal Email',
            controller: _dealEmailController,
            isRequired: true,
            hintText: 'e.g. email@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label:
                'Deal Value ${_regionModel != null ? '(${_regionModel?.currencySymbol})' : ''}',
            controller: _dealValueController,
            keyboardType: TextInputType.number,
            hintText: 'Enter amount',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: 'Allow Follow Up',
            items: const ['Yes', 'No'],
            initialItem: 'Yes',
            onChanged: (value) =>
                _allowFollowUp = value == 'Yes' ? true : false,
            validator: (value) => value == null ? "* Required" : null,
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
                        label: 'Status',
                        items: _dealStatus.map((e) => e.name).toList(),
                        initialItem: _dealStatusModel?.name,
                        onChanged: (value) {
                          setState(() {
                            _dealStatusModel = _dealStatus.firstWhere(
                              (element) => element.name == value,
                            );
                          });
                        },
                        // validator: (value) => value == null ? "* Required" : null,
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
            label: 'Note',
            controller: _notesController,
            hintText: 'Enter note...',
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
                        label: "Name",
                        isRequired: true,
                        initialItem: _clientName.text,
                        items: _contacts.map((e) => e.clientName).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedContact = _contacts
                                .cast<ClientModel?>()
                                .firstWhere(
                                  (cat) => cat?.clientName == value,
                                  orElse: () => null,
                                );
                            _clientName.text =
                                _selectedContact?.clientName ?? '';
                            _email.text = _selectedContact?.email ?? "";
                            _mobile.text = _selectedContact?.mobileNumber ?? "";
                            _salutation.text =
                                _selectedContact?.salutation ?? '';
                            _gender.text = _selectedContact?.gender ?? '';
                          });
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
                          _contacts = (await ClientService.getAllClients())
                              .where(
                                (c) =>
                                    c.isCompany == false &&
                                    (c.clientName?.isNotEmpty ?? false),
                              )
                              .toList();
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
                          borderRadius: BorderRadius.circular(8.0),
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
            isRequired: true,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(label: "Mobile", controller: _mobile),
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
                        key: ValueKey('company_${_clients.length}'),
                        label: 'Company Name',
                        initialItem: _selectedclient?.companyName ?? "",
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
                          _clients = await ClientService.getAllClients();
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
                          borderRadius: BorderRadius.circular(8.0),
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
          child: FormFields(
            label: 'Website',
            controller: _companyWebsiteController,
            hintText: 'Enter website URL',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Mobile',
            controller: _companyMobileController,
            hintText: 'Enter mobile number',
            keyboardType: TextInputType.phone,
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
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentDetails(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double spacing = 16.0;
    const double minWidth = 220.0;
    final bool canGrid =
        currentWidth >= (minWidth * gridCounts + spacing * (gridCounts - 1));
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
                _selectedAttachments.addAll(files);
                setState(() {});
              }
            },
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          children: _selectedAttachments.map((file) {
            return AttachmentPill(
              name: file.name,
              onRemove: () {
                _selectedAttachments.remove(file);
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        List<FileModel> attachments = [];

        if (_selectedAttachments.isNotEmpty) {
          final fileDataList = await Future.wait(
            _selectedAttachments.map((pf) async {
              final bytes = await platformFileToBytes(pf);
              return (bytes: bytes, fileName: pf.name);
            }),
          );
          List<String> urls = await StorageService.uploadBytesInBatch(
            files: fileDataList,
            folder: StorageFolder.dealAttachments,
          );

          for (var i = 0; i < _selectedAttachments.length; i++) {
            final pf = _selectedAttachments[i];
            final ext = pf.extension ?? '';
            final mimeType = lookupMimeType(pf.name) ?? '';

            attachments.add(
              FileModel(
                name: pf.name,
                extension: ext,
                size: pf.size,
                url: urls[i],
                mimeType: mimeType,
              ),
            );
          }
        }

        final workflow = [await Spdb.getUid() ?? ''];
        ClientModel clientModel = ClientModel(
          clientName: _clientName.text.trim(),
          email: _email.text.trim(),
          // password: '',
          mobileNumber: _mobile.text.trim(),
          salutation: _salutation.text.trim(),
          gender: _gender.text.trim(),
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

        var clientId = await ClientService.createClient(client: clientModel);

        final dealModel = DealModel(
          dealName: _dealNameController.text.trim(),
          dealEmail: _dealEmailController.text.trim(),
          dealValue: double.tryParse(_dealValueController.text) ?? 0,
          allowFollowUp: _allowFollowUp,
          dealStatus: _dealStatusModel?.uid,
          notes: _notesController.text.trim(),
          attachments: attachments,
          companyName: _companyNameController.text.trim(),
          companyWebsite: _companyWebsiteController.text.trim(),
          companyMobile: _companyMobileController.text.trim(),
          companyZipCode: _companyZipController.text.trim(),
          companyAddress: _companyAddressController.text.trim(),
          clientName: _clientName.text.trim(),
          clientEmail: _email.text.trim(),
          clientGender: _gender.text.trim(),
          clientMobile: _mobile.text.trim(),
          salutation: _salutation.text.trim(),
          companyCountry: _regionModel,
          companyState: _stateModel,
          companyCity: _cityModel,
          createdBy: await Spdb.getUser(),
          workFlow: workflow,
          clientId: clientId,
        );

        await DealService.createDeal(deal: dealModel);

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);
        FlushBar.show(context, 'Deal created successfully', isSuccess: true);
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
