import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/utils/src/download_io.dart';
import 'package:provider/provider.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import 'bloc/client_bloc.dart';

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
  String get pageTitle {
    return widget.section == ClientSection.contacts ? 'Contacts' : 'Company';
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(pageTitle);
    setState(() {});
  }

  Future<void> _refreshClients(BuildContext context) async {
    context.read<ClientCompanyBloc>().add(StreamClientCompany());
  }

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

    return Scaffold(
      appBar: kIsMobile
          ? AppBar(leading: Back(), title: Text(pageTitle))
          : null,
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
              // if (!(permissions?.canView ?? false)) {
              //   return buildNoPermissionView(context);
              // }
              // if (state.clients.isEmpty) {
              //   return const NoData(text: "No clients company available");
              // }
              return RefreshIndicator(
                onRefresh: () => _refreshClients(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                    const SizedBox(height: 10),
                    _buildActionRow(context),
                    const SizedBox(height: 20),
                    if (controllerWatch.paginatedItems.isEmpty)
                      const NoData(text: "No matching records found")
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.shadow.withValues(alpha: 0.1),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      showCheckboxColumn: true,
                                      sortColumnIndex:
                                          controllerWatch.sortColumnIndex,
                                      sortAscending:
                                          controllerWatch.sortAscending,
                                      headingRowColor: WidgetStateProperty.all(
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                      ),
                                      headingTextStyle: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                      columns: _buildColumns(controllerRead),
                                      rows: controllerWatch.paginatedItems
                                          .map(
                                            (client) => _buildDataRow(
                                              context,
                                              client,
                                              controllerWatch,
                                              controllerRead,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: PaginationControls<ClientModel>(),
                            ),
                          ],
                        ),
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

  List<DataColumn> _buildColumns(
    PaginatedDataController<ClientModel> controller,
  ) {
    if (widget.section == ClientSection.contacts) {
      return [
        DataColumn(
          label: _sortableHeader("Name", controller),
          onSort: controller.setSort,
        ),
        DataColumn(
          label: _sortableHeader("Email", controller),
          onSort: controller.setSort,
        ),
        DataColumn(
          label: Text("Mobile", style: Theme.of(context).textTheme.bodySmall),
        ),
        DataColumn(
          label: Text("Status", style: Theme.of(context).textTheme.bodySmall),
        ),
        DataColumn(
          label: Text(
            "Created By",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataColumn(
          label: Text("Action", style: Theme.of(context).textTheme.bodySmall),
        ),
      ];
    } else {
      return [
        DataColumn(
          label: _sortableHeader("Company", controller),
          onSort: controller.setSort,
        ),
        DataColumn(
          label: Text("Phone", style: Theme.of(context).textTheme.bodySmall),
        ),
        DataColumn(
          label: Text("GST/VAT", style: Theme.of(context).textTheme.bodySmall),
        ),
        DataColumn(
          label: Text("Status", style: Theme.of(context).textTheme.bodySmall),
        ),
        DataColumn(
          label: Text(
            "Created By",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataColumn(
          label: Text("Action", style: Theme.of(context).textTheme.bodySmall),
        ),
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

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_searchBox(onSearchChanged: onSearchChanged)],
    );
  }

  Widget _buildActionRow(context) {
    final controllerWatch = Provider.of<PaginatedDataController<ClientModel>>(
      context,
      listen: true,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (permissions?.canCreate ?? false) ...[
              ElevatedButton.icon(
                onPressed: () {
                  final form = widget.section == ClientSection.contacts
                      ? const ContactCreate()
                      : const CompanyCreate();

                  if (kIsMobile) {
                    Sheet.showSheet(context, widget: form);
                  } else {
                    GeneralDialog.showRTLSheet(context, form);
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  "Add $pageTitle",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if ((permissions?.canExport ?? false) &&
                controllerWatch.paginatedItems.isNotEmpty) ...[
              ElevatedButton.icon(
                label: Text("Export"),
                icon: const Icon(Iconsax.export_3),
                onPressed: () async {
                  try {
                    List<List<String>> exportData = [];

                    // Add header row
                    if (widget.section == ClientSection.contacts) {
                      exportData.add([
                        'Name',
                        'Email',
                        'Mobile',
                        'Status',
                        'Created By',
                      ]);
                    } else {
                      exportData.add([
                        'Company',
                        'Phone',
                        'GST/VAT',
                        'Status',
                        'Created By',
                      ]);
                    }

                    final controller =
                        Provider.of<PaginatedDataController<ClientModel>>(
                          context,
                          listen: false,
                        );
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

                    // Generate Excel
                    var fileBytes = await XlsxWriter().create(exportData);

                    // Save to downloads
                    var filePath = await saveFileToDownloads(
                      fileBytes,
                      fileName: '$pageTitle List.xlsx',
                    );

                    // Open file
                    openfile(filePath, context);
                  } catch (e) {
                    FlushBar.show(context, e.toString(), isSuccess: false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ],
            const SizedBox(width: 10),

            // ] else ...[
            // ElevatedButton.icon(
            //   onPressed: null,
            //   icon: Icon(Icons.add, size: 18, color: AppColors.grey600),
            //   label: Text(
            //     "Add $pageTitle",
            //     style: Theme.of(
            //       context,
            //     ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
            //   ),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: AppColors.grey300,
            //     foregroundColor: AppColors.grey600,
            //   ),
            // ),
            if (permissions?.canDelete ?? false) ...[
              if (_selectedClientCompany.isNotEmpty) ...[
                ElevatedButton.icon(
                  label: Text(
                    "Delete",
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white),
                  ),
                  icon: const Icon(Iconsax.trash),
                  onPressed: () async {
                    if (_selectedClientCompany.isEmpty) return;

                    // ✅ STEP 0: check assignment
                    for (var client in _selectedClientCompany) {
                      final isAssigned = await ClientService.isClientAssigned(
                        client.uid ?? '',
                      );

                      if (isAssigned) {
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(
                              'Cannot Delete',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            content: Text(
                              'One or more selected clients are associated with leads and cannot be deleted.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'OK',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                    }

                    // ✅ STEP 1: confirm
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => ConfirmDialog(
                        title: 'Delete',
                        content: 'Are you sure want to delete this $pageTitle?',
                      ),
                      barrierDismissible: false,
                    );

                    if (confirm != true) return;

                    try {
                      // ✅ STEP 2: BACKUP
                      final deletedClients = _selectedClientCompany
                          .map((e) => e.copyWith())
                          .toList();

                      // ✅ STEP 3: loader
                      futureLoading(context);

                      // ✅ STEP 4: DELETE (use service)
                      for (var client in deletedClients) {
                        await ClientService.deleteClient(uid: client.uid ?? '');
                      }

                      // ✅ STEP 5: close loader
                      if (Navigator.canPop(context)) Navigator.pop(context);

                      // ✅ STEP 6: clear selection
                      _selectedClientCompany.clear();
                      setState(() {});

                      // ✅ STEP 7: UNDO
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

                          // ✅ refresh UI
                          context.read<ClientCompanyBloc>().add(
                            StreamClientCompany(),
                          );
                        },
                      );
                    } catch (e, st) {
                      if (Navigator.canPop(context)) Navigator.pop(context);

                      await ErrorService.recordError(e, st);

                      FlushBar.show(
                        context,
                        'Failed to delete clients: $e',
                        isSuccess: false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ],
              // ] else ...[
              //   ElevatedButton.icon(
              //     label: Text("Delete"),
              //     icon: Icon(Iconsax.trash),
              //     onPressed: () {},
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: AppColors.grey400,
              //       foregroundColor: AppColors.white,
              //     ),
              //   ),
              // ],
            ],
          ],
        ),
        if (kIsDesktop)
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Iconsax.refresh),
            onPressed: () => _refreshClients(context),
            iconSize: 18,
          ),
      ],
    );
  }

  Widget _sortableHeader(String label, controllerRead) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_upward,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    ClientModel client,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
  ) {
    return widget.section == ClientSection.contacts
        ? _buildContactRow(context, client, controllerWatch, controllerRead)
        : _buildCompanyRow(context, client, controllerWatch, controllerRead);
  }

  DataRow _buildContactRow(
    BuildContext context,
    ClientModel client,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(client.uid);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(client.uid!, selected);
        selected == true
            ? _selectedClientCompany.add(client)
            : _selectedClientCompany.remove(client);
        setState(() {});
      },
      cells: [
        /// Name
        DataCell(
          _nameCell(
            context,
            client,
            client.clientName,
            client.profilePictureUrl,
            false,
          ),
        ),

        /// Email
        DataCell(
          Text(
            client.email ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Mobile
        DataCell(
          Text(
            client.mobileNumber ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Status
        DataCell(_statusCell(client.isActive)),

        /// Created By
        DataCell(CreatedByWidget(userData: client.createdBy)),

        /// Actions
        DataCell(_actionButtons(context, client)),
      ],
    );
  }

  DataRow _buildCompanyRow(
    BuildContext context,
    ClientModel company,
    PaginatedDataController<ClientModel> controllerWatch,
    PaginatedDataController<ClientModel> controllerRead,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(company.uid);

    return DataRow(
      selected: isSelected,
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

        /// Phone
        DataCell(
          Text(
            company.officePhoneNo ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// GST / VAT
        DataCell(
          Text(
            company.gstVatNumber ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Status
        DataCell(_statusCell(company.isActive)),
        DataCell(CreatedByWidget(userData: company.createdBy)),

        /// Actions
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
      onTap: () {
        final profile = ClientProfile(client: company, isCompany: isCompany);
        kIsMobile
            ? Sheet.showSheet(context, widget: profile)
            : GeneralDialog.showRTLSheet(context, profile);
      },
      child: Row(
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
          const SizedBox(width: 8),
          Text(
            title ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _statusCell(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success : AppColors.danger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _actionButtons(BuildContext context, ClientModel client) {
    return Row(
      children: [
        if (permissions?.canEdit ?? false) ...[
          IconButton(
            icon: const Icon(Iconsax.edit),
            color: Theme.of(context).colorScheme.primary,
            splashRadius: 20,
            onPressed: () {
              final form = widget.section == ClientSection.contacts
                  ? ContactUpdate(uid: client.uid!)
                  : CompanyUpdate(uid: client.uid!);

              if (kIsMobile) {
                Sheet.showSheet(context, widget: form);
              } else {
                GeneralDialog.showRTLSheet(context, form);
              }
            },
          ),
        ],
        if (permissions?.canDelete ?? false) ...[
          IconButton(
            icon: const Icon(Iconsax.trash),
            color: Theme.of(context).colorScheme.error,
            splashRadius: 20,
            onPressed: () async {
              // ✅ STEP 0: check assignment
              final isAssigned = await ClientService.isClientAssigned(
                client.uid ?? '',
              );

              if (isAssigned) {
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(
                      'Cannot Delete',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    content: Text(
                      'This client is associated with leads.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'OK',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
                return;
              }

              // ✅ STEP 1: confirm
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => ConfirmDialog(
                  title: 'Delete $pageTitle',
                  content: 'Are you sure you want to delete this $pageTitle?',
                ),
              );

              if (confirm != true) return;

              try {
                // ✅ STEP 2: BACKUP
                final deletedClient = client.copyWith();

                // ✅ STEP 3: DELETE (use service, NOT bloc)
                await ClientService.deleteClient(uid: client.uid ?? '');

                if (!context.mounted) return;

                // ✅ STEP 4: UNDO
                FlushBar.show(
                  context,
                  '$pageTitle deleted successfully',
                  actionLabel: 'UNDO',
                  onActionPressed: () async {
                    if (deletedClient.uid == null) return;

                    await ClientService.restoreClient(deletedClient);

                    if (!context.mounted) return;

                    // ✅ refresh UI
                    context.read<ClientCompanyBloc>().add(
                      StreamClientCompany(),
                    );
                  },
                );
              } catch (e, st) {
                await ErrorService.recordError(e, st);

                FlushBar.show(
                  context,
                  'Failed to delete $pageTitle: $e',
                  isSuccess: false,
                );
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _searchBox({required ValueChanged<String> onSearchChanged}) {
    return SizedBox(
      width: 200,
      child: ListingSearchField(
        onChanged: onSearchChanged,
        pageTitle: pageTitle,
      ),
    );
  }
}
