import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';

/// Master Client create / edit form.
///
/// A single flat form: saving captures the Company and its Contact together
/// as one Master Client record. Pass [uid] to edit an existing client.
/// Pops with `{"status": true, "client": ClientModel}` on success so that
/// dropdowns (Leads, Deals) can select the new client straight away.
class MasterClientForm extends StatefulWidget {
  final String? uid;
  const MasterClientForm({super.key, this.uid});

  @override
  State<MasterClientForm> createState() => _MasterClientFormState();
}

class _MasterClientFormState extends State<MasterClientForm> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _vScroll = ScrollController();

  final _companyName = TextEditingController();
  final _contactName = TextEditingController();
  final _contactMobile = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _gst = TextEditingController();
  final _officePhone = TextEditingController();

  ClientModel? _client;
  late Future<void> _future;

  bool get _isEdit => (widget.uid ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _companyName.dispose();
    _contactName.dispose();
    _contactMobile.dispose();
    _address.dispose();
    _postal.dispose();
    _gst.dispose();
    _officePhone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_isEdit) return;
    try {
      final c = await ClientService.getClient(uid: widget.uid!);
      _client = c;
      _companyName.text = c.companyName ?? '';
      _contactName.text = c.clientName ?? '';
      _contactMobile.text = c.mobileNumber ?? '';
      _address.text = c.companyAddress ?? '';
      _postal.text = c.postalCode ?? '';
      _gst.text = c.gstVatNumber ?? '';
      _officePhone.text = c.officePhoneNo ?? '';
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
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
            }
            return Column(
              children: [
                LeadFormUI.header(
                  context,
                  title: _isEdit ? 'Edit Master Client' : 'Create Master Client',
                  subtitle: 'Capture the company and its contact once',
                  icon: Iconsax.people,
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _vScroll,
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: LeadFormUI.sectionCard(
                          context,
                          title: 'Client Details',
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _fields(constraints, 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: LeadFormUI.bottomBar(
          context,
          onSubmit: _submit,
          isEdit: _isEdit,
        ),
      ),
    );
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '* $label is required' : null;

  Widget _fields(BoxConstraints constraints, int gridCounts) {
    const double spacing = 16.0;
    const double minWidth = 220.0;
    final canGrid =
        constraints.maxWidth >=
        (minWidth * gridCounts + spacing * (gridCounts - 1));
    final itemWidth = canGrid
        ? (constraints.maxWidth - spacing * (gridCounts - 1)) / gridCounts
        : constraints.maxWidth;

    Widget box(Widget child) => SizedBox(width: itemWidth, child: child);

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        box(
          FormFields(
            label: 'Company Name',
            controller: _companyName,
            hintText: 'Enter company name',
            isRequired: true,
            valid: (v) => _required(v, 'Company name'),
          ),
        ),
        box(
          FormFields(
            label: 'Contact Name',
            controller: _contactName,
            hintText: 'Enter contact person name',
            isRequired: true,
            valid: (v) => _required(v, 'Contact name'),
          ),
        ),
        box(
          FormFields(
            label: 'Contact Mobile',
            controller: _contactMobile,
            hintText: 'Enter 10 digit mobile number',
            keyboardType: TextInputType.phone,
            isRequired: true,
            valid: (input) {
              if (input == null || input.trim().isEmpty) {
                return '* Contact mobile is required';
              }
              if (!RegExp(r'^\d+$').hasMatch(input.trim())) {
                return 'Mobile must contain only digits';
              }
              if (input.trim().length != 10) {
                return 'Mobile must be exactly 10 digits';
              }
              return null;
            },
          ),
        ),
        box(
          FormFields(
            label: 'Office Phone',
            controller: _officePhone,
            hintText: 'Enter office phone',
            keyboardType: TextInputType.phone,
          ),
        ),
        box(
          FormFields(
            label: 'GST/VAT',
            controller: _gst,
            hintText: 'Enter GST / VAT number',
          ),
        ),
        box(
          FormFields(
            label: 'Postal Code',
            controller: _postal,
            hintText: 'Enter postal code',
            keyboardType: TextInputType.number,
            valid: (input) {
              if (input == null || input.trim().isEmpty) return null;
              if (!RegExp(r'^\d{6}$').hasMatch(input.trim())) {
                return 'Must be 6 digits';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: constraints.maxWidth,
          child: FormFields(
            label: 'Company Address',
            controller: _address,
            hintText: 'Enter company address',
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      futureLoading(context);

      late final ClientModel saved;
      if (_isEdit && _client != null) {
        saved = _client!.copyWith(
          companyName: _companyName.text.trim(),
          clientName: _contactName.text.trim(),
          mobileNumber: _contactMobile.text.trim(),
          companyAddress: _address.text.trim(),
          postalCode: _postal.text.trim(),
          gstVatNumber: _gst.text.trim(),
          officePhoneNo: _officePhone.text.trim(),
          isCompany: true,
          updatedAt: DateTime.now(),
        );
        await ClientService.editClient(uid: widget.uid!, client: saved);
      } else {
        final model = ClientModel(
          companyName: _companyName.text.trim(),
          clientName: _contactName.text.trim(),
          mobileNumber: _contactMobile.text.trim(),
          companyAddress: _address.text.trim(),
          postalCode: _postal.text.trim(),
          gstVatNumber: _gst.text.trim(),
          officePhoneNo: _officePhone.text.trim(),
          loginAllowed: false,
          receiveEmailNotifications: false,
          createdBy: await Spdb.getUser(),
          isCompany: true,
        );
        final id = await ClientService.createClient(client: model);
        saved = model.copyWith(uid: id);
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, {"status": true, "client": saved});
      FlushBar.show(
        context,
        _isEdit ? 'Master client updated' : 'Master client created',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}