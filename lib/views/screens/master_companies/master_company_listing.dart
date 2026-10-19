import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';

const double _wideBreakpoint = 900;

/// Master Company list: company details (logo, GST/VAT, address) with its
/// primary contact. Create / edit / delete / export / view follow the role.
class MasterCompanyListing extends StatefulWidget {
  const MasterCompanyListing({super.key});

  @override
  State<MasterCompanyListing> createState() => _MasterCompanyListingState();
}

class _MasterCompanyListingState extends State<MasterCompanyListing> {
  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  late final PaginatedDataController<MasterCompanyModel> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  List<MasterCompanyModel> _all = [];
  PermissionModel? _permissions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<MasterCompanyModel>(
      initialSortColumnIndex: 0,
      filterLogic: (c, query) {
        final q = query.toLowerCase();
        return c.companyName.toLowerCase().contains(q) ||
            c.contactName.toLowerCase().contains(q) ||
            c.mobileNumber.toLowerCase().contains(q) ||
            (c.email ?? '').toLowerCase().contains(q) ||
            (c.gstVatNumber ?? '').toLowerCase().contains(q);
      },
      sortLogic: (a, b, col, asc) {
        int compare;
        switch (col) {
          case 0:
            compare = a.companyName.toLowerCase().compareTo(
              b.companyName.toLowerCase(),
            );
            break;
          case 1:
            compare = a.contactName.toLowerCase().compareTo(
              b.contactName.toLowerCase(),
            );
            break;
          default:
            compare = (a.uid ?? '').compareTo(b.uid ?? '');
        }
        return asc ? compare : -compare;
      },
      getItemId: (c) => c.uid ?? '',
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  /// Refresh button: show the loader, then reload clients, stats and
  /// permissions (the search text stays as typed).
  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _load() async {
    try {
      _permissions = await PermissionService.getPermissions('Master Company');
      final clients = await MasterCompanyService.getAll();
      if (!mounted) return;
      _all = clients;
      _controller.setData(clients);
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  Future<void> _openForm(BuildContext context, {String? uid}) async {
    final form = MasterCompanyForm(uid: uid);
    dynamic val;
    if (_isWide(context)) {
      val = await GeneralDialog.showRTLSheet(context, form);
    } else {
      val = await Sheet.showSheet(context, widget: form);
    }
    if (val is Map && val['status'] == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text('Master Company'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const WaitingLoading();
          if (_error != null) {
            return Center(
              child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            );
          }
          if (!(_permissions?.canView ?? false)) {
            return buildNoPermissionView(context);
          }
          return ChangeNotifierProvider<PaginatedDataController<MasterCompanyModel>>.value(
            value: _controller,
            child: Consumer<PaginatedDataController<MasterCompanyModel>>(
              builder: (context, controller, _) => RefreshIndicator(
                onRefresh: _load,
                child: Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _vScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      if (isWide) ...[
                        _banner(context),
                        const SizedBox(height: 20),
                      ],
                      _toolbar(context, controller, isWide),
                      const SizedBox(height: 18),
                      controller.paginatedItems.isEmpty
                          ? NoData(
                              text: _all.isEmpty
                                  ? 'No master companies available'
                                  : 'No matching records found',
                            )
                          : _tableCard(context, controller),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Iconsax.building_4, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master Company',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your company details and primary contacts in one place',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '${_all.length}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Companies',
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

  Widget _toolbar(
    BuildContext context,
    PaginatedDataController<MasterCompanyModel> controller,
    bool isWide,
  ) {
    final selected = controller.selectedIds.length;
    final buttons = <Widget>[
      if (_permissions?.canCreate ?? false)
        FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Master Company'),
        ),
      if ((_permissions?.canExport ?? false) &&
          controller.paginatedItems.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _export(context, controller),
          icon: const Icon(Iconsax.export_3, size: 18),
          label: const Text('Export'),
        ),
      if (selected > 0 && (_permissions?.canDelete ?? false))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => _bulkDelete(context, controller),
          icon: const Icon(Iconsax.trash, size: 18),
          label: Text('Delete ($selected)'),
        ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: const Icon(Iconsax.refresh),
      ),
    ];

    final search = SizedBox(
      width: isWide ? 300 : double.infinity,
      child: TextField(
        onChanged: controller.setSearch,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search company, contact, mobile, email, GST',
          prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: isWide
          ? Row(
              children: [
                search,
                const Spacer(),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            ),
    );
  }

  Widget _tableCard(
    BuildContext context,
    PaginatedDataController<MasterCompanyModel> controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: LayoutBuilder(
              builder: (context, constraints) => Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: true,
                      sortColumnIndex: controller.sortColumnIndex,
                      sortAscending: controller.sortAscending,
                      headingRowColor: WidgetStateProperty.all(
                        scheme.primary.withValues(alpha: 0.06),
                      ),
                      headingTextStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                      columns: [
                        DataColumn(
                          label: const Text('Company'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Contact'),
                          onSort: controller.setSort,
                        ),
                        const DataColumn(label: Text('Mobile')),
                        const DataColumn(label: Text('Email')),
                        const DataColumn(label: Text('GST/VAT')),
                        const DataColumn(label: Text('Created By')),
                        const DataColumn(label: Text('Action')),
                      ],
                      rows: controller.paginatedItems
                          .map((c) => _row(context, c, controller))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<MasterCompanyModel>(),
          ),
        ],
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    MasterCompanyModel c,
    PaginatedDataController<MasterCompanyModel> controller,
  ) {
    final style = Theme.of(context).textTheme.bodySmall;
    return DataRow(
      selected: controller.selectedIds.contains(c.uid),
      onSelectChanged: (v) => controller.onSelected(c.uid!, v),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: (c.logoUrl ?? '').isNotEmpty
                    ? NetworkImage(c.logoUrl!)
                    : null,
                child: (c.logoUrl ?? '').isNotEmpty
                    ? null
                    : Text(
                        c.companyName.isNotEmpty
                            ? c.companyName[0].toUpperCase()
                            : '?',
                        style: style?.copyWith(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 10),
              Text(
                c.companyName,
                style: style?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          onTap: (_permissions?.canEdit ?? false)
              ? () => _openForm(context, uid: c.uid)
              : null,
        ),
        DataCell(Text(c.contactName.isNotEmpty ? c.contactName : '-', style: style)),
        DataCell(Text(c.mobileNumber.isNotEmpty ? c.mobileNumber : '-', style: style)),
        DataCell(Text((c.email ?? '').isNotEmpty ? c.email! : '-', style: style)),
        DataCell(Text((c.gstVatNumber ?? '').isNotEmpty ? c.gstVatNumber! : '-', style: style)),
        DataCell(CreatedByWidget(userData: c.createdBy)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_permissions?.canEdit ?? false)
                IconButton(
                  tooltip: 'Edit',
                  color: AppColors.info,
                  icon: const Icon(Iconsax.edit),
                  onPressed: () => _openForm(context, uid: c.uid),
                ),
              if (_permissions?.canDelete ?? false)
                IconButton(
                  tooltip: 'Delete',
                  color: AppColors.danger,
                  icon: const Icon(Iconsax.trash),
                  onPressed: () => _delete(context, c),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    PaginatedDataController<MasterCompanyModel> controller,
  ) async {
    try {
      final rows = <List<String>>[
        [
          'Company',
          'GST/VAT',
          'Contact Name',
          'Mobile Number',
          'Email',
          'Address',
          'Created By',
        ],
        for (final c in controller.paginatedItems)
          [
            c.companyName,
            c.gstVatNumber ?? '',
            c.contactName,
            c.mobileNumber,
            c.email ?? '',
            c.companyAddress ?? '',
            c.createdBy.name,
          ],
      ];
      final bytes = await XlsxWriter().create(rows);
      final path = await saveFileToDownloads(
        bytes,
        fileName: 'Master Company List.xlsx',
      );
      if (!kIsWeb && context.mounted) openfile(path, context);
    } catch (e) {
      if (!context.mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Master Company',
        content: count == 1
            ? 'Are you sure you want to delete this master company?'
            : 'Are you sure you want to delete $count master companies?',
      ),
    );
    return ok == true;
  }

  Future<void> _delete(BuildContext context, MasterCompanyModel c) async {
    if (!context.mounted || !await _confirmDelete(context, 1)) return;
    try {
      final deleted = c.copyWith();
      futureLoading(context);
      try {
        await MasterCompanyService.delete(uid: c.uid ?? '');
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      await _load();
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Master company deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await MasterCompanyService.restore(deleted);
          await _load();
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }

  Future<void> _bulkDelete(
    BuildContext context,
    PaginatedDataController<MasterCompanyModel> controller,
  ) async {
    final chosen = _all
        .where((c) => controller.selectedIds.contains(c.uid))
        .toList();
    if (chosen.isEmpty) return;
    if (!context.mounted || !await _confirmDelete(context, chosen.length)) {
      return;
    }
    try {
      final deleted = chosen.map((e) => e.copyWith()).toList();
      futureLoading(context);
      try {
        for (final c in chosen) {
          await MasterCompanyService.delete(uid: c.uid ?? '');
        }
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      controller.clearSelection();
      await _load();
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Master companies deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (final c in deleted) {
            await MasterCompanyService.restore(c);
          }
          await _load();
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }
}