import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iconsax/iconsax.dart';

import 'package:provider/provider.dart';

import '/models/models.dart';

import '/views/views.dart';

import '/utils/utils.dart';

import '/theme/theme.dart';

import '/services/services.dart';

import 'bloc/lead_status_bloc.dart';



const String _pageTitle = "Lead Status";



class LeadStatusListing extends StatelessWidget {

  const LeadStatusListing({super.key});



  @override

  Widget build(BuildContext context) {

    return BlocProvider(

      create: (context) => LeadStatusBloc()..add(StreamLeadStatus()),

      child: ChangeNotifierProvider(

        create: (context) => PaginatedDataController<LeadStatusModel>(

          initialSortColumnIndex: 1,

          filterLogic: (leadStatus, query) {

            final q = query.toLowerCase();

            return leadStatus.name.toLowerCase().contains(q) ||

                leadStatus.name.toLowerCase().contains(q);

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

          getItemId: (leadStatus) => leadStatus.uid ?? '',

        ),

        child: const LeadStatusListingView(),

      ),

    );

  }

}



class LeadStatusListingView extends StatefulWidget {

  const LeadStatusListingView({super.key});



  @override

  State<LeadStatusListingView> createState() => _LeadStatusListingViewState();

}



class _LeadStatusListingViewState extends State<LeadStatusListingView> {

  final List<LeadStatusModel> _selectedLeadStatus = [];

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



  Future<void> _refreshLeadStatus(BuildContext context) async {

    context.read<LeadStatusBloc>().add(StreamLeadStatus());

  }



  @override

  Widget build(BuildContext context) {

    final width = MediaQuery.of(context).size.width;

    final controllerRead = context

        .read<PaginatedDataController<LeadStatusModel>>();

    final controllerWatch = context

        .watch<PaginatedDataController<LeadStatusModel>>();



    return Scaffold(

      appBar: kIsMobile || width < 1000

          ? AppBar(leading: Back(), title: Text(_pageTitle))

          : null,

      body: BlocListener<LeadStatusBloc, LeadStatusState>(

        listenWhen: (previous, current) => current is LeadStatusLoaded,

        listener: (context, state) {

          if (state is LeadStatusLoaded) {

            controllerRead.setData(state.leadStatus);

          }

        },

        child: BlocBuilder<LeadStatusBloc, LeadStatusState>(

          builder: (context, state) {

            if (state is LeadStatusLoading) {

              return const WaitingLoading();

            }



            if (state is LeadStatusLoaded) {

              if (!(permissions?.canView ?? false)) {

                return buildNoPermissionView(context);

              }

              return RefreshIndicator(

                onRefresh: () => _refreshLeadStatus(context),

                child: ListView(

                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.all(24.0),

                  children: [

                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),

                    const SizedBox(height: 10),

                    _buildActionRow(context, state.leadStatus),

                    const SizedBox(height: 20),

                    controllerWatch.paginatedItems.isEmpty

                        ? NoData(

                            text: state.leadStatus.isEmpty

                                ? "No lead statuses available"

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

                                                  (leadStatus) => _buildDataRow(

                                                    context,

                                                    leadStatus,

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

                                  child: PaginationControls<LeadStatusModel>(),

                                ),

                              ],

                            ),

                          ),

                  ],

                ),

              );

            }



            if (state is LeadStatusError) {

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



  Widget _buildActionRow(context, List<LeadStatusModel> leadStatusList) {

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

                          widget: const LeadStatusCreate(),

                        );

                      } else {

                        GeneralDialog.showRTLSheet(

                          context,

                          const LeadStatusCreate(),

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

            if (_selectedLeadStatus.isNotEmpty) ...[

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

                        if (_selectedLeadStatus.isEmpty) return;



                        // ✅ STEP 0: check assignment

                        for (var status in _selectedLeadStatus) {

                          final isAssigned =

                              await LeadStatusService.isLeadStatusAssigned(

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

                                  'One or more selected lead statuses are associated with leads and cannot be deleted.',

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

                          final deletedStatuses = _selectedLeadStatus

                              .map((e) => e.copyWith())

                              .toList();



                          // ✅ STEP 3: loader

                          futureLoading(context);



                          // ✅ STEP 4: DELETE (use service)

                          for (var status in deletedStatuses) {

                            await LeadStatusService.deleteLeadStatus(

                              uid: status.uid ?? '',

                            );

                          }



                          // ✅ STEP 5: close loader

                          if (Navigator.canPop(context)) Navigator.pop(context);



                          // ✅ STEP 6: clear selection

                          _selectedLeadStatus.clear();

                          setState(() {});



                          // ✅ STEP 7: UNDO

                          FlushBar.show(

                            context,

                            '$_pageTitle deleted successfully',

                            actionLabel: 'UNDO',

                            onActionPressed: () async {

                              for (var status in deletedStatuses) {

                                if (status.uid == null) continue;



                                await LeadStatusService.restoreLeadStatus(

                                  status,

                                );

                              }



                              if (!context.mounted) return;



                              // 🔥 refresh UI

                              context.read<LeadStatusBloc>().add(

                                StreamLeadStatus(),

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

                  color: leadStatusList.isNotEmpty

                      ? Theme.of(context).colorScheme.onSecondary

                      : Theme.of(context).colorScheme.onSurfaceVariant,

                ),

              ),

              icon: const Icon(Iconsax.arrange_circle),

              onPressed: leadStatusList.isNotEmpty

                  ? () {

                      if (kIsMobile || width < 1000) {

                        Sheet.showSheet(

                          context,

                          widget: LeadStatusReorder(

                            leadStatusList: leadStatusList,

                          ),

                        );

                      } else {

                        GeneralDialog.showRTLSheet(

                          context,

                          LeadStatusReorder(leadStatusList: leadStatusList),

                        );

                      }

                    }

                  : null,

              style: ElevatedButton.styleFrom(

                backgroundColor: leadStatusList.isNotEmpty

                    ? Theme.of(context).colorScheme.secondary

                    : Theme.of(context).colorScheme.surfaceContainerHighest,

                foregroundColor: leadStatusList.isNotEmpty

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

            onPressed: () => _refreshLeadStatus(context),

            iconSize: 18,

          ),

      ],

    );

  }



  DataRow _buildDataRow(

    BuildContext context,

    LeadStatusModel leadStatus,

    PaginatedDataController<LeadStatusModel> controllerWatch,

    PaginatedDataController<LeadStatusModel> controllerRead,

  ) {

    final width = MediaQuery.of(context).size.width;

    bool isSelected = controllerWatch.selectedIds.contains(leadStatus.uid);

    return DataRow(

      selected: isSelected,

      onSelectChanged: (selected) {

        controllerRead.onSelected(leadStatus.uid ?? '', selected);

        if (selected ?? false) {

          _selectedLeadStatus.add(leadStatus);

        } else {

          _selectedLeadStatus.remove(leadStatus);

        }

        setState(() {});

      },

      cells: [

        DataCell(

          Text(

            leadStatus.orderNumber.toString(),

            style: Theme.of(

              context,

            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),

          ),

        ),

        DataCell(

          Text(

            leadStatus.name,

            style: Theme.of(

              context,

            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),

          ),

        ),

        DataCell(Icon(Icons.circle, color: Color(leadStatus.color))),

        DataCell(

          Text(

            leadStatus.createdAt.listingDateTime,

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),

        DataCell(CreatedByWidget(userData: leadStatus.createdBy)),

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

                            widget: LeadStatusEdit(uid: leadStatus.uid ?? ''),

                          );

                        } else {

                          GeneralDialog.showRTLSheet(

                            context,

                            LeadStatusEdit(uid: leadStatus.uid ?? ''),

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

                            await LeadStatusService.isLeadStatusAssigned(

                              leadStatus.uid ?? '',

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

                                'This lead status is assigned to one or more leads and cannot be deleted.',

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

                          final deletedStatus = leadStatus.copyWith();



                          // ✅ STEP 3: DELETE (use service, NOT bloc)

                          await LeadStatusService.deleteLeadStatus(

                            uid: leadStatus.uid ?? '',

                          );



                          if (!context.mounted) return;



                          // ✅ STEP 4: UNDO

                          FlushBar.show(

                            context,

                            '$_pageTitle deleted successfully',

                            actionLabel: 'UNDO',

                            onActionPressed: () async {

                              if (deletedStatus.uid == null) return;



                              await LeadStatusService.restoreLeadStatus(

                                deletedStatus,

                              );



                              if (!context.mounted) return;



                              // ✅ refresh UI

                              context.read<LeadStatusBloc>().add(

                                StreamLeadStatus(),

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

