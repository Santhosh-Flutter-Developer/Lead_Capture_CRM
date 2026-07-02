import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/deal_status_bloc.dart';

const String _pageTitle = "Deal Status";

class DealStatusListing extends StatelessWidget {
  const DealStatusListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DealStatusBloc()..add(StreamDealStatus()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<DealStatusModel>(
          initialSortColumnIndex: 1,
          filterLogic: (dealStatus, query) {
            final q = query.toLowerCase();
            return dealStatus.name.toLowerCase().contains(q) ||
                dealStatus.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 1:
                compare = a.orderNumber.compareTo(b.orderNumber);
                break;
              case 2:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (dealStatus) => dealStatus.uid ?? '',
        ),
        child: const DealStatusListingView(),
      ),
    );
  }
}

class DealStatusListingView extends StatefulWidget {
  const DealStatusListingView({super.key});

  @override
  State<DealStatusListingView> createState() => _DealStatusListingViewState();
}

class _DealStatusListingViewState extends State<DealStatusListingView> {
  final List<DealStatusModel> _selectedDealStatus = [];
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

  Future<void> _refreshDealStatus(BuildContext context) async {
    context.read<DealStatusBloc>().add(StreamDealStatus());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final controllerRead = context
        .read<PaginatedDataController<DealStatusModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<DealStatusModel>>();

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<DealStatusBloc, DealStatusState>(
        listenWhen: (previous, current) => current is DealStatusLoaded,
        listener: (context, state) {
          if (state is DealStatusLoaded) {
            controllerRead.setData(state.dealStatus);
          }
        },
        child: BlocBuilder<DealStatusBloc, DealStatusState>(
          builder: (context, state) {
            if (state is DealStatusLoading) {
              return const WaitingLoading();
            }

            if (state is DealStatusLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshDealStatus(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                    const SizedBox(height: 10),
                    _buildActionRow(context, state.dealStatus),
                    const SizedBox(height: 20),
                    controllerWatch.paginatedItems.isEmpty
                        ? NoData(
                            text: state.dealStatus.isEmpty
                                ? "No deal statuses available"
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
                                                      "No",
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
                                                  (dealStatus) => _buildDataRow(
                                                    context,
                                                    dealStatus,
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
                                  child: PaginationControls<DealStatusModel>(),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              );
            }

            if (state is DealStatusError) {
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

  Widget _buildActionRow(context, List<DealStatusModel> dealStatusList) {
    final width = MediaQuery.of(context).size.width;
    if (permissions == null) {
      return Row(
        children: [
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: Text(
              "Add Status",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.white),
            ),
          ),
        ],
      );
    }

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
                          widget: const DealStatusCreate(),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          const DealStatusCreate(),
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
            if (_selectedDealStatus.isNotEmpty) ...[
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
                        if (_selectedDealStatus.isEmpty) return;

                        // ✅ STEP 0: check assignment
                        for (var status in _selectedDealStatus) {
                          final isAssigned =
                              await DealStatusService.isDealStatusAssigned(
                                status.uid ?? '',
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
                                  'One or more selected deal statuses are associated with deals and cannot be deleted.',
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
                          final deletedStatuses = _selectedDealStatus
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 3: loader
                          futureLoading(context);

                          // ✅ STEP 4: DELETE (use service, NOT bloc)
                          for (var status in deletedStatuses) {
                            await DealStatusService.deleteDealStatus(
                              uid: status.uid ?? '',
                            );
                          }

                          // ✅ STEP 5: close loader
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          // ✅ STEP 6: clear selection
                          _selectedDealStatus.clear();
                          setState(() {});

                          // ✅ STEP 7: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              for (var status in deletedStatuses) {
                                if (status.uid == null) continue;

                                await DealStatusService.restoreDealStatus(
                                  status,
                                );
                              }

                              if (!context.mounted) return;

                              // 🔥 refresh UI
                              context.read<DealStatusBloc>().add(
                                StreamDealStatus(),
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
              SizedBox(width: 10),
            ],
            ElevatedButton.icon(
              label: Text(
                "Reorder",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: dealStatusList.isNotEmpty
                      ? Theme.of(context).colorScheme.onSecondary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              icon: const Icon(Iconsax.arrange_circle),
              onPressed: dealStatusList.isNotEmpty
                  ? () {
                      if (kIsMobile || width < 1000) {
                        Sheet.showSheet(
                          context,
                          widget: DealStatusReorder(
                            dealStatusList: dealStatusList,
                          ),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          DealStatusReorder(dealStatusList: dealStatusList),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: dealStatusList.isNotEmpty
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: dealStatusList.isNotEmpty
                    ? Theme.of(context).colorScheme.onSecondary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (kIsDesktop)
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Iconsax.refresh),
            onPressed: () => _refreshDealStatus(context),
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    DealStatusModel dealStatus,
    PaginatedDataController<DealStatusModel> controllerWatch,
    PaginatedDataController<DealStatusModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(dealStatus.uid);
    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(dealStatus.uid ?? '', selected);
        if (selected ?? false) {
          _selectedDealStatus.add(dealStatus);
        } else {
          _selectedDealStatus.remove(dealStatus);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Text(
            dealStatus.orderNumber.toString(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(
            dealStatus.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Icon(Icons.circle, color: Color(dealStatus.color))),
        DataCell(
          Text(
            dealStatus.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(CreatedByWidget(userData: dealStatus.createdBy)),
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
                            widget: DealStatusEdit(uid: dealStatus.uid ?? ''),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            DealStatusEdit(uid: dealStatus.uid ?? ''),
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
                            await DealStatusService.isDealStatusAssigned(
                              dealStatus.uid ?? '',
                            );

                        if (isAssigned) {
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Cannot Delete'),
                              content: Text(
                                'This deal status is associated with one or more deals and cannot be deleted.',
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
                          builder: (_) => const ConfirmDialog(
                            title: 'Delete Deal Status',
                            content:
                                'Are you sure you want to delete this deal status?',
                          ),
                        );

                        if (confirm != true) return;

                        try {
                          // ✅ STEP 2: BACKUP (IMPORTANT)
                          final deletedStatus = dealStatus.copyWith();

                          // ✅ STEP 3: DELETE
                          await DealStatusService.deleteDealStatus(
                            uid: dealStatus.uid ?? '',
                          );

                          if (!context.mounted) return;

                          // ✅ STEP 4: UNDO
                          FlushBar.show(
                            context,
                            'Deal status deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              if (deletedStatus.uid == null) return;

                              await DealStatusService.restoreDealStatus(
                                deletedStatus,
                              );

                              if (!context.mounted) return;

                              // ✅ refresh UI
                              context.read<DealStatusBloc>().add(
                                StreamDealStatus(),
                              );
                            },
                          );
                        } catch (e, st) {
                          await ErrorService.recordError(e, st);

                          FlushBar.show(
                            context,
                            'Failed to delete deal status: $e',
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
