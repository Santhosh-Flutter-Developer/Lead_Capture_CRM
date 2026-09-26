import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/services/services.dart';
import 'bloc/tickets_bloc.dart';

const String _pageTitle = "Tickets";
const double _wideBreakpoint = 1000;

class TicketsListing extends StatelessWidget {
  const TicketsListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TicketBloc()..add(StreamTickets()),
      child: const TicketListView(),
    );
  }
}

class TicketListView extends StatelessWidget {
  const TicketListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaginatedDataController<CustomerTicketModel>(
        initialSortColumnIndex: 1,
        filterLogic: (ticket, query) {
          final q = query.toLowerCase();
          return ticket.ticketTitle.toLowerCase().contains(q) ||
              ticket.clientName.toLowerCase().contains(q) ||
              ticket.ticketNumber?.toString().contains(q) == true;
        },
        sortLogic: (a, b, col, asc) {
          int compare;
          switch (col) {
            case 0:
              compare = a.ticketNumber?.compareTo(b.ticketNumber ?? 0) ?? 0;
              break;
            case 1:
              compare = a.ticketTitle.toLowerCase().compareTo(
                b.ticketTitle.toLowerCase(),
              );
              break;
            case 2:
              compare = a.status.index.compareTo(b.status.index);
              break;
            default:
              compare = (a.uid ?? '').compareTo(b.uid ?? '');
          }
          return asc ? compare : -compare;
        },
        getItemId: (ticket) => ticket.uid ?? '',
      ),
      child: const TicketListingView(),
    );
  }
}

class TicketListingView extends StatefulWidget {
  const TicketListingView({super.key});

  @override
  State<TicketListingView> createState() => _TicketListingViewState();
}

class _TicketListingViewState extends State<TicketListingView> {
  final List<CustomerTicketModel> _selectedTickets = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  String? _currentUid;
  bool _isAdmin = false;
  final ScrollController _hScrollController = ScrollController();

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

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    _currentUid = await Spdb.getUid();
    _isAdmin = await Spdb.isAdminLoggedIn();
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshTickets(BuildContext context) async {
    context.read<TicketBloc>().add(StreamTickets());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = context
        .read<PaginatedDataController<CustomerTicketModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<CustomerTicketModel>>();
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
      body: BlocListener<TicketBloc, TicketState>(
        listenWhen: (previous, current) => current is TicketLoaded,
        listener: (context, state) {
          if (state is TicketLoaded) {
            controllerRead.setData(state.tickets);
          }
        },
        child: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            if (state is TicketLoading) return const WaitingLoading();

            if (state is TicketLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshTickets(context),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      if (isWide) ...[
                        _buildHeaderBanner(
                          context,
                          state.tickets.length,
                        ),
                        const SizedBox(height: 20),
                      ],
                      _buildToolbar(context, controllerRead),
                      const SizedBox(height: 18),
                      if (controllerWatch.paginatedItems.isEmpty)
                        NoData(
                          text: state.tickets.isEmpty
                              ? "No tickets available"
                              : "No matching records found",
                        )
                      else
                        _buildTableCard(context, controllerWatch, controllerRead),
                    ],
                  ),
                ),
              );
            }

            if (state is TicketError) {
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
  Widget _buildHeaderBanner(BuildContext context, int totalTickets) {
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
            child: const Icon(Iconsax.ticket, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Support Tickets",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Track and resolve every customer request in one place",
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
                  '$totalTickets',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalTickets == 1 ? "Ticket" : "Tickets",
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
  // Toolbar: search + add + delete + refresh
  // ---------------------------------------------------------------------
  Widget _buildToolbar(
    BuildContext context,
    PaginatedDataController<CustomerTicketModel> controllerRead,
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
                  Sheet.showSheet(context, widget: const TicketCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const TicketCreate());
                }
              },
            )
          : _disabledButton(
              context,
              icon: Icons.add_rounded,
              label: "Add $_pageTitle",
            ),
      if (_selectedTickets.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedTickets.length})",
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkDelete,
        ),
      if (isWide)
        _iconCircleButton(
          context,
          icon: Iconsax.refresh,
          tooltip: "Refresh",
          background: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          iconColor: Theme.of(context).colorScheme.primary,
          onPressed: () => _refreshTickets(context),
        ),
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

  Widget _searchBox(PaginatedDataController<CustomerTicketModel> controllerRead) {
    return _TicketSearchField(onChanged: controllerRead.setSearch);
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<CustomerTicketModel> controllerWatch,
    PaginatedDataController<CustomerTicketModel> controllerRead,
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
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: true,
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        sortColumnIndex: controllerWatch.sortColumnIndex,
                        sortAscending: controllerWatch.sortAscending,
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.06,
                          ),
                        ),
                        headingTextStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        columns: [
                          DataColumn(
                            label: const Text("Ticket No"),
                            onSort: controllerRead.setSort,
                          ),
                          DataColumn(
                            label: const Text("Title"),
                            onSort: controllerRead.setSort,
                          ),
                          DataColumn(
                            label: const Text("Status"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Client Name")),
                          const DataColumn(label: Text("Priority")),
                          const DataColumn(label: Text("Category")),
                          const DataColumn(label: Text("Project")),
                          const DataColumn(label: Text("Task")),
                          const DataColumn(label: Text("Created By")),
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
            child: PaginationControls<CustomerTicketModel>(),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, TicketStatus status) {
    final color = _getStatusColor(status);
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
            status.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityPill(BuildContext context, TicketPriority priority) {
    final color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    CustomerTicketModel ticket,
    PaginatedDataController<CustomerTicketModel> controllerWatch,
    PaginatedDataController<CustomerTicketModel> controllerRead,
    int index,
  ) {
    final width = MediaQuery.of(context).size.width;
    final isSelected = controllerWatch.selectedIds.contains(ticket.uid);

    void openTicket(BuildContext context, String uid) {
      if (kIsMobile || width < _wideBreakpoint) {
        Sheet.showSheet(context, widget: TicketView(uid: uid));
      } else {
        GeneralDialog.showRTLSheet(context, TicketView(uid: uid));
      }
    }

    DataCell dataCell(Widget child, String uid) {
      return DataCell(
        InkWell(
          onTap: () => openTicket(context, uid),
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
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              );
      }),
      onSelectChanged: (selected) {
        controllerRead.onSelected(ticket.uid ?? '', selected);
        if (selected ?? false) {
          _selectedTickets.add(ticket);
        } else {
          _selectedTickets.remove(ticket);
        }
        setState(() {});
      },
      cells: [
        dataCell(
          Text(
            ticket.ticketNumber?.toString() ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          Text(
            ticket.ticketTitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          ticket.uid ?? '',
        ),
        dataCell(_statusPill(context, ticket.status), ticket.uid ?? ''),
        dataCell(
          Text(ticket.clientName, style: Theme.of(context).textTheme.bodySmall),
          ticket.uid ?? '',
        ),
        dataCell(
          _priorityPill(context, ticket.priorityLevel),
          ticket.uid ?? '',
        ),
        dataCell(
          Text(
            ticket.category.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          Text(
            ticket.project != null
                ? CacheService.getProjectByUid(ticket.project!)?.projectName ??
                      '-'
                : '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          Text(
            ticket.task != null
                ? CacheService.getTaskByUid(ticket.task!)?.taskName ?? '-'
                : '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          ticket.ticketCreatedBy.uid.isNotEmpty
              ? CreatedByWidget(userData: ticket.ticketCreatedBy)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ticket.createdBy
                      .map((uid) => CacheService.getUserByUid(uid))
                      .where((user) => user != null)
                      .map((user) => CreatedByWidget(userData: user!))
                      .toList(),
                ),
          ticket.uid ?? '',
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
                    final form = TicketEdit(uid: ticket.uid ?? '');
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
                  onPressed: () => _onDeleteTap(ticket),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onDeleteTap(CustomerTicketModel ticket) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete $_pageTitle',
        content: 'Are you sure you want to delete this ticket?',
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedTicket = ticket;

      await TicketService.deleteTicket(uid: ticket.uid ?? '');

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await TicketService.restoreTicket(deletedTicket);
          if (!mounted) return;
          context.read<TicketBloc>().add(StreamTickets());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedTickets.isEmpty) return;

    final result = await showDialog<bool>(
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
      final deletedTickets = List<CustomerTicketModel>.from(_selectedTickets);

      futureLoading(context);

      for (var ticket in deletedTickets) {
        await TicketService.deleteTicket(uid: ticket.uid ?? '');
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _selectedTickets.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var ticket in deletedTickets) {
            await TicketService.restoreTicket(ticket);
          }
          if (!mounted) return;
          context.read<TicketBloc>().add(StreamTickets());
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

// ---------------------------------------------------------------------
// A more polished, colorful search field for the Tickets toolbar.
// ---------------------------------------------------------------------
class _TicketSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _TicketSearchField({required this.onChanged});

  @override
  State<_TicketSearchField> createState() => _TicketSearchFieldState();
}

class _TicketSearchFieldState extends State<_TicketSearchField> {
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
          hintText: 'Search tickets',
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