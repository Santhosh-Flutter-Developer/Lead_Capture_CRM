import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../form/sub_department_create.dart';
import '../form/sub_department_edit.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/sub_department_bloc.dart';

const String _pageTitle = "Sub Department";

class SubDepartmentListing extends StatelessWidget {
  const SubDepartmentListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SubDepartmentBloc()..add(StreamSubDepartment()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<SubDepartmentModel>(
          initialSortColumnIndex: 1,
          filterLogic: (subDepartment, query) {
            final q = query.toLowerCase();
            return subDepartment.name.toLowerCase().contains(q) ||
                subDepartment.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 2:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;

              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (subDepartment) => subDepartment.uid ?? '',
        ),
        child: const SubDepartmentListingView(),
      ),
    );
  }
}

class SubDepartmentListingView extends StatefulWidget {
  const SubDepartmentListingView({super.key});

  @override
  State<SubDepartmentListingView> createState() =>
      _SubDepartmentListingViewState();
}

class _SubDepartmentListingViewState extends State<SubDepartmentListingView> {
  final List<SubDepartmentModel> _selectedSubDepartments = [];
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

  Future<void> _refreshSubDepartments() async {
    context.read<SubDepartmentBloc>().add(StreamSubDepartment());
  }

  @override
  Widget build(BuildContext context) {
    final controllerRead = context
        .read<PaginatedDataController<SubDepartmentModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<SubDepartmentModel>>();
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<SubDepartmentBloc, SubDepartmentState>(
        listenWhen: (previous, current) => current is SubDepartmentLoaded,
        listener: (context, state) {
          if (state is SubDepartmentLoaded) {
            controllerRead.setData(state.subDepartments);
          }
        },
        child: BlocBuilder<SubDepartmentBloc, SubDepartmentState>(
          builder: (context, state) {
            if (state is SubDepartmentLoading) {
              return const WaitingLoading();
            }

            if (state is SubDepartmentLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshSubDepartments(),
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
                            text: state.subDepartments.isEmpty
                                ? "No sub_departments available"
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
                                                      "Department",
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
                                                  (subDepartment) =>
                                                      _buildDataRow(
                                                        context,
                                                        subDepartment,
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
                                  child:
                                      PaginationControls<SubDepartmentModel>(),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              );
            }

            if (state is SubDepartmentError) {
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
    final width = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _searchBox(onSearchChanged: onSearchChanged),
        if (!kIsMobile && width >= 1000)
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 18),
              label: Text(
                "Filters",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ],
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
                          widget: const SubDepartmentCreate(),
                        );
                      } else {
                        GeneralDialog.showRTLSheet(
                          context,
                          const SubDepartmentCreate(),
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
            if (_selectedSubDepartments.isNotEmpty) ...[
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
                        if (_selectedSubDepartments.isEmpty) return;

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
                          final deletedSubDepartments = _selectedSubDepartments
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 2: loader
                          futureLoading(context);

                          // ✅ STEP 3: DELETE
                          for (var subDept in deletedSubDepartments) {
                            await SubDepartmentService.deleteSubDepartment(
                              uid: subDept.uid ?? '',
                            );
                          }

                          // ✅ STEP 4: close loader
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          // ✅ STEP 5: clear selection
                          _selectedSubDepartments.clear();
                          setState(() {});

                          // ✅ STEP 6: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              for (var subDept in deletedSubDepartments) {
                                if (subDept.uid == null) continue;

                                await SubDepartmentService.restoreSubDepartment(
                                  subDept,
                                );
                              }

                              if (!context.mounted) return;

                              // ✅ refresh UI
                              context.read<SubDepartmentBloc>().add(
                                StreamSubDepartment(),
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
            onPressed: _refreshSubDepartments,
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    SubDepartmentModel subDepartment,
    PaginatedDataController<SubDepartmentModel> controllerWatch,
    PaginatedDataController<SubDepartmentModel> controllerRead,
  ) {
    bool isSelected = controllerWatch.selectedIds.contains(subDepartment.uid);
    final width = MediaQuery.of(context).size.width;
    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(subDepartment.uid ?? '', selected);
        if (selected ?? false) {
          _selectedSubDepartments.add(subDepartment);
        } else {
          _selectedSubDepartments.remove(subDepartment);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Text(
            subDepartment.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(
            CacheService.departmentByUid(subDepartment.department)?.name ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(
            subDepartment.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(CreatedByWidget(userData: subDepartment.createdBy)),
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
                            widget: SubDepartmentEdit(
                              uid: subDepartment.uid ?? '',
                            ),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            SubDepartmentEdit(uid: subDepartment.uid ?? ''),
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
                                'Are you sure want to delete this $_pageTitle',
                          ),
                        );

                        if (result != true) return;

                        try {
                          // ✅ STEP 1: BACKUP
                          final deletedSubDepartment = subDepartment.copyWith();

                          // ✅ STEP 2: DELETE
                          await SubDepartmentService.deleteSubDepartment(
                            uid: subDepartment.uid ?? '',
                          );

                          if (!context.mounted) return;

                          // ✅ STEP 3: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              if (deletedSubDepartment.uid == null) return;

                              // ✅ STEP 4: RESTORE
                              await SubDepartmentService.restoreSubDepartment(
                                deletedSubDepartment,
                              );

                              if (!context.mounted) return;

                              // ✅ STEP 5: REFRESH UI
                              context.read<SubDepartmentBloc>().add(
                                StreamSubDepartment(),
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
