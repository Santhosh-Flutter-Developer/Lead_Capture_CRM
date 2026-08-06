import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/services/services.dart';
import 'bloc/tasks_bloc.dart';

const String _pageTitle = "Tasks";

class TasksListing extends StatelessWidget {
  const TasksListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskBloc()..add(StreamTasks()),
      child: const TaskListView(),
    );
  }
}

class TaskListView extends StatelessWidget {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaginatedDataController<TaskModel>(
        initialSortColumnIndex: 1,
        filterLogic: (task, query) {
          final q = query.toLowerCase();
          return task.taskName.toLowerCase().contains(q) ||
              (task.tags.map((e) => e.toLowerCase()).contains(q));
        },
        sortLogic: (a, b, col, asc) {
          int compare;
          switch (col) {
            case 0:
              compare = a.taskName.toLowerCase().compareTo(
                b.taskName.toLowerCase(),
              );
              break;
            case 2:
              compare = (a.deadline ?? DateTime.now()).compareTo(
                (b.deadline ?? DateTime.now()),
              );
              break;
            default:
              compare = (a.uid ?? '').compareTo(b.uid ?? '');
          }
          return asc ? compare : -compare;
        },
        getItemId: (task) => task.uid ?? '',
      ),
      child: const TaskListingView(),
    );
  }
}

class TaskListingView extends StatefulWidget {
  const TaskListingView({super.key});

  @override
  State<TaskListingView> createState() => _TaskListingViewState();
}

class _TaskListingViewState extends State<TaskListingView> {
  final List<TaskModel> _selectedTasks = [];
  PermissionModel? permissions;
  String _selectedView = 'Grid';
  String? _currentUid;
  bool _isAdmin = false;
  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    _currentUid = await Spdb.getUid();
    _isAdmin = await Spdb.isAdminLoggedIn();
    setState(() {});
  }

  Future<void> _refreshTasks(BuildContext context) async {
    context.read<TaskBloc>().add(StreamTasks());
  }

  final ScrollController _hScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final controllerRead = context.read<PaginatedDataController<TaskModel>>();
    final controllerWatch = context.watch<PaginatedDataController<TaskModel>>();

    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<TaskBloc, TaskState>(
        listenWhen: (previous, current) => current is TaskLoaded,
        listener: (context, state) {
          if (state is TaskLoaded) {
            controllerRead.setData(state.tasks);
          }
        },
        child: BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) return const WaitingLoading();

            if (state is TaskLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshTasks(context),
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
                    else if (_selectedView == 'Calendar') ...[
                      TaskCalendarListing(tasks: state.tasks),
                    ] else ...[
                      _buildMainBody(context, controllerWatch, controllerRead),
                    ],
                  ],
                ),
              );
            }

            if (state is TaskError) {
              return Center(
                child: SelectableText(
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

  Container _buildMainBody(
    BuildContext context,
    PaginatedDataController<TaskModel> controllerWatch,
    PaginatedDataController<TaskModel> controllerRead,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
              // if (tasks.isEmpty) {
              //   return const Padding(
              //     padding: EdgeInsets.all(20.0),
              //     child: Center(
              //       child: Text(
              //         "No tasks found.",
              //         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey),
              //       ),
              //     ),
              //   );
              // }

              return Scrollbar(
                controller: _hScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 4,
                radius: const Radius.circular(6),
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _hScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: true,
                      columnSpacing: 12,
                      horizontalMargin: 8,
                      sortColumnIndex: controllerWatch.sortColumnIndex,
                      sortAscending: controllerWatch.sortAscending,
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      headingTextStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      columns: [
                        DataColumn(
                          label: _sortableHeader("Task No", controllerRead),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: _sortableHeader("Name", controllerRead),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: Text(
                            "Active",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: _sortableHeader("Deadline", controllerRead),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: Text(
                            "Created By",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Assignee",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            "Action",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      rows: controllerWatch.paginatedItems
                          .map(
                            (task) => _buildDataRow(
                              context,
                              task,
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
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<TaskModel>(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return LayoutBuilder(
      builder: (context, constraints) {
        // final bool isMobile = constraints.maxWidth < 600;

        final addDeleteButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permissions?.canCreate ?? false) ...[
              ElevatedButton.icon(
                onPressed: () {
                  if (kIsMobile || width < 1000) {
                    Sheet.showSheet(context, widget: const TaskCreate());
                  } else {
                    GeneralDialog.showRTLSheet(context, const TaskCreate());
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  "Add $_pageTitle",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                ),
              ),
              const SizedBox(width: 10),
            ] else ...[
              ElevatedButton.icon(
                onPressed: null,
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  "Add $_pageTitle",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 10),
            if (permissions?.canDelete ?? false) ...[
              if (_selectedTasks.isNotEmpty)
                ElevatedButton.icon(
                  label: Text(
                    "Delete",
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                  ),
                  icon: const Icon(Iconsax.trash),
                  onPressed: () async {
                    final result = await showDialog(
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
                      // ✅ STEP 1: backup
                      final deletedTasks = List<TaskModel>.from(_selectedTasks);

                      futureLoading(context);

                      // ✅ STEP 2: delete
                      for (var task in deletedTasks) {
                        await TaskService.deleteTask(uid: task.uid ?? '');
                      }

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      // ✅ STEP 3: clear selection
                      _selectedTasks.clear();
                      setState(() {});

                      // ✅ STEP 4: UNDO
                      FlushBar.show(
                        context,
                        '$_pageTitle deleted successfully',
                        actionLabel: 'UNDO',
                        onActionPressed: () async {
                          for (var task in deletedTasks) {
                            await TaskService.restoreTask(task);
                          }

                          // 🔥 refresh list
                          context.read<TaskBloc>().add(StreamTasks());
                        },
                      );
                    } catch (e) {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      FlushBar.show(context, e.toString(), isSuccess: false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.white,
                  ),
                ),
            ] else ...[
              if (_selectedTasks.isNotEmpty) ...[
                ElevatedButton.icon(
                  label: Text(
                    "Delete",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  icon: Icon(Iconsax.trash),
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        );

        final viewToggle = Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kIsDesktop)
                IconButton(
                  tooltip: "Refresh",
                  icon: const Icon(Iconsax.refresh),
                  iconSize: 18,
                  onPressed: () => _refreshTasks(context),
                ),

              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  _selectedView = 'List';
                  setState(() {});
                },
                icon: const Icon(Icons.list),
                color: _selectedView == 'List'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Container(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              IconButton(
                onPressed: () {
                  _selectedView = 'Calendar';
                  setState(() {});
                },
                icon: const Icon(Iconsax.calendar_1, size: 18),
                color: _selectedView == 'Calendar'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );

        if (kIsMobile || width < 1000) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: addDeleteButtons,
              ),
              const SizedBox(height: 8),
              viewToggle,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [addDeleteButtons, viewToggle],
          );
        }
      },
    );
  }

  Widget _sortableHeader(String label, controllerRead) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_upward,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    TaskModel task,
    PaginatedDataController<TaskModel> controllerWatch,
    PaginatedDataController<TaskModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(task.uid);
    void openTask(BuildContext context, String uid) {
      if (kIsMobile || width < 1000) {
        Sheet.showSheet(context, widget: TaskView(uid: uid));
      } else {
        GeneralDialog.showRTLSheet(context, TaskView(uid: uid));
      }
    }

    DataCell dataCell(BuildContext context, Widget child, String uid) {
      return DataCell(
        InkWell(
          onTap: () => openTask(context, uid),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: child,
          ),
        ),
      );
    }

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(task.uid ?? '', selected);
        if (selected ?? false) {
          _selectedTasks.add(task);
        } else {
          _selectedTasks.remove(task);
        }
        setState(() {});
      },
      cells: [
        dataCell(
          context,
          SelectableText(
            task.taskNumber?.toString() ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          task.uid ?? '',
        ),

        dataCell(
          context,
          Text(
            task.taskName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          task.uid ?? '',
        ),

        dataCell(
          context,
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: task.completed
                  ? AppColors.success
                  : task.hasStarted
                  ? AppColors.blue
                  : AppColors.danger,
            ),
            child: Text(
              task.completed
                  ? 'Completed'
                  : task.hasStarted
                  ? 'Started'
                  : 'Not Started',
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: AppColors.white),
            ),
          ),
          task.uid ?? '',
        ),

        dataCell(
          context,
          Text(
            task.deadline?.listingDateTime ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          task.uid ?? '',
        ),

        dataCell(
          context,
          task.taskCreatedBy.uid.isNotEmpty
              ? CreatedByWidget(userData: task.taskCreatedBy)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: task.createdBy
                      .map((uid) => CacheService.getUserByUid(uid))
                      .where((user) => user != null)
                      .map((user) => CreatedByWidget(userData: user!))
                      .toList(),
                ),
          task.uid ?? '',
        ),
        dataCell(
          context,
          SizedBox(
            width: 120,
            child: Text(
              task.assignees
                  .map((e) => CacheService.getUserByUid(e)?.name ?? '')
                  .where((name) => name.isNotEmpty)
                  .join(',\n'),
              softWrap: true,
              maxLines: null,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          task.uid ?? '',
        ),

        DataCell(
          Row(
            children: [
              if ((permissions?.canEdit ?? false) &&
                  (_isAdmin ||
                      task.taskCreatedBy.uid == _currentUid ||
                      (task.taskCreatedBy.uid.isEmpty &&
                          task.createdBy.contains(_currentUid ?? '')))) ...[
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  onPressed: () {
                    if (kIsMobile || width < 1000) {
                      Sheet.showSheet(
                        context,
                        widget: TaskEdit(uid: task.uid ?? ''),
                      );
                    } else {
                      GeneralDialog.showRTLSheet(
                        context,
                        TaskEdit(uid: task.uid ?? ''),
                      );
                    }
                  },
                  color: Theme.of(context).colorScheme.secondary,
                  splashRadius: 20,
                ),
              ] else ...[
                IconButton(
                  icon: Icon(
                    Iconsax.edit,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: null,
                ),
              ],
              if (permissions?.canDelete ?? false) ...[
                IconButton(
                  icon: const Icon(Iconsax.trash),
                  color: Theme.of(context).colorScheme.error,
                  splashRadius: 20,
                  tooltip: 'Delete $_pageTitle',
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => ConfirmDialog(
                        title: 'Delete $_pageTitle',
                        content: 'Are you sure you want to delete this task?',
                      ),
                    );

                    if (result != true) return;

                    try {
                      final deletedTask = task;

                      await TaskService.deleteTask(uid: task.uid ?? '');

                      if (!mounted) return;

                      FlushBar.show(
                        context,
                        '$_pageTitle deleted successfully',
                        actionLabel: 'UNDO',
                        onActionPressed: () async {
                          await TaskService.restoreTask(deletedTask);

                          // ✅ refresh AFTER undo
                          context.read<TaskBloc>().add(StreamTasks());
                        },
                        // onDismissed: () {
                        //   // ✅ refresh AFTER snackbar disappears (no undo)
                        //   context.read<TaskBloc>().add(StreamTasks());
                        // },
                      );
                    } catch (e, st) {
                      await ErrorService.recordError(e, st);
                      FlushBar.show(context, e.toString(), isSuccess: false);
                    }
                  },
                ),
              ] else ...[
                IconButton(
                  icon: Icon(
                    Iconsax.trash,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Widget _searchBox({required ValueChanged<String> onSearchChanged}) {
  //   return SizedBox(
  //     width: 200,
  //     child: ListingSearchField(
  //       onChanged: onSearchChanged,
  //       pageTitle: _pageTitle,
  //     ),
  //   );
  // }
}
