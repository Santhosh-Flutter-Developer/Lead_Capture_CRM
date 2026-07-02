import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/lead_priority_bloc.dart';

const String _pageTitle = "Lead Priority";

class LeadPriorityListing extends StatelessWidget {
  const LeadPriorityListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeadPriorityBloc()..add(StreamLeadPriority()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<LeadPriorityModel>(
          initialSortColumnIndex: 1,
          filterLogic: (leadPriority, query) {
            final q = query.toLowerCase();
            return leadPriority.name.toLowerCase().contains(q) ||
                leadPriority.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 1:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (leadPriority) => leadPriority.uid ?? '',
        ),
        child: const LeadPriorityListingView(),
      ),
    );
  }
}

class LeadPriorityListingView extends StatefulWidget {
  const LeadPriorityListingView({super.key});

  @override
  State<LeadPriorityListingView> createState() =>
      _LeadPriorityListingViewState();
}

class _LeadPriorityListingViewState extends State<LeadPriorityListingView> {
  final List<LeadPriorityModel> _selectedLeadPriority = [];
  PermissionModel? permissions;
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    setState(() {});
  }

  Future<void> _refreshLeadPriority(BuildContext context) async {
    context.read<LeadPriorityBloc>().add(StreamLeadPriority());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final controllerRead = context
        .read<PaginatedDataController<LeadPriorityModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<LeadPriorityModel>>();

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<LeadPriorityBloc, LeadPriorityState>(
        listenWhen: (previous, current) => current is LeadPriorityLoaded,
        listener: (context, state) {
          if (state is LeadPriorityLoaded) {
            controllerRead.setData(state.leadPriority);
          }
        },
        child: BlocBuilder<LeadPriorityBloc, LeadPriorityState>(
          builder: (context, state) {
            if (state is LeadPriorityLoading) {
              return const WaitingLoading();
            }

            if (state is LeadPriorityLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshLeadPriority(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                    const SizedBox(height: 10),
                    _buildActionRow(context, state.leadPriority),
                    const SizedBox(height: 20),
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
                              return Scrollbar(
                                controller: _hScrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                thickness: 4,
                                radius: const Radius.circular(6),
                                scrollbarOrientation:
                                    ScrollbarOrientation.bottom,
                                child: SingleChildScrollView(
                                  controller: _hScrollController,
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
                                      columns: [
                                        DataColumn(
                                          label: Row(
                                            children: [
                                              Text(
                                                "Name",
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_upward,
                                                size: 14,
                                                color: AppColors.grey400,
                                              ),
                                            ],
                                          ),
                                          onSort: controllerRead.setSort,
                                        ),
                                        DataColumn(
                                          label: Row(
                                            children: [
                                              Text(
                                                "Color",
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_upward,
                                                size: 14,
                                                color: AppColors.grey400,
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataColumn(
                                          label: Row(
                                            children: [
                                              Text(
                                                "Created",
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_upward,
                                                size: 14,
                                                color: AppColors.grey400,
                                              ),
                                            ],
                                          ),
                                          onSort: controllerRead.setSort,
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Created By",
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Action",
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                      rows: controllerWatch.paginatedItems
                                          .map(
                                            (leadPriority) => _buildDataRow(
                                              context,
                                              leadPriority,
                                              controllerWatch,
                                              controllerRead,
                                            ),
                                          )
                                          .toList(),
                                    ),
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
                            child: PaginationControls<LeadPriorityModel>(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is LeadPriorityError) {
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

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_searchBox(onSearchChanged: onSearchChanged)],
    );
  }

  Widget _buildActionRow(context, List<LeadPriorityModel> leadPriorityList) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            (permissions?.canCreate ?? false)
                ? ElevatedButton.icon(
                    onPressed: () {
                      if (kIsMobile || width < 1000) {
                        Sheet.showSheet(
                          context,
                          widget: const LeadPriorityCreate(),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          const LeadPriorityCreate(),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      "Add $_pageTitle",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.add, size: 18, color: AppColors.grey600),
                    label: Text(
                      "Add $_pageTitle",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
            const SizedBox(width: 10),
            if (_selectedLeadPriority.isNotEmpty) ...[
              (permissions?.canDelete ?? false)
                  ? ElevatedButton.icon(
                      label: Text(
                        "Delete",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                      ),
                      icon: const Icon(Iconsax.trash),
                      onPressed: () async {
                        if (_selectedLeadPriority.isEmpty) return;

                        // ✅ STEP 0: check assignment
                        for (var priority in _selectedLeadPriority) {
                          final isAssigned =
                              await LeadPriorityService.isLeadPriorityAssigned(
                                priority.uid ?? '',
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
                                  'One or more selected lead priorities are associated with leads and cannot be deleted.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'OK',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
                            title: 'Delete $_pageTitle',
                            content:
                                'Are you sure want to delete selected $_pageTitle?',
                          ),
                          barrierDismissible: false,
                        );

                        if (confirm != true) return;

                        try {
                          // ✅ STEP 2: BACKUP (IMPORTANT)
                          final deletedPriorities = _selectedLeadPriority
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 3: loader
                          futureLoading(context);

                          // ✅ STEP 4: delete
                          for (var priority in deletedPriorities) {
                            await LeadPriorityService.deleteLeadPriority(
                              uid: priority.uid ?? '',
                            );
                          }

                          // ✅ STEP 5: close loader
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          // ✅ STEP 6: clear selection
                          _selectedLeadPriority.clear();
                          setState(() {});

                          // ✅ STEP 7: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              for (var priority in deletedPriorities) {
                                if (priority.uid == null) continue;

                                await LeadPriorityService.restoreLeadPriority(
                                  priority,
                                );
                              }

                              if (!context.mounted) return;

                              // 🔥 refresh UI
                              context.read<LeadPriorityBloc>().add(
                                StreamLeadPriority(),
                              );
                            },
                          );
                        } catch (e, st) {
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          await ErrorService.recordError(e, st);

                          FlushBar.show(
                            context,
                            'Failed to delete $_pageTitle: $e',
                            isSuccess: false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    )
                  : ElevatedButton.icon(
                      label: Text(
                        "Delete",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                      ),
                      icon: Icon(Iconsax.trash),
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.grey400,
                        foregroundColor: AppColors.white,
                      ),
                    ),
            ],
          ],
        ),
        if (kIsDesktop)
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Iconsax.refresh),
            onPressed: () => _refreshLeadPriority(context),
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    LeadPriorityModel leadPriority,
    PaginatedDataController<LeadPriorityModel> controllerWatch,
    PaginatedDataController<LeadPriorityModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(leadPriority.uid);
    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(leadPriority.uid ?? '', selected);
        if (selected ?? false) {
          _selectedLeadPriority.add(leadPriority);
        } else {
          _selectedLeadPriority.remove(leadPriority);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Text(
            leadPriority.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Icon(Icons.circle, color: Color(leadPriority.color))),
        DataCell(
          Text(
            leadPriority.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(CreatedByWidget(userData: leadPriority.createdBy)),
        DataCell(
          Row(
            children: [
              (permissions?.canEdit ?? false)
                  ? IconButton(
                      icon: const Icon(Iconsax.edit),
                      onPressed: () {
                        if (kIsMobile || width < 1000) {
                          Sheet.showSheet(
                            context,
                            widget: LeadPriorityEdit(
                              uid: leadPriority.uid ?? '',
                            ),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            LeadPriorityEdit(uid: leadPriority.uid ?? ''),
                          );
                        }
                      },
                      color: Theme.of(context).colorScheme.primary,
                      splashRadius: 20,
                    )
                  : IconButton(
                      icon: Icon(
                        Iconsax.edit,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: null,
                    ),
              (permissions?.canDelete ?? false)
                  ? IconButton(
                      icon: const Icon(Iconsax.trash),
                      color: Theme.of(context).colorScheme.error,
                      splashRadius: 20,
                      onPressed: () async {
                        // ✅ STEP 0: check assignment
                        final isAssigned =
                            await LeadPriorityService.isLeadPriorityAssigned(
                              leadPriority.uid ?? '',
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
                                'This lead priority is assigned to one or more leads and cannot be deleted.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'OK',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                          builder: (context) => ConfirmDialog(
                            title: 'Delete $_pageTitle',
                            content:
                                'Are you sure want to delete this $_pageTitle?',
                          ),
                          barrierDismissible: false,
                        );

                        if (confirm != true) return;

                        try {
                          // ✅ STEP 2: BACKUP (IMPORTANT)
                          final deletedPriority = leadPriority.copyWith();

                          // ✅ STEP 3: DELETE (use service, not bloc)
                          await LeadPriorityService.deleteLeadPriority(
                            uid: leadPriority.uid ?? '',
                          );

                          if (!context.mounted) return;

                          // ✅ STEP 4: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              if (deletedPriority.uid == null) return;

                              await LeadPriorityService.restoreLeadPriority(
                                deletedPriority,
                              );

                              if (!context.mounted) return;

                              // ✅ refresh UI
                              context.read<LeadPriorityBloc>().add(
                                StreamLeadPriority(),
                              );
                            },
                          );
                        } catch (e, st) {
                          await ErrorService.recordError(e, st);

                          FlushBar.show(
                            context,
                            e.toString(),
                            isSuccess: false,
                          );
                        }
                      },
                    )
                  : IconButton(
                      icon: Icon(
                        Iconsax.trash,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: null,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchBox({required ValueChanged<String> onSearchChanged}) {
    return SizedBox(
      width: 200,
      child: ListingSearchField(
        onChanged: onSearchChanged,
        pageTitle: _pageTitle,
      ),
    );
  }
}
