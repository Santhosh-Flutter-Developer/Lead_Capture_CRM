import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../form/role_create.dart';
import '../form/role_edit.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/models/models.dart';
import 'bloc/roles_bloc.dart';

const String _pageTitle = "Role";

class RolesListing extends StatelessWidget {
  const RolesListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RolesBloc()..add(StreamRoles()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<RoleModel>(
          initialSortColumnIndex: 1,
          filterLogic: (role, query) {
            final q = query.toLowerCase();
            return role.name.toLowerCase().contains(q) ||
                role.name.toLowerCase().contains(q);
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
          getItemId: (role) => role.uid ?? '',
        ),
        child: const RolesListingView(),
      ),
    );
  }
}

class RolesListingView extends StatefulWidget {
  const RolesListingView({super.key});

  @override
  State<RolesListingView> createState() => _RolesListingViewState();
}

class _RolesListingViewState extends State<RolesListingView> {
  final List<RoleModel> _selectedRoles = [];
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

  Future<void> _refreshRoles() async {
    context.read<RolesBloc>().add(StreamRoles());
  }

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<RoleModel>>();
    final controllerWatch = context.watch<PaginatedDataController<RoleModel>>();
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<RolesBloc, RolesState>(
        listenWhen: (previous, current) => current is RolesLoaded,
        listener: (context, state) {
          if (state is RolesLoaded) {
            controllerRead.setData(state.roles);
          }
        },
        child: BlocBuilder<RolesBloc, RolesState>(
          builder: (context, state) {
            if (state is RolesLoading) {
              return const WaitingLoading();
            }

            if (state is RolesLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshRoles(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                    const SizedBox(height: 20),
                    _buildActionRow(context),
                    const SizedBox(height: 20),
                    controllerWatch.paginatedItems.isEmpty
                        ? NoData(
                            text: state.roles.isEmpty
                                ? "No roles available"
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
                                                      "Description",
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
                                                  (role) => _buildDataRow(
                                                    context,
                                                    role,
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
                                  child: PaginationControls<RoleModel>(),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              );
            }

            if (state is RolesError) {
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

  Widget _buildActionRow(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /// LEFT SIDE (Add + Delete)
        Row(
          children: [
            (permissions?.canCreate ?? false)
                ? ElevatedButton.icon(
                    onPressed: () {
                      if (kIsMobile || width < 1000) {
                        Sheet.showSheet(context, widget: const RoleCreate());
                      } else {
                        GeneralDialog.showRTLSheet(context, const RoleCreate());
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

            if (_selectedRoles.isNotEmpty) ...[
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
                        if (_selectedRoles.isEmpty) return;

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
                          final deletedRoles = _selectedRoles
                              .map((e) => e.copyWith())
                              .toList();

                          // ✅ STEP 2: loader
                          futureLoading(context);

                          // ✅ STEP 3: DELETE
                          for (var role in deletedRoles) {
                            if (role.isSuperAdmin) continue;
                            await RoleService.deleteRole(uid: role.uid ?? '');
                          }

                          // ✅ STEP 4: close loader
                          if (Navigator.canPop(context)) Navigator.pop(context);

                          // ✅ STEP 5: clear selection
                          _selectedRoles.clear();
                          setState(() {});

                          // ✅ STEP 6: UNDO
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              for (var role in deletedRoles) {
                                if (role.uid == null) continue;

                                await RoleService.restoreRole(role);
                              }

                              if (!context.mounted) return;

                              // 🔥 refresh UI
                              context.read<RolesBloc>().add(StreamRoles());
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey400,
                        ),
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
            onPressed: _refreshRoles,
            iconSize: 18,
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    RoleModel role,
    PaginatedDataController<RoleModel> controllerWatch,
    PaginatedDataController<RoleModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    final isSuperAdmin = role.isSuperAdmin;
    bool isSelected = controllerWatch.selectedIds.contains(role.uid);
    return DataRow(
      selected: isSelected,
      onSelectChanged: isSuperAdmin
          ? null
          : (selected) {
              controllerRead.onSelected(role.uid ?? '', selected);
              if (selected ?? false) {
                _selectedRoles.add(role);
              } else {
                _selectedRoles.remove(role);
              }
              setState(() {});
            },
      cells: [
        DataCell(
          Text(
            role.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(role.description, style: Theme.of(context).textTheme.bodySmall),
        ),
        DataCell(
          Text(
            role.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(CreatedByWidget(userData: role.createdBy)),
        DataCell(
          isSuperAdmin
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    (permissions?.canEdit ?? false)
                        ? IconButton(
                            icon: const Icon(Iconsax.edit),
                            onPressed: () {
                              if (kIsMobile || width < 1000) {
                                Sheet.showSheet(
                                  context,
                                  widget: RoleEdit(uid: role.uid ?? ''),
                                );
                              } else {
                                GeneralDialog.showRTLSheet(
                                  context,
                                  RoleEdit(uid: role.uid ?? ''),
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
                                final deletedRole = role.copyWith();

                                await RoleService.deleteRole(
                                  uid: role.uid ?? '',
                                );

                                if (!context.mounted) return;

                                FlushBar.show(
                                  context,
                                  '$_pageTitle deleted successfully',
                                  actionLabel: 'UNDO',
                                  onActionPressed: () async {
                                    if (deletedRole.uid == null) return;

                                    await RoleService.restoreRole(deletedRole);

                                    if (!context.mounted) return;

                                    context.read<RolesBloc>().add(
                                      StreamRoles(),
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
