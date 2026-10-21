import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';
import '/views/screens/project_updations/project_updation_form.dart'
    show masterClientLabel;

/// A completed deal shown in the Projects dropdown.
class _Proj {
  final String uid;
  final String label;
  final double dealValue;
  const _Proj(this.uid, this.label, this.dealValue);
}

/// One allocation waiting in the table below the form.
class _Line {
  String? uid; // set when it already exists in Firestore
  ClientModel client;
  _Proj project;
  MasterCompanyModel company;
  double allocated;
  String mode;
  _Line({
    this.uid,
    required this.client,
    required this.project,
    required this.company,
    required this.allocated,
    required this.mode,
  });
}

final NumberFormat _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Payment form. Add several allocations (Master Client, Project, Master
/// Company, Allocate Value, Payment Mode) with the Add button, edit or
/// delete them in the table, then Submit to save them all.
///
/// Per project the allocated total can never exceed its deal value, and a
/// project that already has payments is not offered again. Pass [uid] to
/// edit an existing payment (its project stays available).
class PaymentForm extends StatefulWidget {
  final String? uid;
  const PaymentForm({super.key, this.uid});

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _vScroll = ScrollController();

  final _dealValue = TextEditingController();
  final _clientRO = TextEditingController();
  final _projectRO = TextEditingController();
  final _allocate = TextEditingController();
  final _mode = TextEditingController();

  List<ClientModel> _clients = [];
  List<MasterCompanyModel> _companies = [];
  List<PaymentModel> _saved = [];
  List<_Proj> _projects = [];

  ClientModel? _client;
  _Proj? _project;
  MasterCompanyModel? _company;

  final List<_Line> _lines = [];
  final List<String> _removedUids = [];
  // Payments this form opened for editing (still in Firestore until submit).
  final Set<String> _origUids = {};
  int? _editingIndex;
  int _tick = 0; // forces dropdown rebuilds

  late Future<void> _future;

  bool get _isEdit => (widget.uid ?? '').isNotEmpty;

  /// Once any allocation exists, Master Client, Project and Deal Value are
  /// fixed. They unlock again only after every allocation is deleted.
  bool get _locked => _lines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _dealValue.dispose();
    _clientRO.dispose();
    _projectRO.dispose();
    _allocate.dispose();
    _mode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        ClientService.getMasterClients(),
        MasterCompanyService.getAll(),
        PaymentService.getAll(),
      ]);
      _clients = r[0] as List<ClientModel>;
      _companies = r[1] as List<MasterCompanyModel>;
      _saved = r[2] as List<PaymentModel>;

      if (_isEdit) {
        final p = _saved.firstWhere(
          (e) => e.uid == widget.uid,
          orElse: () => throw 'Payment not found',
        );
        final client = _clients.where((c) => c.uid == p.clientId).firstOrNull;
        // Edit every allocation of this project together.
        for (final s in _saved.where((e) => e.projectId == p.projectId)) {
          final company =
              _companies.where((c) => c.uid == s.companyId).firstOrNull;
          if (client == null || company == null) continue;
          if (s.uid != null) _origUids.add(s.uid!);
          _lines.add(
            _Line(
              uid: s.uid,
              client: client,
              project: _Proj(s.projectId, s.projectName, s.dealValue),
              company: company,
              allocated: s.allocatedValue,
              mode: s.paymentMode,
            ),
          );
        }
      }
      _syncLocked();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  /// While locked the entry always targets the first line's client/project.
  void _syncLocked() {
    if (_lines.isEmpty) return;
    _client = _lines.first.client;
    _project = _lines.first.project;
    _dealValue.text = _project!.dealValue.toStringAsFixed(2);
    _clientRO.text = masterClientLabel(_client!);
    _projectRO.text = _project!.label;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Deal value minus every other allocation of that project: lines in the
  /// table (except [excludeIndex]) and saved payments not being edited here.
  double _remaining(_Proj p, {int? excludeIndex}) {
    final editingUids = _lines.map((l) => l.uid).whereType<String>().toSet();
    double used = 0;
    for (final s in _saved) {
      if (s.projectId == p.uid &&
          !editingUids.contains(s.uid) &&
          !_removedUids.contains(s.uid)) {
        used += s.allocatedValue;
      }
    }
    for (var i = 0; i < _lines.length; i++) {
      if (i == excludeIndex) continue;
      if (_lines[i].project.uid == p.uid) used += _lines[i].allocated;
    }
    return p.dealValue - used;
  }

  Future<void> _loadProjects() async {
    final id = _client?.uid;
    if (id == null || id.isEmpty) {
      _projects = [];
      return;
    }
    final deals = await DealService.getCompletedDealsByClient(clientId: id);
    // Projects that already have saved payments are not offered again
    // (except the ones being edited in this form).
    // Payments opened for editing are never treated as "already paid", even
    // after their rows were removed here (they are deleted on submit).
    final editingUids = {
      ..._origUids,
      ..._lines.map((l) => l.uid).whereType<String>(),
    };
    final paid = _saved
        .where((s) => !editingUids.contains(s.uid))
        .map((s) => s.projectId)
        .toSet();
    String nameOf(DealModel d) =>
        (d.projectName ?? '').trim().isEmpty ? d.dealName : d.projectName!;
    final counts = <String, int>{};
    for (final d in deals) {
      counts[nameOf(d)] = (counts[nameOf(d)] ?? 0) + 1;
    }
    _projects = [
      for (final d in deals)
        if (d.uid != null && !paid.contains(d.uid))
          _Proj(
            d.uid!,
            counts[nameOf(d)]! > 1 && d.dealNumber != null
                ? '${nameOf(d)} (#${d.dealNumber})'
                : nameOf(d),
            d.dealValue,
          ),
    ];
    // Keep a project that is being edited selectable.
    for (final l in _lines) {
      if (l.client.uid == id && !_projects.any((p) => p.uid == l.project.uid)) {
        _projects.add(l.project);
      }
    }
  }

  Future<void> _onClientChanged(ClientModel? c) async {
    _client = c;
    _project = null;
    _dealValue.clear();
    try {
      await _loadProjects();
    } catch (e) {
      if (mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
    if (mounted) setState(() {});
  }

  void _onProjectChanged(_Proj? p) {
    _project = p;
    _dealValue.text = p == null ? '' : p.dealValue.toStringAsFixed(2);
    setState(() {});
  }

  void _resetEntry({bool keepProject = false}) {
    _editingIndex = null;
    _company = null;
    _allocate.clear();
    _mode.clear();
    if (!keepProject) {
      _project = null;
      _dealValue.clear();
    }
    _tick++;
  }

  Widget _plusButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
    );
  }

  Future<dynamic> _openSheet(Widget form) {
    if (kIsMobile) return Sheet.showSheet(context, widget: form);
    return GeneralDialog.showRTLSheet(context, form);
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _addOrUpdate() {
    if (!_formKey.currentState!.validate()) return;
    final client = _client!;
    final project = _project!;
    final company = _company!;
    final amount = double.parse(_allocate.text.trim());
    final left = _remaining(project, excludeIndex: _editingIndex);
    if (amount > left + 0.0001) {
      FlushBar.show(
        context,
        'Allocated value exceeds the deal value. Remaining: ${_money.format(left)}',
        isSuccess: false,
      );
      return;
    }
    setState(() {
      if (_editingIndex != null) {
        final l = _lines[_editingIndex!];
        l.client = client;
        l.project = project;
        l.company = company;
        l.allocated = amount;
        l.mode = _mode.text.trim();
      } else {
        _lines.add(
          _Line(
            client: client,
            project: project,
            company: company,
            allocated: amount,
            mode: _mode.text.trim(),
          ),
        );
      }
      _resetEntry(keepProject: true);
      _syncLocked();
    });
  }

  Future<void> _editLine(int i) async {
    final l = _lines[i];
    setState(() {
      _editingIndex = i;
      _syncLocked();
      _company = l.company;
      _allocate.text = l.allocated.toString();
      _mode.text = l.mode;
      _tick++;
    });
  }

  void _deleteLine(int i) {
    setState(() {
      final l = _lines.removeAt(i);
      if (l.uid != null) _removedUids.add(l.uid!);
      if (_editingIndex != null) _resetEntry(keepProject: _lines.isNotEmpty);
      if (_lines.isEmpty) {
        // Nothing allocated any more: client and project may change again.
        _client = null;
        _project = null;
        _projects = [];
        _dealValue.clear();
        _tick++;
      } else {
        _syncLocked();
      }
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      FlushBar.show(
        context,
        'Add at least one payment allocation first',
        isSuccess: false,
      );
      return;
    }
    try {
      futureLoading(context);
      final user = await Spdb.getUser();
      final existing = {for (final s in _saved) s.uid: s};
      final models = [
        for (final l in _lines)
          PaymentModel(
            uid: l.uid,
            clientId: l.client.uid ?? '',
            clientLabel: masterClientLabel(l.client),
            projectId: l.project.uid,
            projectName: l.project.label,
            dealValue: l.project.dealValue,
            companyId: l.company.uid ?? '',
            companyName: l.company.companyName,
            allocatedValue: l.allocated,
            paymentMode: l.mode,
            createdBy: existing[l.uid]?.createdBy ?? user,
            createdAt: existing[l.uid]?.createdAt,
          ),
      ];
      await PaymentService.save(lines: models, removeUids: _removedUids);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, {"status": true});
      FlushBar.show(
        context,
        _isEdit ? 'Payment updated' : 'Payments added',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

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
                  title: _isEdit ? 'Edit Payment' : 'Add Payment',
                  subtitle: 'Allocate a completed deal across master companies',
                  icon: Iconsax.wallet_3,
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _vScroll,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Form(
                            key: _formKey,
                            child: LeadFormUI.sectionCard(
                              context,
                              title: 'Payment Details',
                              child: LayoutBuilder(
                                builder: (context, c) => _fields(c),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          LeadFormUI.sectionCard(
                            context,
                            title: 'Allocations (${_lines.length})',
                            child: _table(context),
                          ),
                        ],
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

  Widget _fields(BoxConstraints constraints) {
    const double spacing = 16.0;
    const int gridCounts = 2;
    final canGrid =
        constraints.maxWidth >= (220.0 * gridCounts + spacing * (gridCounts - 1));
    final itemWidth = canGrid
        ? (constraints.maxWidth - spacing * (gridCounts - 1)) / gridCounts
        : constraints.maxWidth;
    Widget box(Widget child) => SizedBox(width: itemWidth, child: child);

    final remaining = _project == null
        ? null
        : _remaining(_project!, excludeIndex: _editingIndex);

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        // Master Client (+) - read-only once an allocation exists
        box(
          _locked
              ? FormFields(
                  key: ValueKey('client_ro_${_client?.uid}'),
                  label: 'Master Clients',
                  controller: _clientRO,
                  readOnly: true,
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
                  key: ValueKey('client_${_clients.length}_${_client?.uid}_$_tick'),
                  label: 'Master Clients',
                  isRequired: true,
                  initialItem: _client == null ? null : masterClientLabel(_client!),
                  items: _clients.map(masterClientLabel).toList(),
                  onChanged: (v) => _onClientChanged(
                    _clients.where((c) => masterClientLabel(c) == v).firstOrNull,
                  ),
                  validator: (v) => v == null ? '* Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              _plusButton(() async {
                final val = await _openSheet(const MasterClientForm());
                if (val is Map && val['status'] == true) {
                  _clients = await ClientService.getMasterClients();
                  if (val['client'] is ClientModel) {
                    await _onClientChanged(val['client'] as ClientModel);
                  } else if (mounted) {
                    setState(() {});
                  }
                }
              }),
            ],
          ),
        ),
        // Projects = the client's completed, not-yet-allocated deals
        box(
          _locked
              ? FormFields(
                  key: ValueKey('proj_ro_${_project?.uid}'),
                  label: 'Projects',
                  controller: _projectRO,
                  readOnly: true,
                )
              : FormDropdownSearch(
            key: ValueKey('proj_${_client?.uid}_${_projects.length}_${_project?.uid}_$_tick'),
            label: 'Projects',
            isRequired: true,
            initialItem: _project?.label,
            items: _projects.map((p) => p.label).toList(),
            onChanged: (v) => _onProjectChanged(
              _projects.where((p) => p.label == v).firstOrNull,
            ),
            validator: (v) {
              if (_client == null) return '* Select a master client first';
              if (_projects.isEmpty) return '* No completed deals to allocate';
              return v == null ? '* Required' : null;
            },
          ),
        ),
        // Deal Value (auto-fetched)
        box(
          FormFields(
            label: 'Deal Value',
            controller: _dealValue,
            readOnly: true,
            hintText: 'Select a project',
          ),
        ),
        // Master Company (+)
        box(
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
                  key: ValueKey('comp_${_companies.length}_${_company?.uid}_$_tick'),
                  label: 'Master Company',
                  isRequired: true,
                  initialItem: _company?.companyName,
                  items: _companies.map((c) => c.companyName).toList(),
                  onChanged: (v) => _company = _companies
                      .where((c) => c.companyName == v)
                      .firstOrNull,
                  validator: (v) => v == null ? '* Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              _plusButton(() async {
                final val = await _openSheet(const MasterCompanyForm());
                if (val is Map && val['status'] == true) {
                  _companies = await MasterCompanyService.getAll();
                  if (val['company'] is MasterCompanyModel) {
                    _company = val['company'] as MasterCompanyModel;
                  }
                  if (mounted) setState(() => _tick++);
                }
              }),
            ],
          ),
        ),
        // Allocate Value
        box(
          FormFields(
            label: 'Allocate Value',
            controller: _allocate,
            hintText: remaining == null
                ? 'Enter amount'
                : 'Remaining ${_money.format(remaining)}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isRequired: true,
            valid: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return '* Allocate value is required';
              final n = double.tryParse(t);
              if (n == null || n <= 0) return 'Enter a valid amount';
              if (_project != null) {
                final left = _remaining(_project!, excludeIndex: _editingIndex);
                if (n > left + 0.0001) {
                  return "Can't exceed remaining ${_money.format(left)}";
                }
              }
              return null;
            },
          ),
        ),
        // Payment Mode
        box(
          FormFields(
            label: 'Payment Mode',
            controller: _mode,
            hintText: 'e.g. Cash, UPI, Bank Transfer',
            isRequired: true,
            valid: (v) =>
                (v == null || v.trim().isEmpty) ? '* Payment mode is required' : null,
          ),
        ),
        SizedBox(
          width: constraints.maxWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                if (_editingIndex != null)
                  OutlinedButton(
                    onPressed: () => setState(() => _resetEntry(keepProject: _locked)),
                    child: const Text('Cancel'),
                  ),
                FilledButton.icon(
                  onPressed: _addOrUpdate,
                  icon: Icon(
                    _editingIndex == null ? Icons.add_rounded : Icons.check_rounded,
                    size: 18,
                  ),
                  label: Text(_editingIndex == null ? 'Add' : 'Update'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    if (_lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'No allocations added yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final style = Theme.of(context).textTheme.bodySmall;
    // Per-project totals so it is clear how much of each deal is allocated.
    final totals = <String, double>{};
    final projects = <String, _Proj>{};
    for (final l in _lines) {
      totals[l.project.uid] = (totals[l.project.uid] ?? 0) + l.allocated;
      projects[l.project.uid] = l.project;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Master Client')),
              DataColumn(label: Text('Project')),
              DataColumn(label: Text('Deal Value'), numeric: true),
              DataColumn(label: Text('Master Company')),
              DataColumn(label: Text('Allocated'), numeric: true),
              DataColumn(label: Text('Payment Mode')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (var i = 0; i < _lines.length; i++)
                DataRow(
                  selected: _editingIndex == i,
                  cells: [
                    DataCell(Text(masterClientLabel(_lines[i].client), style: style)),
                    DataCell(Text(_lines[i].project.label, style: style)),
                    DataCell(Text(_money.format(_lines[i].project.dealValue), style: style)),
                    DataCell(Text(_lines[i].company.companyName, style: style)),
                    DataCell(Text(_money.format(_lines[i].allocated), style: style)),
                    DataCell(Text(_lines[i].mode, style: style)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Iconsax.edit, size: 18),
                            onPressed: () => _editLine(i),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Iconsax.trash, size: 18),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _deleteLine(i),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final id in totals.keys)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${projects[id]!.label}: allocated ${_money.format(totals[id])} of '
              '${_money.format(projects[id]!.dealValue)}',
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}