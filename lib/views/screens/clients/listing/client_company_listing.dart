import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import 'package:provider/provider.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import 'bloc/client_bloc.dart';

const double _wideBreakpoint = 900;

class ClientCompanyListing extends StatelessWidget {
  final ClientSection section;

  const ClientCompanyListing({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClientCompanyBloc()..add(StreamClientCompany()),
      child: ClientCompanyListView(section: section),
    );
  }
}

class ClientCompanyListView extends StatelessWidget {
  final ClientSection section;
  const ClientCompanyListView({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PaginatedDataController<ClientModel>(
        initialSortColumnIndex: 1,
        filterLogic: (client, query) {
          final q = query.toLowerCase();

          if (section == ClientSection.contacts) {
            return (client.clientName ?? '').toLowerCase().contains(q) ||
                (client.email ?? '').toLowerCase().contains(q);
          } else {
            return (client.companyName ?? '').toLowerCase().contains(q) ||
                (client.email ?? '').toLowerCase().contains(q);
          }
        },
        sortLogic: (a, b, col, asc) {
          int compare;
          switch (col) {
            case 0:
              compare = a.clientName!.toLowerCase().compareTo(
                b.clientName!.toLowerCase(),
              );
              break;
            case 1:
              compare = a.email!.toLowerCase().compareTo(
                b.email!.toLowerCase(),
              );
              break;
            case 2:
              compare = (a.companyName!).toLowerCase().compareTo(
                (b.companyName!).toLowerCase(),
              );
              break;
            case 5:
              compare = a.isActive.toString().compareTo(b.isActive.toString());
              break;
            default:
              compare = (a.uid ?? '').compareTo(b.uid ?? '');
              break;
          }
          return asc ? compare : -compare;
        },
        getItemId: (client) => client.uid ?? '',
      ),
      child: ClientCompanyListingView(section: section),
    );
  }
}

class ClientCompanyListingView extends StatefulWidget {
  final ClientSection section;

  const ClientCompanyListingView({super.key, required this.section});

  @override
  State<ClientCompanyListingView> createState() =>
      _ClientCompanyListingViewState();
}

class _ClientCompanyListingViewState extends State<ClientCompanyListingView> {
  final List<ClientModel> _selectedClientCompany = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  final ScrollController _hScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  bool get _isCompanySection => widget.section != ClientSection.contacts;

  String get pageTitle => _isCompanySection ? 'Company' : 'Contact';

  IconData get _sectionIcon =>
      _isCompanySection ? Iconsax.buildings : Iconsax.user;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(pageTitle);
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshClients(BuildContext context) async {
    context.read<ClientCompanyBloc>().add(StreamClientCompany());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = Provider.of<PaginatedDataController<ClientModel>>(
      context,
      listen: false,
    );
    final controllerWatch = Provider.of<PaginatedDataController<ClientModel>>(
      context,
      listen: true,
    );
    final isWide = _isWide(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: Text(pageTitle),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: BlocListener<ClientCompanyBloc, ClientCompanyState>(
        listenWhen: (previous, current) => current is ClientCompanyLoaded,
        listener: (context, state) {
          if (state is ClientCompanyLoaded) {
            final filtered = state.clients.where(_filterBySection).toList();
            controllerRead.setData(filtered);
          }
        },
        child: BlocBuilder<ClientCompanyBloc, ClientCompanyState>(
          builder: (context, state) {
            if (state is ClientCompanyLoading) {
              return const WaitingLoading();
            }

            if (state is ClientCompanyLoaded) {
              final totalCount = state.clients.where(_filterBySection).length;
              return RefreshIndicator(
                onRefresh: () => _refreshClients(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                  children: [
                    if (isWide) ...[
                      _buildHeaderBanner(context, totalCount),
                      const SizedBox(height: 20),
                    ],
                    _buildToolbar(
                      context,
                      controllerRead,
                      controllerWatch,
                      totalCount,
                    ),
                    const SizedBox(height: 18),
                    controllerWatch.paginatedItems.isEmpty
                        ? NoData(
                            text: totalCount == 0
                                ? "No ${pageTitle.toLowerCase()}s available"
                                : "No matching records found",
                          )
                        : _buildTableCard(
                            context,
                            controllerWatch,
                            controllerRead,
                          ),
                  ],
                ),
              );
            }

            if (state is ClientCompanyError) {
              return Center(
                child: Text(
                  state.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header banner (desktop only)
  // ---------------------------------------------------------------------
  Widget _buildHeaderBanner(BuildContext context, int totalItems) {
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052D4).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_sectionIcon, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$pageTitle Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCompanySection
                      ? "Keep track of the companies you do business with"
                      : "Keep track of the people you do business with",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$totalItems',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalItems == 1 ? pageTitle : '${pageTitle}s',
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

  // ---------------------------------------------------------------------
  // Toolbar: search + add + export + delete + refresh
  // ---------------------------------------------------------------------
  Widget _buildToolbar(
    BuildContext context,
    PaginatedDataController<ClientModel> controllerRead,
    PaginatedDataController<ClientModel> controllerWatch,
    int totalCount,
  ) {
    final isWide = _isWide(context);

    final buttons = <Widget>[
      (permissions?.canCreate ?? false)
          ? _gradientButton(
              context: context,
              icon: Icons.add_rounded,
              label: "Add $pageTitle",
              colors: _brandGradient,
              onPressed: () {
                final form = widget.section == ClientSection.contacts
                    ? const ContactCreate()
                    : const CompanyCreate();

                if (kIsMobile || !isWide) {
                  Sheet.showSheet(context, widget: form);
                } else {
                  GeneralDialog.showRTLSheet(context, form);
                }
              },
            )
          : _disabledButton(
              context,
              icon: Icons.add_rounded,
              label: "Add $pageTitle",
            ),
      if ((permissions?.canExport ?? false) &&
          controllerWatch.paginatedItems.isNotEmpty)
        _gradientButton(
          context: context,
          icon: Iconsax.export_3,
          label: "Export",
          colors: const [Color(0xFF334155), Color(0xFF64748B)],
          onPressed: () => _exportData(context, controllerRead),
        ),
      if (_selectedClientCompany.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedClientCompany.length})",
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: () => _bulkDelete(context),
        ),
      if (isWide)
        _iconCircleButton(
          context,
          icon: Iconsax.refresh,
          tooltip: "Refresh",
          background: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          iconColor: Theme.of(context).colorScheme.primary,
          onPressed: () => _refreshClients(context),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                SizedBox(width: 260, child: _searchBox(controllerRead)),
                const SizedBox(width: 16),
                _countChip(context, totalCount),
                const Spacer(),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchBox(controllerRead),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            ),
    );
  }

  Widget _countChip(BuildContext context, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _sectionIcon,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "$total total",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox(PaginatedDataController<ClientModel> controllerRead) {
    return _ClientSearchField(
      pageTitle: pageTitle,
      onChanged: controllerRead.setSearch,
    );
  }

  Widget _gradientButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabledButton(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.grey500),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _iconCircleButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(
    BuildContext context,
    PaginatedDataController<ClientModel> controller,
  ) async {
    try {
      List<List<String>> exportData = [];

      if (widget.section == ClientSection.contacts) {
        exportData.add(['Name', 'Email', 'Mobile', 'Status', 'Created By']);
      } else {
        exportData.add(['Company', 'Phone', 'GST/VAT', 'Status', 'Created By']);
      }

      for (var client in controller.paginatedItems) {
        if (widget.section == ClientSection.contacts) {
          exportData.add([
            client.clientName ?? '',
            client.email ?? '',
            client.mobileNumber ?? '',
            client.isActive ? 'Active' : 'Inactive',
            client.createdBy.name,
          ]);
        } else {
          exportData.add([
            client.companyName ?? '',
            client.officePhoneNo ?? '',
            client.gstVatNumber ?? '',
            client.isActive ? 'Active' : 'Inactive',
            client.createdBy.name,
          ]);
        }
      }

      var fileBytes = await XlsxWriter().create(exportData);

      var filePath = await saveFileToDownloads(
        fileBytes,
        fileName: '$pageTitle List.xlsx',
      );

      if (!kIsWeb) openfile(filePath, context);
    } catch (e) {
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  // ---------------------------------------------------------------------
  // Table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _hScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(6),
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _hScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: true,
                        sortColumnIndex: controllerWatch.sortColumnIndex,
                        sortAscending: controllerWatch.sortAscending,
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.06,
                          ),
                        ),
                        headingTextStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        columns: _buildColumns(controllerRead),
                        rows: controllerWatch.paginatedItems
                            .asMap()
                            .entries
                            .map(
                              (entry) => _buildDataRow(
                                context,
                                entry.value,
                                controllerWatch,
                                controllerRead,
                                entry.key,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<ClientModel>(),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns(
    PaginatedDataController<ClientModel> controller,
  ) {
    if (widget.section == ClientSection.contacts) {
      return [
        DataColumn(label: const Text("Name"), onSort: controller.setSort),
        DataColumn(label: const Text("Email"), onSort: controller.setSort),
        const DataColumn(label: Text("Mobile")),
        const DataColumn(label: Text("Status")),
        const DataColumn(label: Text("Created By")),
        const DataColumn(label: Text("Action")),
      ];
    } else {
      return [
        DataColumn(label: const Text("Company"), onSort: controller.setSort),
        const DataColumn(label: Text("Phone")),
        const DataColumn(label: Text("GST/VAT")),
        const DataColumn(label: Text("Status")),
        const DataColumn(label: Text("Created By")),
        const DataColumn(label: Text("Action")),
      ];
    }
  }

  bool _filterBySection(ClientModel client) {
    if (widget.section == ClientSection.contacts) {
      return client.clientName!.isNotEmpty;
    } else {
      return client.companyName!.isNotEmpty;
    }
  }

  DataRow _buildDataRow(
    BuildContext context,
    ClientModel client,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
    int index,
  ) {
    return widget.section == ClientSection.contacts
        ? _buildContactRow(context, client, controllerWatch, controllerRead, index)
        : _buildCompanyRow(context, client, controllerWatch, controllerRead, index);
  }

  WidgetStateProperty<Color?> _rowColor(BuildContext context, int index) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
      }
      return index.isEven
          ? Colors.transparent
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            );
    });
  }

  DataRow _buildContactRow(
    BuildContext context,
    ClientModel client,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
    int index,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(client.uid);

    return DataRow(
      selected: isSelected,
      color: _rowColor(context, index),
      onSelectChanged: (selected) {
        controllerRead.onSelected(client.uid!, selected);
        selected == true
            ? _selectedClientCompany.add(client)
            : _selectedClientCompany.remove(client);
        setState(() {});
      },
      cells: [
        DataCell(
          _nameCell(
            context,
            client,
            client.clientName,
            client.profilePictureUrl,
            false,
          ),
        ),
        DataCell(
          Text(
            client.email ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(
            client.mobileNumber ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(_statusCell(context, client.isActive)),
        DataCell(CreatedByWidget(userData: client.createdBy)),
        DataCell(_actionButtons(context, client)),
      ],
    );
  }

  DataRow _buildCompanyRow(
    BuildContext context,
    ClientModel company,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
    int index,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(company.uid);

    return DataRow(
      selected: isSelected,
      color: _rowColor(context, index),
      onSelectChanged: (selected) {
        controllerRead.onSelected(company.uid!, selected);
        selected == true
            ? _selectedClientCompany.add(company)
            : _selectedClientCompany.remove(company);
        setState(() {});
      },
      cells: [
        DataCell(
          _nameCell(
            context,
            company,
            company.companyName,
            company.companyLogoUrl,
            true,
          ),
        ),
        DataCell(
          Text(
            company.officePhoneNo ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(
            company.gstVatNumber ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(_statusCell(context, company.isActive)),
        DataCell(CreatedByWidget(userData: company.createdBy)),
        DataCell(_actionButtons(context, company)),
      ],
    );
  }

  Widget _nameCell(
    BuildContext context,
    ClientModel company,
    String? title,
    String? imageUrl,
    bool isCompany,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final profile = ClientProfile(client: company, isCompany: isCompany);
        final isWide = _isWide(context);
        !isWide
            ? Sheet.showSheet(context, widget: profile)
            : GeneralDialog.showRTLSheet(context, profile);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: imageUrl ?? AppStrings.emptyProfilePhotoUrl,
              height: 30,
              width: 30,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _statusCell(BuildContext context, bool isActive) {
    final color = isActive ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context, ClientModel client) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        (permissions?.canEdit ?? false)
            ? _iconCircleButton(
                context,
                icon: Iconsax.edit,
                tooltip: "Edit",
                background: AppColors.info.withValues(alpha: 0.12),
                iconColor: AppColors.info,
                onPressed: () {
                  final form = widget.section == ClientSection.contacts
                      ? ContactUpdate(uid: client.uid!)
                      : CompanyUpdate(uid: client.uid!);

                  final isWide = _isWide(context);
                  if (!isWide) {
                    Sheet.showSheet(context, widget: form);
                  } else {
                    GeneralDialog.showRTLSheet(context, form);
                  }
                },
              )
            : _iconCircleButton(
                context,
                icon: Iconsax.edit,
                tooltip: "No permission",
                background: AppColors.grey200,
                iconColor: AppColors.grey400,
                onPressed: () {},
              ),
        const SizedBox(width: 8),
        (permissions?.canDelete ?? false)
            ? _iconCircleButton(
                context,
                icon: Iconsax.trash,
                tooltip: "Delete",
                background: AppColors.danger.withValues(alpha: 0.12),
                iconColor: AppColors.danger,
                onPressed: () => _onDeleteTap(context, client),
              )
            : _iconCircleButton(
                context,
                icon: Iconsax.trash,
                tooltip: "No permission",
                background: AppColors.grey200,
                iconColor: AppColors.grey400,
                onPressed: () {},
              ),
      ],
    );
  }

  Future<void> _onDeleteTap(BuildContext context, ClientModel client) async {
    final isAssigned = await ClientService.isClientAssigned(client.uid ?? '');

    if (isAssigned) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text('This client is associated with leads.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete $pageTitle',
        content: 'Are you sure you want to delete this $pageTitle?',
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      final deletedClient = client.copyWith();

      await ClientService.deleteClient(uid: client.uid ?? '');

      if (!context.mounted) return;

      FlushBar.show(
        context,
        '$pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          if (deletedClient.uid == null) return;

          await ClientService.restoreClient(deletedClient);

          if (!context.mounted) return;

          context.read<ClientCompanyBloc>().add(StreamClientCompany());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Failed to delete $pageTitle: $e',
        isSuccess: false,
      );
    }
  }

  Future<void> _bulkDelete(BuildContext context) async {
    if (_selectedClientCompany.isEmpty) return;

    for (var client in _selectedClientCompany) {
      final isAssigned = await ClientService.isClientAssigned(client.uid ?? '');

      if (isAssigned) {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: const Text(
              'One or more selected clients are associated with leads and cannot be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete',
        content: 'Are you sure want to delete this $pageTitle?',
      ),
      barrierDismissible: false,
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      final deletedClients = _selectedClientCompany
          .map((e) => e.copyWith())
          .toList();

      futureLoading(context);

      for (var client in deletedClients) {
        await ClientService.deleteClient(uid: client.uid ?? '');
      }

      if (Navigator.canPop(context)) Navigator.pop(context);

      _selectedClientCompany.clear();
      setState(() {});

      if (!context.mounted) return;

      FlushBar.show(
        context,
        'Clients deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var client in deletedClients) {
            if (client.uid == null) continue;

            await ClientService.restoreClient(client);
          }

          if (!context.mounted) return;

          context.read<ClientCompanyBloc>().add(StreamClientCompany());
        },
      );
    } catch (e, st) {
      if (Navigator.canPop(context)) Navigator.pop(context);

      await ErrorService.recordError(e, st);
      if (!context.mounted) return;

      FlushBar.show(
        context,
        'Failed to delete clients: $e',
        isSuccess: false,
      );
    }
  }
}

// ---------------------------------------------------------------------
// A more polished, colorful search field for the Company / Contact toolbar.
// ---------------------------------------------------------------------
class _ClientSearchField extends StatefulWidget {
  final String pageTitle;
  final ValueChanged<String> onChanged;
  const _ClientSearchField({required this.pageTitle, required this.onChanged});

  @override
  State<_ClientSearchField> createState() => _ClientSearchFieldState();
}

class _ClientSearchFieldState extends State<_ClientSearchField> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _focused
              ? primary.withValues(alpha: 0.55)
              : Theme.of(context).colorScheme.outlineVariant,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: (val) {
          setState(() => _hasText = val.isNotEmpty);
          widget.onChanged(val);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search ${widget.pageTitle}',
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(
                  Iconsax.search_normal_1,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  splashRadius: 16,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _hasText = false);
                    widget.onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 4,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}