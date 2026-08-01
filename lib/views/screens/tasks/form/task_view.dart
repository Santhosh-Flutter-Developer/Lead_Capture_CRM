import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class TaskViewColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
}

class TaskView extends StatefulWidget {
  final String uid;
  const TaskView({super.key, required this.uid});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> with TickerProviderStateMixin {
  late Future<TaskModel> _future;
  late TaskModel _taskModel;
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();

  String? currentUid;
  String _cid = '';
  Stream<List<TaskCommentModel>>? _commentsStream;
  Stream<List<TaskHistoryModel>>? _historyStream;
  bool _isSending = false;
  bool isParticipant = false;
  bool _isActionLoading = false;

  Timer? _liveTimer;
  Duration get _taskDuration {
    if (_taskModel.startedTime == null) return Duration.zero;

    final end = _taskModel.completedTime ?? DateTime.now();
    return end.difference(_taskModel.startedTime!);
  }

  List<FlSpot> _buildLiveSpots(int totalMinutes) {
    final spots = <FlSpot>[];

    for (int i = 0; i <= totalMinutes; i += 30) {
      spots.add(FlSpot(i / 60, i.toDouble()));
    }

    // Live running task → add current moment
    if (_taskModel.completedTime == null) {
      final nowMinutes = DateTime.now()
          .difference(_taskModel.startedTime!)
          .inMinutes
          .toDouble();

      spots.add(FlSpot(nowMinutes / 60, nowMinutes));
    }

    return spots;
  }

  double get _totalHours => _taskDuration.inMinutes / 60;

  @override
  void initState() {
    super.initState();
    _future = TaskService.getTask(uid: widget.uid);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    Spdb.getUid().then((uid) {
      if (mounted) setState(() => currentUid = uid);
    });
    Spdb.getCid().then((cid) {
      if (mounted) {
        setState(() {
          _cid = cid ?? '';
          _commentsStream = TaskService.streamComments(
            cid: _cid,
            taskId: widget.uid,
          );
          _historyStream = TaskService.streamTaskHistory(
            cid: _cid,
            taskId: widget.uid,
          );
        });
      }
    });
    // _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    //   if (!mounted) return;
    //   if (!(_taskModel.hasStarted && !_taskModel.completed)) return;
    //   setState(() {});
    // });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment(String taskId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await TaskService.addComment(taskId: taskId, comment: text);
      _commentController.clear();
    } catch (e) {
      FlushBar.show(context, 'Failed to add comment', isSuccess: false);
    }
    setState(() => _isSending = false);
  }

  Future<void> _startTask() async {
    if (_taskModel.uid == null) return;

    setState(() => _isActionLoading = true);

    try {
      final startTime = DateTime.now();

      await TaskService.startTask(taskId: _taskModel.uid!);

      setState(() {
        _taskModel.hasStarted = true;
        _taskModel.completed = false;
        _taskModel.startedTime = startTime;
      });

      FlushBar.show(context, "Task started", isSuccess: true);
    } catch (e) {
      FlushBar.show(
        context,
        e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _completeTask() async {
    if (_taskModel.uid == null) return;

    setState(() => _isActionLoading = true);

    try {
      final endTime = DateTime.now();

      await TaskService.completeTask(taskId: _taskModel.uid!);

      setState(() {
        _taskModel.completed = true;
        _taskModel.hasStarted = false;
        _taskModel.completedTime = endTime;
      });

      FlushBar.show(context, "Task marked completed", isSuccess: true);
    } catch (e) {
      FlushBar.show(context, "Failed to complete task", isSuccess: false);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const WaitingLoading();

    return FutureBuilder<TaskModel>(
      future: _future,
      builder: (context, taskSnap) {
        if (taskSnap.connectionState == ConnectionState.waiting) {
          return const WaitingLoading();
        }
        if (!taskSnap.hasData) return ErrorDisplay(error: "Task not found");

        _taskModel = taskSnap.data!;
        isParticipant =
            currentUid != null &&
            (_taskModel.assignees.contains(currentUid!) ||
                _taskModel.createdBy.contains(currentUid!));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: FormWidgets.buildHeader(
            context: context,
            title: "Task Details",
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 1000;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isWide ? 7 : 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [_buildMainContent()],
                          ),
                        ),
                      ),
                      if (isWide)
                        Container(
                          width: 380,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          child: _buildSidePanel(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTaskHeader(),
        const SizedBox(height: 24),
        _buildInfoGrid(),
        const SizedBox(height: 32),
        _buildSectionLabel("TASK DESCRIPTION"),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            _taskModel.description.isNotEmpty
                ? _taskModel.description
                : "No description provided for this task.",
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (_taskModel.attachments.isNotEmpty) ...[
          _buildSectionLabel("ATTACHMENTS"),
          const SizedBox(height: 12),
          _buildAttachmentsGrid(),
          const SizedBox(height: 32),
        ],
        _buildModernTabs(),
      ],
    );
  }

  Widget _buildTaskHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _taskModel.highPriority
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      (_taskModel.highPriority
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _taskModel.highPriority ? Iconsax.flash : Iconsax.task,
                    size: 14,
                    color: _taskModel.highPriority
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _taskModel.highPriority ? "URGENT" : "STANDARD",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _taskModel.highPriority
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge(),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _taskModel.taskName,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (_taskModel.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _taskModel.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      "#$tag",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge() {
    final bool isCompleted = _taskModel.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isCompleted ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        isCompleted
            ? "COMPLETED"
            : (_taskModel.hasStarted ? "IN PROGRESS" : "PENDING"),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isCompleted ? AppColors.success : AppColors.warning,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final daysLeft =
        _taskModel.deadline?.difference(DateTime.now()).inDays ?? 0;
    return Row(
      children: [
        _infoBox(
          Iconsax.calendar_1,
          "Deadline",
          _taskModel.deadline?.formatDate ?? "No date",
          daysLeft < 0
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 16),
        _infoBox(
          Iconsax.timer_1,
          "Reminder",
          _taskModel.reminder?.listingDateTime ?? "Disabled",
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _infoBox(IconData icon, String label, String val, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAttachmentsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _taskModel.attachments.length,
      itemBuilder: (context, index) {
        final file = _taskModel.attachments[index];
        return InkWell(
          onTap: () async {
            await Download.downloadFromUrl(context, file.url, file.name);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Iconsax.document_text,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${file.size} KB",
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_circle_down,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: "Comments"),
              Tab(text: "Activity History"),
              Tab(text: "Time Tracking"),
            ],
          ),
        ),
        const SizedBox(height: 20),
        IndexedStack(
          index: _tabController.index,
          children: [
            _buildCommentsTab(),
            _buildHistoryTab(),
            _buildTimeTrackingTab(),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsTab() {
    return StreamBuilder<List<TaskCommentModel>>(
      stream: _commentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: WaitingLoading(),
          );
        }
        final comments = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentInput(),
            const SizedBox(height: 20),
            if (comments.isEmpty)
              _buildEmptyState(Iconsax.slash, "No comments yet.")
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _buildCommentItem(comments[index]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommentItem(TaskCommentModel comment) {
    final user = CacheService.getUserByUid(comment.userId);
    var userData = UserDataModel.fromEmptyMap();

    if (user is EmployeeModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: CacheService.designationByUid(user.designation)?.name,
        userType: UserType.employee,
      );
    } else if (user is AdminModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: user.email,
        userType: UserType.admin,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(userData: userData, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user?.name ?? "Collaborator",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      comment.timestamp.listingDateTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.comment,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: "Add a progress update...",
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _isSending
            ? const CircularProgressIndicator()
            : IconButton(
                onPressed: () => _addComment(_taskModel.uid!),
                icon: Icon(
                  Iconsax.send_1,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<TaskHistoryModel>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: WaitingLoading(),
          );
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return _buildEmptyState(Iconsax.activity, "No activity recorded.");
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) =>
              _buildHistoryItem(history[index], index == history.length - 1),
        );
      },
    );
  }

  Widget _buildHistoryItem(TaskHistoryModel item, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.updateDisposition,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "By ${CacheService.getUserByUid(item.userId)?.name ?? 'User'} • ${item.timestamp.listingDateTime}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.update != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.update!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfoRow() {
    return Row(
      children: [
        _timeTile(
          "Started",
          _taskModel.startedTime?.listingDateTime ?? "--",
          Iconsax.play,
        ),
        const SizedBox(width: 16),
        _timeTile(
          "Completed",
          _taskModel.completedTime?.listingDateTime ?? "In progress",
          Iconsax.tick_circle,
        ),
      ],
    );
  }

  Widget _timeTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: TaskViewColors.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: TaskViewColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTrackingTab() {
    if (_taskModel.startedTime == null) {
      return _buildEmptyState(
        Iconsax.timer_start,
        "Task has not been started yet.",
      );
    }

    final totalMinutes = (_taskModel.completedTime ?? DateTime.now())
        .difference(_taskModel.startedTime!)
        .inMinutes;

    final spots = _buildLiveSpots(totalMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeInfoRow(),

        const SizedBox(height: 16),

        /// TOTAL TIME CARD
        _buildTotalTimeCard(),

        const SizedBox(height: 24),

        /// CHART
        SizedBox(height: 300, child: _buildTimeChart(spots, totalMinutes)),
      ],
    );
  }

  Widget _buildTotalTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Iconsax.timer,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Total Time Spent",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: TaskViewColors.textSecondary,
                ),
              ),
              Text(
                "${_totalHours.toStringAsFixed(2)} hrs",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChart(List<FlSpot> spots, int totalMinutes) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: LineChart(
          key: ValueKey(spots.length),
          LineChartData(
            minX: 0,
            maxX: (totalMinutes / 60).ceilToDouble(),
            minY: 0,
            maxY: totalMinutes.toDouble() + 10,

            /// GRID
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 30,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withValues(alpha: 0.12),
                strokeWidth: 1,
              ),
            ),

            /// BORDER
            borderData: FlBorderData(show: false),

            /// AXIS TITLES
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    if (v % 1 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "${v.toInt()}h",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 30,
                  reservedSize: 38,
                  getTitlesWidget: (v, _) => Text(
                    "${v.toInt()}m",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),

            /// LINE DATA
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 3,
                isStrokeCapRound: true,

                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, barData) => spot == spots.last,
                  getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                    radius: _taskModel.completed ? 5 : 6,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.25),
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],

            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(10),
                tooltipPadding: const EdgeInsets.all(10),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      "Time: ${spot.x.toStringAsFixed(1)} hrs\n"
                      "Elapsed: ${spot.y.toInt()} min",
                      const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      strokeWidth: 2,
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 5,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionLabel("ASSIGNED TO"),
        const SizedBox(height: 16),
        ..._taskModel.assignees.map(
          (u) => _buildProfileTile(u, "Lead Execution"),
        ),
        const SizedBox(height: 32),
        _buildSectionLabel("COLLABORATORS"),
        const SizedBox(height: 16),
        if (_taskModel.participants.isEmpty)
          _buildEmptyStateSmall("No participants")
        else
          ..._taskModel.participants.map(
            (u) => _buildProfileTile(u, "Participant"),
          ),
        const SizedBox(height: 32),
        _buildSectionLabel("OBSERVERS"),
        const SizedBox(height: 16),
        if (_taskModel.observers.isEmpty)
          _buildEmptyStateSmall("No observers")
        else
          ..._taskModel.observers.map((u) => _buildProfileTile(u, "Viewer")),
        const SizedBox(height: 40),
        if (isParticipant) _buildActionButtons(),
      ],
    );
  }

  Widget _buildProfileTile(String uid, String role) {
    final user = CacheService.getUserByUid(uid);
    var userData = UserDataModel.fromEmptyMap();

    if (user is EmployeeModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: CacheService.designationByUid(user.designation)?.name,
        userType: UserType.employee,
      );
    } else if (user is AdminModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: user.email,
        userType: UserType.admin,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          UserAvatar(userData: userData, size: 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? "System User",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_taskModel.completed) {
      return const Center(
        child: Text(
          "Task successfully closed.",
          style: TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_taskModel.hasStarted)
          ElevatedButton.icon(
            onPressed: _isActionLoading ? null : _startTask,
            icon: const Icon(Iconsax.play),
            label: const Text("Activate Task"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              elevation: 0,
            ),
          ),
        if (_taskModel.hasStarted)
          ElevatedButton.icon(
            onPressed: _isActionLoading ? null : _completeTask,
            icon: const Icon(Iconsax.tick_circle),
            label: const Text("Mark as Completed"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              elevation: 0,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 40,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          msg,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
  Widget _buildEmptyStateSmall(String msg) => Text(
    msg,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
      fontStyle: FontStyle.italic,
    ),
  );
}
