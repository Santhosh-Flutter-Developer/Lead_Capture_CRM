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
const double _wideBreakpoint = 1000;

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
  bool _permissionsLoaded = false;
  String _selectedView = 'Grid';
  String? _currentUid;
  bool _isAdmin = false;
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    _currentUid = await Spdb.getUid();
    _isAdmin = await Spdb.isAdminLoggedIn();
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshTasks(BuildContext context) async {
    context.read<TaskBloc>().add(StreamTasks());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<TaskModel>>();
    final controllerWatch = context.watch<PaginatedDataController<TaskModel>>();
    final isWide = _isWide(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text(_pageTitle),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
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
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshTasks(context),
                child: Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: ListView(
                      controller: _vScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                      children: [
                        if (isWide) ...[
                          _buildHeaderBanner(context, state.tasks.length),
                          const SizedBox(height: 20),
                        ],
                        _buildToolbar(context, controllerRead),
                        const SizedBox(height: 18),
                        if (controllerWatch.paginatedItems.isEmpty)
                          const NoData(text: "No matching records found")
                        else if (_selectedView == 'Calendar') ...[
                          TaskCalendarListing(tasks: state.tasks),
                        ] else ...[
                          _buildMainBody(
                            context,
                            controllerWatch,
                            controllerRead,
                          ),
                        ],
                      ],
                    ),
                  ),
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

  // ---------------------------------------------------------------------
  // Header banner (desktop only)
  // ---------------------------------------------------------------------
  Widget _buildHeaderBanner(BuildContext context, int totalTasks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052D4).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Iconsax.task_square,
              color: AppColors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tasks",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Plan, assign and track work across your team",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$totalTasks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalTasks == 1 ? "Task" : "Tasks",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Toolbar: search + add + delete + view toggle + refresh
  // ---------------------------------------------------------------------
  Widget _buildToolbar(
    BuildContext context,
    PaginatedDataController<TaskModel> controllerRead,
  ) {
    final isWide = _isWide(context);

    final buttons = <Widget>[
      (permissions?.canCreate ?? false)
          ? _gradientButton(
              context: context,
              icon: Icons.add_rounded,
              label: "Add $_pageTitle",
              colors: _brandGradient,
              onPressed: () {
                if (kIsMobile || !isWide) {
                  Sheet.showSheet(context, widget: const TaskCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const TaskCreate());
                }
              },
            )
          : _disabledButton(
              context,
              icon: Icons.add_rounded,
              label: "Add $_pageTitle",
            ),
      if (_selectedTasks.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedTasks.length})",
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkDelete,
        ),
      _buildViewToggle(context),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                SizedBox(width: 260, child: _searchBox(controllerRead)),
                const Spacer(),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchBox(controllerRead),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!kIsMobile)
            _iconCircleButton(
              context,
              icon: Iconsax.refresh,
              tooltip: "Refresh",
              background: Colors.transparent,
              iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: () => _refreshTasks(context),
            ),
          _viewToggleButton(
            context,
            icon: Icons.list_rounded,
            selected: _selectedView == 'List',
            onTap: () => setState(() => _selectedView = 'List'),
          ),
          _viewToggleButton(
            context,
            icon: Iconsax.calendar_1,
            selected: _selectedView == 'Calendar',
            onTap: () => setState(() => _selectedView = 'Calendar'),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? AppColors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _searchBox(PaginatedDataController<TaskModel> controllerRead) {
    return _TaskSearchField(onChanged: controllerRead.setSearch);
  }

  Widget _gradientButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabledButton(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.grey500),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _iconCircleButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Table card
  // ---------------------------------------------------------------------
  Widget _buildMainBody(
    BuildContext context,
    PaginatedDataController<TaskModel> controllerWatch,
    PaginatedDataController<TaskModel> controllerRead,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        showCheckboxColumn: true,
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        sortColumnIndex: controllerWatch.sortColumnIndex,
                        sortAscending: controllerWatch.sortAscending,
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.06),
                        ),
                        headingTextStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        columns: [
                          DataColumn(
                            label: const Text("Task No"),
                            onSort: controllerRead.setSort,
                          ),
                          DataColumn(
                            label: const Text("Name"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Active")),
                          DataColumn(
                            label: const Text("Deadline"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Assignee")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(
                          controllerWatch.paginatedItems.length,
                          (index) => _buildDataRow(
                            context,
                            controllerWatch.paginatedItems[index],
                            controllerWatch,
                            controllerRead,
                            index,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<TaskModel>(),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, TaskModel task) {
    final color = task.completed
        ? AppColors.success
        : task.hasStarted
        ? AppColors.info
        : AppColors.warning;
    final label = task.completed
        ? 'Completed'
        : task.hasStarted
        ? 'Started'
        : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    TaskModel task,
    PaginatedDataController<TaskModel> controllerWatch,
    PaginatedDataController<TaskModel> controllerRead,
    int index,
  ) {
    final width = MediaQuery.of(context).size.width;
    final isSelected = controllerWatch.selectedIds.contains(task.uid);

    void openTask(BuildContext context, String uid) {
      if (kIsMobile || width < _wideBreakpoint) {
        Sheet.showSheet(context, widget: TaskView(uid: uid));
      } else {
        GeneralDialog.showRTLSheet(context, TaskView(uid: uid));
      }
    }

    DataCell dataCell(Widget child, String uid) {
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
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
        }
        return index.isEven
            ? Colors.transparent
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
      }),
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
          Text(
            task.taskNumber?.toString() ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          task.uid ?? '',
        ),
        dataCell(
          Text(
            task.taskName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          task.uid ?? '',
        ),
        dataCell(_statusPill(context, task), task.uid ?? ''),
        dataCell(
          Text(
            task.deadline?.listingDateTime ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          task.uid ?? '',
        ),
        dataCell(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (permissions?.canEdit ?? false)
                _iconCircleButton(
                  context,
                  icon: Iconsax.edit,
                  tooltip: "Edit",
                  background: AppColors.info.withValues(alpha: 0.12),
                  iconColor: AppColors.info,
                  onPressed: () {
                    final form = TaskEdit(uid: task.uid ?? '');
                    if (kIsMobile || width < _wideBreakpoint) {
                      Sheet.showSheet(context, widget: form);
                    } else {
                      GeneralDialog.showRTLSheet(context, form);
                    }
                  },
                ),
              if (permissions?.canDelete ?? false) ...[
                const SizedBox(width: 8),
                _iconCircleButton(
                  context,
                  icon: Iconsax.trash,
                  tooltip: "Delete $_pageTitle",
                  background: AppColors.danger.withValues(alpha: 0.12),
                  iconColor: AppColors.danger,
                  onPressed: () => _onDeleteTap(task),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onDeleteTap(TaskModel task) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete $_pageTitle',
        content: 'Are you sure you want to delete this task?',
      ),
    );

    if (result != true) return;
    if (!mounted) return;

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
          context.read<TaskBloc>().add(StreamTasks());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedTasks.isEmpty) return;

    final result = await showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete',
        content: 'Are you sure want to delete this $_pageTitle?',
      ),
      barrierDismissible: false,
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedTasks = List<TaskModel>.from(_selectedTasks);

      futureLoading(context);

      for (var task in deletedTasks) {
        await TaskService.deleteTask(uid: task.uid ?? '');
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _selectedTasks.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var task in deletedTasks) {
            await TaskService.restoreTask(task);
          }
          context.read<TaskBloc>().add(StreamTasks());
        },
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}

// ---------------------------------------------------------------------
// A more polished, colorful search field for the Tasks toolbar.
// ---------------------------------------------------------------------
class _TaskSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _TaskSearchField({required this.onChanged});

  @override
  State<_TaskSearchField> createState() => _TaskSearchFieldState();
}

class _TaskSearchFieldState extends State<_TaskSearchField> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _focused
              ? primary.withValues(alpha: 0.55)
              : Theme.of(context).colorScheme.outlineVariant,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: (val) {
          setState(() => _hasText = val.isNotEmpty);
          widget.onChanged(val);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search tasks',
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(
                  Iconsax.search_normal_1,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  splashRadius: 16,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _hasText = false);
                    widget.onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 4,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
