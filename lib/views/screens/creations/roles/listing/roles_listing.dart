import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
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
  bool _permissionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    _permissionsLoaded = true;
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
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
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
                            child: DataTable(
                              showCheckboxColumn: true,
                              sortColumnIndex: controllerWatch.sortColumnIndex,
                              sortAscending: controllerWatch.sortAscending,
                              headingRowColor: WidgetStateProperty.all(
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              headingTextStyle: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                              columns: [
                                DataColumn(
                                  label: Row(
                                    children: [
                                      Text(
                                        "Name",
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Description",
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Created At",
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Actions",
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                              rows: controllerWatch.paginatedItems.map((role) {
                                return _buildDataRow(
                                  context,
                                  role,
                                  controllerWatch,
                                  controllerRead,
                                  width,
                                );
                              }).toList(),
                            ),
                          ),
                  ],
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
      children: [
        Expanded(
          child: ListingSearchField(
            onChanged: onSearchChanged,
            pageTitle: _pageTitle,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        if (permissions?.canCreate ?? false)
          ElevatedButton.icon(
            onPressed: () {
              if (kIsMobile) {
                Sheet.showSheet(context, widget: const RoleCreate());
              } else {
                GeneralDialog.showRTLSheet(context, const RoleCreate());
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              "Add $_pageTitle",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
            ),
          ),
        const SizedBox(width: 10),
        if ((permissions?.canDelete ?? false) && _selectedRoles.isNotEmpty)
          ElevatedButton.icon(
            label: Text(
              "Delete",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.white),
            ),
            icon: const Icon(Iconsax.trash),
            onPressed: () async {
              final blockedNames = <String>[];
              for (var i in _selectedRoles) {
                final blocker = await RoleService.getRoleDeletionBlocker(
                  i.uid ?? '',
                );
                if (blocker != null) blockedNames.add(i.name);
              }
              if (!context.mounted) return;
              if (blockedNames.isNotEmpty) {
                FlushBar.show(
                  context,
                  '${blockedNames.join(', ')} '
                  '${blockedNames.length > 1 ? 'are' : 'is'} already mapped '
                  'to an employee. Please reassign those employees before '
                  'deleting.',
                  isSuccess: false,
                );
                return;
              }

              var result = await showDialog(
                context: context,
                builder: (context) => ConfirmDialog(
                  title: 'Delete',
                  content: 'Are you sure want to delete this $_pageTitle?',
                ),
                barrierDismissible: false,
              );
              if (result != null && result) {
                try {
                  futureLoading(context);
                  for (var i in _selectedRoles) {
                    await RoleService.deleteRole(uid: i.uid ?? '');
                  }
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  FlushBar.show(context, '$_pageTitle deleted successfully');
                  _selectedRoles.clear();
                  setState(() {});
                } catch (e) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  FlushBar.show(context, e.toString(), isSuccess: false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
            ),
          ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    RoleModel role,
    PaginatedDataController<RoleModel> controllerWatch,
    PaginatedDataController<RoleModel> controllerRead,
    double width,
  ) {
    bool isSelected = controllerWatch.selectedIds.contains(role.uid ?? '');
    return DataRow(
      selected: isSelected,
      onSelectChanged: role.isSuperAdmin
          ? null
          : (selected) {
              controllerRead.onSelected(role.uid ?? '', selected);
            },
      cells: [
        DataCell(Text(role.name)),
        DataCell(Text(role.description)),
        DataCell(Text(role.createdAt.listingDateTime)),
        DataCell(
          Row(
            children: [
              if ((permissions?.canEdit ?? false) && !role.isSuperAdmin)
                IconButton(
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
                ),
              if ((permissions?.canDelete ?? false) && !role.isSuperAdmin)
                IconButton(
                icon: const Icon(Iconsax.trash),
                color: AppColors.danger,
                splashRadius: 20,
                onPressed: () async {
                  final blocker = await RoleService.getRoleDeletionBlocker(
                    role.uid ?? '',
                  );
                  if (!context.mounted) return;
                  if (blocker != null) {
                    FlushBar.show(context, blocker, isSuccess: false);
                    return;
                  }

                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => ConfirmDialog(
                      title: 'Delete $_pageTitle',
                      content: 'Are you sure want to delete this $_pageTitle?',
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
