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
              ticket.clientName.toLowerCase().contains(q);
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

  Future<void> _refreshTickets(BuildContext context) async {
    context.read<TicketBloc>().add(StreamTickets());
  }

  final ScrollController _hScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final controllerRead = context
        .read<PaginatedDataController<CustomerTicketModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<CustomerTicketModel>>();

    return Scaffold(
      appBar: kIsMobile
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
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
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshTickets(context),
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
                      _buildMainBody(context, controllerWatch, controllerRead),
                  ],
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

  Widget _buildMainBody(
    BuildContext context,
    PaginatedDataController<CustomerTicketModel> controllerWatch,
    PaginatedDataController<CustomerTicketModel> controllerRead,
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
                          label: _sortableHeader("Ticket No", controllerRead),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: _sortableHeader("Title", controllerRead),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: _sortableHeader("Status", controllerRead),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: Text(
                            "Client Name",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Priority",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Category",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Project",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Task",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Created By",
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
                            (ticket) => _buildDataRow(
                              context,
                              ticket,
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
            child: PaginationControls<CustomerTicketModel>(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final addDeleteButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permissions?.canCreate ?? false) ...[
              ElevatedButton.icon(
                onPressed: () {
                  if (kIsMobile) {
                    Sheet.showSheet(context, widget: const TicketCreate());
                  } else {
                    GeneralDialog.showRTLSheet(context, const TicketCreate());
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
              if (_selectedTickets.isNotEmpty)
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
                      final deletedTickets = List<CustomerTicketModel>.from(
                        _selectedTickets,
                      );

                      futureLoading(context);

                      for (var ticket in deletedTickets) {
                        await TicketService.deleteTicket(uid: ticket.uid ?? '');
                      }

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      _selectedTickets.clear();
                      setState(() {});

                      FlushBar.show(
                        context,
                        '$_pageTitle deleted successfully',
                        actionLabel: 'UNDO',
                        onActionPressed: () async {
                          for (var ticket in deletedTickets) {
                            await TicketService.restoreTicket(ticket);
                          }

                          context.read<TicketBloc>().add(StreamTickets());
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
              if (_selectedTickets.isNotEmpty) ...[
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

        if (kIsMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: addDeleteButtons,
              ),
              const SizedBox(height: 8),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [addDeleteButtons, _buildViewToggle(context)],
          );
        }
      },
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Iconsax.refresh),
            iconSize: 18,
            onPressed: () => _refreshTickets(context),
          ),
        ],
      ),
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
    CustomerTicketModel ticket,
    PaginatedDataController<CustomerTicketModel> controllerWatch,
    PaginatedDataController<CustomerTicketModel> controllerRead,
  ) {
    bool isSelected = controllerWatch.selectedIds.contains(ticket.uid);
    void openTicket(BuildContext context, String uid) {
      if (kIsMobile) {
        Sheet.showSheet(context, widget: TicketView(uid: uid));
      } else {
        GeneralDialog.showRTLSheet(context, TicketView(uid: uid));
      }
    }

    DataCell dataCell(BuildContext context, Widget child, String uid) {
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
          context,
          SelectableText(
            ticket.ticketNumber?.toString() ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
          Text(
            ticket.ticketTitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: _getStatusColor(ticket.status).withValues(alpha: 0.1),
            ),
            child: Text(
              ticket.status.label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: _getStatusColor(ticket.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
          Text(ticket.clientName, style: Theme.of(context).textTheme.bodySmall),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: _getPriorityColor(
                ticket.priorityLevel,
              ).withValues(alpha: 0.1),
            ),
            child: Text(
              ticket.priorityLevel.label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: _getPriorityColor(ticket.priorityLevel),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
          Text(
            ticket.category.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
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
          context,
          Text(
            ticket.task != null
                ? CacheService.getTaskByUid(ticket.task!)?.taskName ?? '-'
                : '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ticket.uid ?? '',
        ),
        dataCell(
          context,
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
            children: [
              if ((permissions?.canEdit ?? false) &&
                  (_isAdmin ||
                      ticket.ticketCreatedBy.uid == _currentUid ||
                      (ticket.ticketCreatedBy.uid.isEmpty &&
                          ticket.createdBy.contains(_currentUid ?? '')))) ...[
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  onPressed: () {
                    if (kIsMobile) {
                      Sheet.showSheet(
                        context,
                        widget: TicketEdit(uid: ticket.uid ?? ''),
                      );
                    } else {
                      GeneralDialog.showRTLSheet(
                        context,
                        TicketEdit(uid: ticket.uid ?? ''),
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
              if ((permissions?.canDelete ?? false) &&
                  (_isAdmin ||
                      ticket.ticketCreatedBy.uid == _currentUid ||
                      (ticket.ticketCreatedBy.uid.isEmpty &&
                          ticket.createdBy.contains(_currentUid ?? '')))) ...[
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
                        content: 'Are you sure you want to delete this ticket?',
                      ),
                    );

                    if (result != true) return;

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

                          context.read<TicketBloc>().add(StreamTickets());
                        },
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
