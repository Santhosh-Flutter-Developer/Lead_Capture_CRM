import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/lead_category_bloc.dart';

const String _pageTitle = "Lead Category";

class LeadCategoryListing extends StatelessWidget {
  const LeadCategoryListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeadCategoryBloc()..add(StreamLeadCategory()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<LeadCategoryModel>(
          initialSortColumnIndex: 1,
          filterLogic: (leadCategories, query) {
            final q = query.toLowerCase();
            return leadCategories.name.toLowerCase().contains(q) ||
                leadCategories.name.toLowerCase().contains(q);
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
          getItemId: (leadCategories) => leadCategories.uid ?? '',
        ),
        child: const LeadCategoryListingView(),
      ),
    );
  }
}

class LeadCategoryListingView extends StatefulWidget {
  const LeadCategoryListingView({super.key});

  @override
  State<LeadCategoryListingView> createState() =>
      _LeadCategoryListingViewState();
}

class _LeadCategoryListingViewState extends State<LeadCategoryListingView> {
  final List<LeadCategoryModel> _selectedLeadCategories = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  bool _isAdmin = false;
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    _isAdmin = await Spdb.isAdminLoggedIn();
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshLeadCategory(BuildContext context) async {
    context.read<LeadCategoryBloc>().add(StreamLeadCategory());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final controllerRead = context
        .read<PaginatedDataController<LeadCategoryModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<LeadCategoryModel>>();

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text("Category"))
          : null,
      body: BlocListener<LeadCategoryBloc, LeadCategoryState>(
        listenWhen: (previous, current) => current is LeadCategoryLoaded,
        listener: (context, state) {
          if (state is LeadCategoryLoaded) {
            controllerRead.setData(state.leadCategory);
          }
        },
        child: BlocBuilder<LeadCategoryBloc, LeadCategoryState>(
          builder: (context, state) {
            if (state is LeadCategoryLoading) {
              return const WaitingLoading();
            }

            if (state is LeadCategoryLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshLeadCategory(context),
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
                            text: state.leadCategory.isEmpty
                                ? "No lead categories available"
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
                                                Text("Name"),
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
                                                Text("Desc"),
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
                                                Text("Created"),
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
                                          const DataColumn(
                                            label: Text("Created By"),
                                          ),
                                          const DataColumn(
                                            label: Text("Action"),
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
                              child: PaginationControls<LeadCategoryModel>(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }

            if (state is LeadCategoryError) {
              return Center(child: Text(state.message));
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
            if (permissions?.canCreate ?? false)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (kIsMobile || width < 1000) {
                        Sheet.showSheet(
                          context,
                          widget: const LeadCategoryCreate(),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          const LeadCategoryCreate(),
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
                  ),
            const SizedBox(width: 10),
            if (_selectedLeadCategories.isNotEmpty) ...[
              if (permissions?.canDelete ?? false)
                    ElevatedButton.icon(
                      label: const Text("Delete"),
                      icon: const Icon(Iconsax.trash),
                      onPressed: () async {
                        if (_selectedLeadCategories.isEmpty) return;

                        // ✅ STEP 0: Check assignment
                        for (var category in _selectedLeadCategories) {
                          final isAssigned =
                              await LeadCategoryService.isLeadCategoryAssigned(
                                category.uid ?? '',
                              );

                          if (isAssigned) {
                            await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Cannot Delete'),
                                content: const Text(
                                  'One or more selected categories are associated with leads.',
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

                        // ✅ STEP 1: Confirm
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ConfirmDialog(
                            title: 'Delete $_pageTitle',
                            content:
                                'Are you sure you want to delete selected $_pageTitle?',
                          ),
                        );

                        if (result != true) return;

                        try {
                          // ✅ STEP 2: Backup (IMPORTANT — deep copy)
                          final deletedCategories = _selectedLeadCategories
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 3: Loader
                          futureLoading(context);

                          // ✅ STEP 4: Delete
                          for (var category in deletedCategories) {
                            await LeadCategoryService.deleteLeadCategory(
                              uid: category.uid ?? '',
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
                              for (var category in deletedCategories) {
                                if (category.uid == null) continue;

                                await LeadCategoryService.restoreLeadCategory(
                                  category,
                                );
                              }

                              if (!context.mounted) return;

                              // 🔥 refresh list
                              context.read<LeadCategoryBloc>().add(
                                StreamLeadCategory(),
                              );
                            },
                            // Optional (same as your leads pattern)
                            // onDismissed: () {
                            //   context.read<LeadCategoryBloc>().add(StreamLeadCategory());
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
                    ),
            ],
          ],
        ),
        if (kIsDesktop)
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Iconsax.refresh),
            onPressed: () => _refreshLeadCategory(context),
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    LeadCategoryModel leadCategory,
    PaginatedDataController<LeadCategoryModel> controllerWatch,
    PaginatedDataController<LeadCategoryModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(leadCategory.uid);
    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(leadCategory.uid ?? '', selected);
        if (selected ?? false) {
          _selectedLeadCategories.add(leadCategory);
        } else {
          _selectedLeadCategories.remove(leadCategory);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Text(
            leadCategory.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Text(leadCategory.description)),
        DataCell(Text(leadCategory.createdAt.listingDateTime)),
        DataCell(CreatedByWidget(userData: leadCategory.createdBy)),
        DataCell(
          Row(
            children: [
              if (permissions?.canEdit ?? false)
                    IconButton(
                      icon: const Icon(Iconsax.edit),
                      onPressed: () {
                        if (kIsMobile || width < 1000) {
                          Sheet.showSheet(
                            context,
                            widget: LeadCategoryEdit(
                              uid: leadCategory.uid ?? '',
                            ),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            LeadCategoryEdit(uid: leadCategory.uid ?? ''),
                          );
                        }
                      },
                      color: Theme.of(context).colorScheme.primary,
                      splashRadius: 20,
                    ),
              if (permissions?.canDelete ?? false)
                    IconButton(
                      icon: const Icon(Iconsax.trash),
                      color: Theme.of(context).colorScheme.error,
                      splashRadius: 20,
                      tooltip: 'Delete $_pageTitle',
                      onPressed: () async {
                        // ✅ STEP 0: check assignment
                        final isAssigned =
                            await LeadCategoryService.isLeadCategoryAssigned(
                              leadCategory.uid ?? '',
                            );

                        if (isAssigned) {
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Cannot Delete'),
                              content: const Text(
                                'This lead category is associated with one or more leads and cannot be deleted.',
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

                        // ✅ STEP 1: confirm
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (_) => ConfirmDialog(
                            title: 'Delete $_pageTitle',
                            content:
                                'Are you sure you want to delete this $_pageTitle?',
                          ),
                        );

                        if (result != true) return;

                        try {
                          // ✅ STEP 2: BACKUP (VERY IMPORTANT)
                          final deletedCategory = leadCategory.copyWith();

                          // ✅ STEP 3: DELETE
                          await LeadCategoryService.deleteLeadCategory(
                            uid: leadCategory.uid ?? '',
                          );

                          if (!context.mounted) return;

                          // ✅ STEP 4: UNDO (same as Lead)
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              if (deletedCategory.uid == null) return;

                              await LeadCategoryService.restoreLeadCategory(
                                deletedCategory,
                              );

                              if (!context.mounted) return;

                              // ✅ refresh list
                              context.read<LeadCategoryBloc>().add(
                                StreamLeadCategory(),
                              );
                            },
                            // Optional consistency with lead
                            // onDismissed: () {
                            //   context.read<LeadCategoryBloc>().add(StreamLeadCategory());
                            // },
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
