import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../form/designation_create.dart';
import '../form/designation_edit.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/designation_bloc.dart';

const String _pageTitle = "Designation";

class DesignationListing extends StatelessWidget {
  const DesignationListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesignationBloc()..add(StreamDesignation()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<DesignationModel>(
          initialSortColumnIndex: 1,
          filterLogic: (designation, query) {
            final q = query.toLowerCase();
            return designation.name.toLowerCase().contains(q) ||
                designation.name.toLowerCase().contains(q);
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
          getItemId: (designation) => designation.uid ?? '',
        ),
        child: const DesignationListingView(),
      ),
    );
  }
}

class DesignationListingView extends StatefulWidget {
  const DesignationListingView({super.key});

  @override
  State<DesignationListingView> createState() => _DesignationListingViewState();
}

class _DesignationListingViewState extends State<DesignationListingView> {
  final List<DesignationModel> _selectedDesignations = [];
  PermissionModel? permissions;
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
    setState(() {});
  }

  Future<void> _refreshDesignations() async {
    context.read<DesignationBloc>().add(StreamDesignation());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final controllerRead = context
        .read<PaginatedDataController<DesignationModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<DesignationModel>>();

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<DesignationBloc, DesignationState>(
        listenWhen: (previous, current) => current is DesignationLoaded,
        listener: (context, state) {
          if (state is DesignationLoaded) {
            controllerRead.setData(state.designation);
          }
        },
        child: BlocBuilder<DesignationBloc, DesignationState>(
          builder: (context, state) {
            if (state is DesignationLoading) {
              return const WaitingLoading();
            }

            if (state is DesignationLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshDesignations(),
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
                            text: state.designation.isEmpty
                                ? "No designations available"
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
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
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
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
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
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
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
                                                  (designation) =>
                                                      _buildDataRow(
                                                        context,
                                                        designation,
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
                                  child: PaginationControls<DesignationModel>(),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              );
            }

            if (state is DesignationError) {
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
                    onPressed: () async {
                      if (kIsMobile || width < 1000) {
                        Sheet.showSheet(
                          context,
                          widget: const DesignationCreate(),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          const DesignationCreate(),
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
                      "Add Designation",
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
            if (_selectedDesignations.isNotEmpty) ...[
              (permissions?.canDelete ?? false)
                  ? ElevatedButton.icon(
                      label: Text(
                        "Delete",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      icon: const Icon(Iconsax.trash),
                      onPressed: () async {
                        if (_selectedDesignations.isEmpty) return;

                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ConfirmDialog(
                            title: 'Delete',
                            content:
                                'Are you sure want to delete this $_pageTitle?',
                          ),
                          barrierDismissible: false,
                        );

                        if (result != true) return;

                        try {
                          // ✅ STEP 1: BACKUP
                          final deletedDesignations = _selectedDesignations
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 2: loader
                          futureLoading(context);

                          // ✅ STEP 3: DELETE
                          for (var designation in deletedDesignations) {
                            await DesignationService.deleteDesignation(
                              uid: designation.uid ?? '',
                            );
                          }

                          // ✅ STEP 4: close loader
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          // ✅ STEP 5: clear selection
                          _selectedDesignations.clear();
                          setState(() {});

                          // ✅ STEP 6: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              for (var designation in deletedDesignations) {
                                if (designation.uid == null) continue;

                                await DesignationService.restoreDesignation(
                                  designation,
                                );
                              }

                              if (!context.mounted) return;

                              // ✅ refresh UI
                              context.read<DesignationBloc>().add(
                                StreamDesignation(),
                              );
                            },
                          );
                        } catch (e, st) {
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          await ErrorService.recordError(e, st);

                          FlushBar.show(
                            context,
                            e.toString(),
                            isSuccess: false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
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
            onPressed: _refreshDesignations,
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    DesignationModel designation,
    PaginatedDataController<DesignationModel> controllerWatch,
    PaginatedDataController<DesignationModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(designation.uid);
    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(designation.uid ?? '', selected);
        if (selected ?? false) {
          _selectedDesignations.add(designation);
        } else {
          _selectedDesignations.remove(designation);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Text(
            designation.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(
            designation.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(
            designation.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(CreatedByWidget(userData: designation.createdBy)),
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
                            widget: DesignationEdit(uid: designation.uid ?? ''),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            DesignationEdit(uid: designation.uid ?? ''),
                          );
                        }
                      },
                      color: AppColors.info,
                      splashRadius: 20,
                    )
                  : IconButton(
                      icon: Icon(Iconsax.edit, color: AppColors.grey400),
                      onPressed: null,
                    ),
              (permissions?.canDelete ?? false)
                  ? IconButton(
                      icon: const Icon(Iconsax.trash),
                      color: AppColors.danger,
                      splashRadius: 20,
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ConfirmDialog(
                            title: 'Delete $_pageTitle',
                            content:
                                'Are you sure want to delete this $_pageTitle?',
                          ),
                        );

                        if (result != true) return;

                        try {
                          // ✅ STEP 1: BACKUP (IMPORTANT)
                          final deletedDesignation = designation.copyWith();

                          // ✅ STEP 2: DELETE
                          await DesignationService.deleteDesignation(
                            uid: designation.uid ?? '',
                          );

                          if (!context.mounted) return;

                          // ✅ STEP 3: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              if (deletedDesignation.uid == null) return;

                              await DesignationService.restoreDesignation(
                                deletedDesignation,
                              );

                              if (!context.mounted) return;

                              // ✅ refresh UI
                              context.read<DesignationBloc>().add(
                                StreamDesignation(),
                              );
                            },
                          );
                        } catch (e, st) {
                          await ErrorService.recordError(e, st);
                          debugPrint("${e.toString()}, ${st.toString()}");

                          FlushBar.show(
                            context,
                            e.toString(),
                            isSuccess: false,
                            error: e,
                            stackTrace: st,
                          );
                        }
                      },
                    )
                  : IconButton(
                      icon: Icon(Iconsax.trash, color: AppColors.grey400),
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
