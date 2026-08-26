import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iconsax/iconsax.dart';

import 'package:provider/provider.dart';

import '/models/models.dart';

import '/views/views.dart';

import '/utils/utils.dart';

import '/theme/theme.dart';

import '/services/services.dart';

import 'bloc/projects_bloc.dart';



const String _pageTitle = "Projects";



class ProjectsListing extends StatelessWidget {

  const ProjectsListing({super.key});



  @override

  Widget build(BuildContext context) {

    return BlocProvider(

      create: (context) => ProjectsBloc()..add(StreamProjects()),

      child: ChangeNotifierProvider(

        create: (context) => PaginatedDataController<ProjectModel>(

          initialSortColumnIndex: 0,

          filterLogic: (project, query) {

            final q = query.toLowerCase();

            return project.projectName.toLowerCase().contains(q) ||

                project.projectName.toLowerCase().contains(q);

          },

          sortLogic: (a, b, col, asc) {

            int compare;

            switch (col) {

              case 0:

                //   compare = a.projectId

                //       .toLowerCase()

                //       .compareTo(b.projectId.toLowerCase());

                //   break;

                // case 1:

                compare = a.projectName.toLowerCase().compareTo(

                  b.projectName.toLowerCase(),

                );

                break;

              case 2:

                compare = (a.projectCode ?? '').toLowerCase().compareTo(

                  (b.projectCode ?? '').toLowerCase(),

                );

                break;



              default:

                compare = (a.projectName).compareTo(b.projectName);

                break;

            }

            return asc ? compare : -compare;

          },

          getItemId: (project) => project.uid ?? '',

        ),

        child: const ProjectsListingView(),

      ),

    );

  }

}



class ProjectsListingView extends StatefulWidget {

  const ProjectsListingView({super.key});



  @override

  State<ProjectsListingView> createState() => _ProjectsListingViewState();

}



class _ProjectsListingViewState extends State<ProjectsListingView> {

  final List<ProjectModel> _selectedProjects = [];

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



  Future<void> _refreshProjects(BuildContext context) async {

    context.read<ProjectsBloc>().add(StreamProjects());

  }



  @override

  Widget build(BuildContext context) {

    final width = MediaQuery.of(context).size.width;

    final controllerRead = context

        .read<PaginatedDataController<ProjectModel>>();

    final controllerWatch = context

        .watch<PaginatedDataController<ProjectModel>>();



    return Scaffold(

      appBar: kIsMobile || width < 1000

          ? AppBar(leading: Back(), title: Text(_pageTitle))

          : null,

      body: BlocListener<ProjectsBloc, ProjectsState>(

        listenWhen: (previous, current) => current is ProjectsLoaded,

        listener: (context, state) {

          if (state is ProjectsLoaded) {

            controllerRead.setData(state.projects);

          }

        },

        child: BlocBuilder<ProjectsBloc, ProjectsState>(

          builder: (context, state) {

            if (state is ProjectsLoading) {

              return const WaitingLoading();

            }



            if (state is ProjectsLoaded) {

              if (!_permissionsLoaded) {

                return const WaitingLoading();

              }

              if (!(permissions?.canView ?? false)) {

                return buildNoPermissionView(context);

              }

              return RefreshIndicator(

                onRefresh: () => _refreshProjects(context),

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

                                        columns: [

                                          DataColumn(

                                            label: Text(

                                              "Project Name",

                                              style: Theme.of(

                                                context,

                                              ).textTheme.bodySmall,

                                            ),

                                            onSort: controllerRead.setSort,

                                          ),

                                          DataColumn(

                                            label: Text(

                                              "Project Code",

                                              style: Theme.of(

                                                context,

                                              ).textTheme.bodySmall,

                                            ),

                                            onSort: controllerRead.setSort,

                                          ),

                                          DataColumn(

                                            label: Text(

                                              "Lead",

                                              style: Theme.of(

                                                context,

                                              ).textTheme.bodySmall,

                                            ),

                                          ),

                                          DataColumn(

                                            label: Text(

                                              "Deadline",

                                              style: Theme.of(

                                                context,

                                              ).textTheme.bodySmall,

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

                                              (project) => _buildDataRow(

                                                context,

                                                project,

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

                              child: PaginationControls<ProjectModel>(),

                            ),

                          ],

                        ),

                      ),

                  ],

                ),

              );

            }



            if (state is ProjectsError) {

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

        Row(

          children: [

            if (permissions?.canCreate ?? false) ...[

              ElevatedButton.icon(

                onPressed: () {

                  if (kIsMobile || width < 1000) {

                    Sheet.showSheet(context, widget: const ProjectCreate());

                  } else {

                    GeneralDialog.showRTLSheet(context, const ProjectCreate());

                  }

                },

                icon: const Icon(Icons.add, size: 18),

                label: Text(

                  "Add $_pageTitle",

                  style: Theme.of(

                    context,

                  ).textTheme.bodySmall?.copyWith(color: Colors.white),

                ),

                style: ElevatedButton.styleFrom(

                  backgroundColor: AppColors.success,

                  foregroundColor: AppColors.white,

                ),

              ),

              const SizedBox(width: 10),

            ],

            if (permissions?.canDelete ?? false) ...[

              if (_selectedProjects.isNotEmpty) ...[

                ElevatedButton.icon(

                  label: Text(

                    "Delete",

                    style: Theme.of(

                      context,

                    ).textTheme.bodySmall?.copyWith(color: Colors.white),

                  ),

                  icon: const Icon(Iconsax.trash),

                  onPressed: () async {

                    if (_selectedProjects.isEmpty) return;



                    for (var project in _selectedProjects) {

                      final isAssigned = await ProjectService.isProjectAssigned(

                        project.uid ?? '',

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

                              'One or more selected projects are associated with tasks.',

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



                    // ✅ STEP 1: CONFIRM

                    final confirm = await showDialog<bool>(

                      context: context,

                      builder: (context) => ConfirmDialog(

                        title: 'Delete',

                        content:

                            'Are you sure want to delete this $_pageTitle?',

                      ),

                      barrierDismissible: false,

                    );



                    if (confirm != true) return;



                    try {

                      // ✅ STEP 2: BACKUP

                      final deletedProjects = _selectedProjects

                          .map((e) => e.copyWith())

                          .toList();



                      // ✅ STEP 3: DELETE (use service, NOT bloc)

                      for (var project in deletedProjects) {

                        await ProjectService.deleteProject(

                          uid: project.uid ?? '',

                        );

                      }



                      // ✅ STEP 4: CLEAR UI

                      _selectedProjects.clear();

                      setState(() {});



                      if (!context.mounted) return;



                      // ✅ STEP 5: UNDO

                      FlushBar.show(

                        context,

                        'Projects deleted successfully',

                        actionLabel: 'UNDO',

                        onActionPressed: () async {

                          for (var project in deletedProjects) {

                            if (project.uid == null) continue;



                            await ProjectService.restoreProject(project);

                          }



                          if (!context.mounted) return;



                          // 🔥 refresh UI

                          context.read<ProjectsBloc>().add(StreamProjects());

                        },

                      );

                    } catch (e, st) {

                      await ErrorService.recordError(e, st);



                      FlushBar.show(

                        context,

                        'Failed to delete projects: $e',

                        isSuccess: false,

                      );

                    }

                  },

                  style: ElevatedButton.styleFrom(

                    backgroundColor: AppColors.danger,

                    foregroundColor: AppColors.white,

                  ),

                ),

              ],

            ],

          ],

        ),

        if (kIsDesktop)

          IconButton(

            tooltip: "Refresh",

            icon: const Icon(Iconsax.refresh),

            onPressed: () => _refreshProjects(context),

            iconSize: 18,

          ),

      ],

    );

  }



  DataRow _buildDataRow(

    BuildContext context,

    ProjectModel project,

    PaginatedDataController<ProjectModel> controllerWatch,

    PaginatedDataController<ProjectModel> controllerRead,

  ) {

    final width = MediaQuery.of(context).size.width;

    bool isSelected = controllerWatch.selectedIds.contains(project.uid);

    return DataRow(

      selected: isSelected,

      onSelectChanged: (selected) {

        controllerRead.onSelected(project.uid ?? '', selected);

        if (selected ?? false) {

          _selectedProjects.add(project);

        } else {

          _selectedProjects.remove(project);

        }

        setState(() {});

      },

      cells: [

        DataCell(

          Text(

            project.projectName,

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),

        DataCell(

          Text(

            project.projectCode ?? '',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),

        DataCell(

          Text(

            CacheService.getUserByUid(project.projectOwner)?.name ?? '',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),

        DataCell(

          Text(

            project.deadline != null ? project.deadline!.listingDateTime : '',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),

        DataCell(CreatedByWidget(userData: project.createdBy)),

        DataCell(

          Row(

            children: [

              if ((permissions?.canEdit ?? false)) ...[

                IconButton(

                  icon: const Icon(Iconsax.edit),

                  onPressed: () {

                    if (kIsMobile || width < 1000) {

                      Sheet.showSheet(

                        context,

                        widget: ProjectEdit(uid: project.uid ?? ''),

                      );

                    } else {

                      GeneralDialog.showRTLSheet(

                        context,

                        ProjectEdit(uid: project.uid ?? ''),

                      );

                    }

                  },

                  color: Theme.of(context).colorScheme.secondary,

                  splashRadius: 20,

                ),

              ],

              if (permissions?.canDelete ?? false) ...[

                IconButton(

                  icon: const Icon(Iconsax.trash),

                  color: Theme.of(context).colorScheme.error,

                  splashRadius: 20,

                  onPressed: () async {

                    // ✅ STEP 0: CHECK ASSIGNMENT

                    final isAssigned = await ProjectService.isProjectAssigned(

                      project.uid ?? '',

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

                            'This project is associated with one or more tasks.',

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



                    // ✅ STEP 1: CONFIRM

                    final confirm = await showDialog<bool>(

                      context: context,

                      builder: (_) => ConfirmDialog(

                        title: 'Delete $_pageTitle',

                        content:

                            'Are you sure you want to delete this $_pageTitle?',

                      ),

                    );



                    if (confirm != true) return;



                    try {

                      // ✅ STEP 2: BACKUP

                      final deletedProject = project.copyWith();



                      // ✅ STEP 3: DELETE (use service, NOT bloc)

                      await ProjectService.deleteProject(

                        uid: project.uid ?? '',

                      );



                      if (!context.mounted) return;



                      // ✅ STEP 4: UNDO

                      FlushBar.show(

                        context,

                        'Project deleted successfully',

                        actionLabel: 'UNDO',

                        onActionPressed: () async {

                          if (deletedProject.uid == null) return;



                          await ProjectService.restoreProject(deletedProject);



                          if (!context.mounted) return;



                          // ✅ refresh UI

                          context.read<ProjectsBloc>().add(StreamProjects());

                        },

                      );

                    } catch (e, st) {

                      await ErrorService.recordError(e, st);



                      FlushBar.show(

                        context,

                        'Failed to delete project: $e',

                        isSuccess: false,

                      );

                    }

                  },

                ),

              ],

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

