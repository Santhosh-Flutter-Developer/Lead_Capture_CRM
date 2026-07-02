import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/lead_source_bloc.dart';

const String _pageTitle = "Lead Source";

class LeadSourceListing extends StatelessWidget {
  const LeadSourceListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeadSourceBloc()..add(StreamLeadSource()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<LeadSourceModel>(
          initialSortColumnIndex: 1,
          filterLogic: (leadSources, query) {
            final q = query.toLowerCase();
            return leadSources.name.toLowerCase().contains(q) ||
                leadSources.description.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 2:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              case 3:
                compare = a.description.toLowerCase().compareTo(
                  b.description.toLowerCase(),
                );
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (leadSources) => leadSources.uid ?? '',
        ),
        child: const LeadSourceListingView(),
      ),
    );
  }
}

class LeadSourceListingView extends StatefulWidget {
  const LeadSourceListingView({super.key});

  @override
  State<LeadSourceListingView> createState() => _LeadSourceListingViewState();
}

class _LeadSourceListingViewState extends State<LeadSourceListingView> {
  final List<LeadSourceModel> _selectedLeadCategories = [];
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

  Future<void> _refreshLeadSource(BuildContext context) async {
    context.read<LeadSourceBloc>().add(StreamLeadSource());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final controllerRead = context
        .read<PaginatedDataController<LeadSourceModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<LeadSourceModel>>();

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text("Source"))
          : null,
      body: BlocListener<LeadSourceBloc, LeadSourceState>(
        listenWhen: (previous, current) => current is LeadSourceLoaded,
        listener: (context, state) {
          if (state is LeadSourceLoaded) {
            controllerRead.setData(state.leadSource);
          }
        },
        child: BlocBuilder<LeadSourceBloc, LeadSourceState>(
          builder: (context, state) {
            if (state is LeadSourceLoading) {
              return const WaitingLoading();
            }

            if (state is LeadSourceLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshLeadSource(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                    const SizedBox(height: 10),
                    _buildActionRow(context),
                    const SizedBox(height: 20),
                    controllerWatch.paginatedItems.isEmpty
                        ? NoData(
                            text: state.leadSource.isEmpty
                                ? "No lead sources available"
                                : "No matching records found",
                          )
                        : Container(
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
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
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
                                                  "Desc",
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
                                              (leadCategories) => _buildDataRow(
                                                context,
                                                leadCategories,
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
                              child: PaginationControls<LeadSourceModel>(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }

            if (state is LeadSourceError) {
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

  Widget _buildActionRow(context) {
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
                          widget: const LeadSourceCreate(),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          const LeadSourceCreate(),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.grey300,
                      foregroundColor: AppColors.grey600,
                    ),
                  ),
            const SizedBox(width: 10),
            if (_selectedLeadCategories.isNotEmpty) ...[
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
                        if (_selectedLeadCategories.isEmpty) return;

                        // ✅ STEP 0: Check assignment
                        for (var source in _selectedLeadCategories) {
                          final isAssigned =
                              await LeadSourceService.isLeadSourceAssigned(
                                source.uid ?? '',
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
                                  'One or more selected lead sources are associated with leads and cannot be deleted.',
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

                        // ✅ STEP 1: Confirm
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
                          // ✅ STEP 2: BACKUP (VERY IMPORTANT)
                          final deletedSources = _selectedLeadCategories
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 3: Loader
                          futureLoading(context);

                          // ✅ STEP 4: DELETE
                          for (var source in deletedSources) {
                            await LeadSourceService.deleteLeadSource(
                              uid: source.uid ?? '',
                            );
                          }

                          // ✅ STEP 5: Close loader
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          // ✅ STEP 6: Clear selection
                          _selectedLeadCategories.clear();
                          setState(() {});

                          // ✅ STEP 7: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              for (var source in deletedSources) {
                                if (source.uid == null) continue;

                                await LeadSourceService.restoreLeadSource(
                                  source,
                                );
                              }

                              if (!context.mounted) return;

                              // 🔥 refresh UI
                              context.read<LeadSourceBloc>().add(
                                StreamLeadSource(),
                              );
                            },
                            // optional
                            // onDismissed: () {
                            //   context.read<LeadSourceBloc>().add(StreamLeadSource());
                            // },
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
            onPressed: () => _refreshLeadSource(context),
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    LeadSourceModel leadSource,
    PaginatedDataController<LeadSourceModel> controllerWatch,
    PaginatedDataController<LeadSourceModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(leadSource.uid);
    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(leadSource.uid ?? '', selected);
        if (selected ?? false) {
          _selectedLeadCategories.add(leadSource);
        } else {
          _selectedLeadCategories.remove(leadSource);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Text(
            leadSource.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(
            leadSource.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(
            leadSource.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(CreatedByWidget(userData: leadSource.createdBy)),
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
                            widget: LeadSourceEdit(uid: leadSource.uid ?? ''),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            LeadSourceEdit(uid: leadSource.uid ?? ''),
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
                            await LeadSourceService.isLeadSourceAssigned(
                              leadSource.uid ?? '',
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
                                'This lead source is associated with one or more leads and cannot be deleted.',
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
                          // ✅ STEP 2: BACKUP (VERY IMPORTANT)
                          final deletedSource = leadSource.copyWith();

                          // ✅ STEP 3: DELETE
                          await LeadSourceService.deleteLeadSource(
                            uid: leadSource.uid ?? '',
                          );

                          if (!context.mounted) return;

                          // ✅ STEP 4: UNDO
                          FlushBar.show(
                            context,
                            'Source deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              if (deletedSource.uid == null) return;

                              await LeadSourceService.restoreLeadSource(
                                deletedSource,
                              );

                              if (!context.mounted) return;

                              // ✅ refresh UI
                              context.read<LeadSourceBloc>().add(
                                StreamLeadSource(),
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
