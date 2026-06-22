import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class TicketView extends StatefulWidget {
  final String uid;
  const TicketView({super.key, required this.uid});

  @override
  State<TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends State<TicketView> with TickerProviderStateMixin {
  late Future<CustomerTicketModel> _future;
  late CustomerTicketModel _ticketModel;
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();

  String? currentUid;
  String _cid = '';
  Stream<List<TicketCommentModel>>? _commentsStream;
  Stream<List<TicketHistoryModel>>? _historyStream;
  bool _isSending = false;
  bool isParticipant = false;

  @override
  void initState() {
    super.initState();
    _future = TicketService.getTicket(uid: widget.uid);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    Spdb.getUid().then((uid) {
      if (mounted) setState(() => currentUid = uid);
    });
    Spdb.getCid().then((cid) {
      if (mounted) {
        setState(() {
          _cid = cid ?? '';
          _commentsStream = TicketService.streamComments(
            cid: _cid,
            ticketId: widget.uid,
          );
          _historyStream = TicketService.streamTicketHistory(
            cid: _cid,
            ticketId: widget.uid,
          );
        });
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment(String ticketId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await TicketService.addComment(ticketId: ticketId, comment: text);
      _commentController.clear();
    } catch (e) {
      FlushBar.show(context, 'Failed to add comment', isSuccess: false);
    }
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const WaitingLoading();

    return FutureBuilder<CustomerTicketModel>(
      future: _future,
      builder: (context, ticketSnap) {
        if (ticketSnap.connectionState == ConnectionState.waiting) {
          return const WaitingLoading();
        }
        if (!ticketSnap.hasData) return ErrorDisplay(error: "Ticket not found");

        _ticketModel = ticketSnap.data!;
        isParticipant =
            currentUid != null &&
            (_ticketModel.assignTo.contains(currentUid!) ||
                _ticketModel.createdBy.contains(currentUid!));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: FormWidgets.buildHeader(
            context: context,
            title: "Ticket Details",
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
        _buildTicketHeader(),
        const SizedBox(height: 24),
        _buildInfoGrid(),
        const SizedBox(height: 32),
        _buildSectionLabel("TICKET DESCRIPTION"),
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
            _ticketModel.ticketDescription.isNotEmpty
                ? _ticketModel.ticketDescription
                : "No description provided for this ticket.",
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (_ticketModel.attachments.isNotEmpty) ...[
          _buildSectionLabel("ATTACHMENTS"),
          const SizedBox(height: 12),
          _buildAttachmentsGrid(),
          const SizedBox(height: 32),
        ],
        _buildModernTabs(),
      ],
    );
  }

  Widget _buildTicketHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getPriorityColor(
                  _ticketModel.priorityLevel,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getPriorityColor(
                    _ticketModel.priorityLevel,
                  ).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.flash,
                    size: 14,
                    color: _getPriorityColor(_ticketModel.priorityLevel),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ticketModel.priorityLevel.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _getPriorityColor(_ticketModel.priorityLevel),
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
          _ticketModel.ticketTitle,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(_ticketModel.category.label),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
            Chip(
              label: Text(_ticketModel.modeOfContact.label),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(_ticketModel.status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _getStatusColor(_ticketModel.status).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        _ticketModel.status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: _getStatusColor(_ticketModel.status),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    // Get project and task names
    final projectName = _ticketModel.project != null
        ? CacheService.getProjectByUid(_ticketModel.project!)?.projectName
        : null;
    final taskName = _ticketModel.task != null
        ? CacheService.getTaskByUid(_ticketModel.task!)?.taskName
        : null;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _infoBox(Iconsax.user, "Client Name", _ticketModel.clientName),
        if (_ticketModel.clientCompanyName != null)
          _infoBox(
            Iconsax.building,
            "Company",
            _ticketModel.clientCompanyName!,
          ),
        if (projectName != null)
          _infoBox(Iconsax.folder, "Project", projectName),
        if (taskName != null) _infoBox(Iconsax.task, "Task", taskName),
        if (_ticketModel.deadline != null)
          _infoBox(
            Iconsax.calendar_1,
            "Deadline",
            _ticketModel.deadline!.listingDateTime,
          ),
        if (_ticketModel.reminder != null)
          _infoBox(
            Iconsax.notification,
            "Reminder",
            _ticketModel.reminder!.listingDateTime,
          ),
      ],
    );
  }

  Widget _infoBox(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      constraints: const BoxConstraints(minWidth: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _ticketModel.attachments.map((file) {
        return InkWell(
          onTap: () async {
            await Download.downloadFromUrl(context, file.url, file.name);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.document_text,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
              ],
            ),
          ),
        );
      }).toList(),
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        IndexedStack(
          index: _tabController.index,
          children: [_buildCommentsTab(), _buildHistoryTab()],
        ),
      ],
    );
  }

  Widget _buildCommentsTab() {
    return StreamBuilder<List<TicketCommentModel>>(
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
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _buildCommentItem(comments[index]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommentItem(TicketCommentModel comment) {
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
                onPressed: () => _addComment(_ticketModel.uid!),
                icon: Icon(
                  Iconsax.send_1,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<TicketHistoryModel>>(
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

  Widget _buildHistoryItem(TicketHistoryModel item, bool isLast) {
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

  Widget _buildSidePanel() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionLabel("ASSIGNED TO"),
        const SizedBox(height: 16),
        ..._ticketModel.assignTo.map(
          (u) => _buildProfileTile(u, "Assigned To"),
        ),
        const SizedBox(height: 32),
        _buildSectionLabel("PARTICIPANTS"),
        const SizedBox(height: 16),
        if (_ticketModel.participants.isEmpty)
          _buildEmptyStateSmall("No participants")
        else
          ..._ticketModel.participants.map(
            (u) => _buildProfileTile(u, "Participant"),
          ),
        const SizedBox(height: 32),
        _buildSectionLabel("OBSERVERS"),
        const SizedBox(height: 16),
        if (_ticketModel.observers.isEmpty)
          _buildEmptyStateSmall("No observers")
        else
          ..._ticketModel.observers.map(
            (u) => _buildProfileTile(u, "Observer"),
          ),
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

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return AppColors.info;
      case TicketPriority.medium:
        return AppColors.warning;
      case TicketPriority.high:
        return AppColors.danger;
      case TicketPriority.urgent:
        return Colors.red;
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return AppColors.info;
      case TicketStatus.assigned:
        return AppColors.secondary;
      case TicketStatus.inProgress:
        return AppColors.warning;
      case TicketStatus.onHold:
        return Colors.orange;
      case TicketStatus.pendingCustomerResponse:
        return Colors.purple;
      case TicketStatus.resolved:
        return AppColors.success;
      case TicketStatus.closed:
        return AppColors.grey;
    }
  }
}
