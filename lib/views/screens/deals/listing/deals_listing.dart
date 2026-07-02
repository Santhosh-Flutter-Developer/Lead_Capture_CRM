import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/services/services.dart';

const String _pageTitle = "Deals";

class DealsListing extends StatelessWidget {
  final bool showAppBar;
  const DealsListing({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DealBloc()..add(StreamDeals()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<DealModel>(
          initialSortColumnIndex: 1,
          filterLogic: (deal, query) {
            final q = query.toLowerCase();
            return deal.dealName.toLowerCase().contains(q) ||
                deal.dealEmail.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 1:
                compare = (a.dealNumber ?? 0).compareTo((b.dealNumber ?? 0));
                break;
              case 2:
                compare = a.dealName.toLowerCase().compareTo(
                  b.dealName.toLowerCase(),
                );
                break;
              case 3:
                compare = a.dealEmail.toLowerCase().compareTo(
                  b.dealEmail.toLowerCase(),
                );
                break;
              case 5:
                compare = a.dealValue.compareTo(b.dealValue);
                break;
              case 6:
                compare = a.createdAt.compareTo(b.createdAt);
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (deal) => deal.uid ?? '',
        ),
        child: DealsListingView(showAppBar: showAppBar),
      ),
    );
  }
}

class DealsListingView extends StatefulWidget {
  final bool showAppBar;
  const DealsListingView({super.key, this.showAppBar = true});
  @override
  State<DealsListingView> createState() => _DealsListingViewState();
}

class _DealsListingViewState extends State<DealsListingView> {
  final ScrollController _hScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedView = 'Grid';
  final List<DealModel> _selectedDeals = [];
  List<DealModel> _filteredDeals = [];

  DateTime? _fromDate;
  DateTime? _toDate;

  String? _selectedStatus;
  String? _selectedCreatedBy;

  double? _value;

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

  List<String> statusItems(Box<Map<dynamic, dynamic>> box) {
    return box.keys.map((key) {
      final data = CacheService.normalizeFromCache(box.get(key) ?? {});
      final model = DealStatusModel.fromMap(key, data);
      return model.name;
    }).toList();
  }

  List<String> employeeItems(CacheService cache) {
    return cache.getAllListenableEmployees().value.map((e) => e.name).toList();
  }

  Future<void> _refreshDeals(BuildContext context) async {
    context.read<DealBloc>().add(StreamDeals());
  }

  void _resetFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _selectedStatus = null;
      _selectedCreatedBy = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<DealModel>>();
    final controllerWatch = context.watch<PaginatedDataController<DealModel>>();
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: widget.showAppBar && (kIsMobile || width < 1000)
          ? AppBar(title: Text(_pageTitle))
          : null,
      body: BlocListener<DealBloc, DealState>(
        listenWhen: (previous, current) => current is DealLoaded,
        listener: (context, state) {
          if (state is DealLoaded) {
            controllerRead.setData(state.deals);
            setState(() {
              _filteredDeals = state.deals;
            });
          }
        },
        child: BlocBuilder<DealBloc, DealState>(
          builder: (context, state) {
            if (state is DealLoading) {
              return const WaitingLoading();
            }

            if (state is DealLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshDeals(context),
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch, width: width),
                    const SizedBox(height: 10),
                    _buildActionRow(context),
                    const SizedBox(height: 20),
                    if (controllerWatch.paginatedItems.isEmpty)
                      const NoData(text: "No matching records found")
                    else if (_selectedView == 'Grid') ...[
                      DealKanbanListing(dealList: _filteredDeals),
                    ] else if (_selectedView == 'Calendar') ...[
                      DealsCalendarListing(dealList: _filteredDeals),
                    ] else ...[
                      _buildListView(context, controllerWatch, controllerRead),
                    ],
                  ],
                ),
              );
            }

            if (state is DealError) {
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

  Container _buildListView(
    BuildContext context,
    PaginatedDataController<DealModel> controllerWatch,
    PaginatedDataController<DealModel> controllerRead,
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
                          label: Text(
                            "Id",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: Text(
                            "Name",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: Text(
                            "Email",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: Text(
                            "Value",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Status",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Created",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                            "Action",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      rows: controllerWatch.paginatedItems
                          .map(
                            (deal) => _buildDataRow(
                              context,
                              deal,
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
            child: PaginationControls<DealModel>(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged, required double width}) {
    if (!Hive.isBoxOpen('dealStatus') || !Hive.isBoxOpen('employees')) {
      return _buildSearchField(onSearchChanged);
    }

    final statusBox = Hive.box<Map<dynamic, dynamic>>('dealStatus');
    final cache = CacheService();

    final filters = [
      /// From Date
      _dateFilter(
        label: "From Date",
        value: _fromDate,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: _fromDate ?? DateTime.now(),
          );

          if (picked != null) {
            setState(() => _fromDate = picked);
            _applyFilters();
          }
        },
      ),

      /// To Date
      _dateFilter(
        label: "To Date",
        value: _toDate,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: _toDate ?? DateTime.now(),
          );

          if (picked != null) {
            setState(() => _toDate = picked);
            _applyFilters();
          }
        },
      ),

      /// Status
      _filterDropdown(
        label: "Status",
        value: _selectedStatus != null
            ? CacheService.dealStatusByUid(_selectedStatus!)?.name
            : null,
        items: statusItems(statusBox),
        onChanged: (v) {
          final selectedModel = statusBox.keys.firstWhere(
            (key) => CacheService.dealStatusByUid(key)?.name == v,
            orElse: () => '',
          );

          setState(() => _selectedStatus = selectedModel);

          _applyFilters();
        },
      ),

      /// Created By
      _filterDropdown(
        label: "Created By",
        value: _selectedCreatedBy != null
            ? cache
                  .getAllListenableEmployees()
                  .value
                  .firstWhere((e) => e.uid == _selectedCreatedBy)
                  .name
            : null,
        items: employeeItems(cache),
        onChanged: (v) {
          final selectedEmployee = cache
              .getAllListenableEmployees()
              .value
              .firstWhereOrNull((e) => e.name == v);

          setState(() => _selectedCreatedBy = selectedEmployee?.uid);

          _applyFilters();
        },
      ),

      /// Deal Value Filter
      _valueFilter(onChanged: _onValueChanged),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Search + Reset
          kIsMobile || width < 1000
              ? Column(
                  children: [
                    _buildSearchField(onSearchChanged),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: _buildResetButton(),
                    ),

                    const SizedBox(height: 16),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _buildSearchField(onSearchChanged),
                    ),

                    const Spacer(),

                    _buildResetButton(),
                  ],
                ),

          if (!kIsMobile) const SizedBox(height: 16),

          /// Filters
          kIsMobile || width < 1000
              ? Wrap(spacing: 10, runSpacing: 10, children: filters)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in filters) ...[
                        filter,
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: _resetFilters,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text("Reset Filters"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSearchField(ValueChanged<String> onSearchChanged) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          onSearchChanged(value);
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'Search deals...',
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),

          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    onSearchChanged('');
                    _applyFilters();
                  },
                )
              : null,

          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,

          contentPadding: const EdgeInsets.symmetric(horizontal: 16),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.3,
            ),
          ),

          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _valueFilter({
    required ValueChanged<String> onChanged,
    double itemWidth = 180,
  }) {
    return SizedBox(
      width: itemWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Deal Value",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // Icon(
                //   Icons.currency_rupee,
                //   size: 18,
                //   color: Colors.grey.shade600,
                // ),
                // const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    onChanged: onChanged,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      // hintText: "1000 - 5000",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onValueChanged(String value) {
    _value = null;

    final cleaned = value.replaceAll(' ', '');
    if (cleaned.isEmpty) {
      _applyFilters();
      return;
    }

    final parsedValue = double.tryParse(cleaned);
    if (parsedValue == null) {
      _applyFilters();
      return;
    }

    _value = parsedValue;

    _applyFilters();
  }

  Widget _dateFilter({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    double itemWidth = 180,
  }) {
    return SizedBox(
      width: itemWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.calendar_1,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value == null
                          ? "Select $label"
                          : "${value.day.toString().padLeft(2, '0')}/"
                                "${value.month.toString().padLeft(2, '0')}/"
                                "${value.year}",
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double itemWidth = 180,
  }) {
    return SizedBox(
      width: itemWidth,
      child: FormDropdownSearch(
        label: label,
        items: items,
        initialItem: value,
        onChanged: (dynamic val) {
          onChanged(val as String?);
        },
        validator: (val) => val == null ? "* Required" : null,
      ),
    );
  }

  void _applyFilters() {
    final controller = context.read<PaginatedDataController<DealModel>>();
    final List<DealModel> allDeals =
        context.read<DealBloc>().state is DealLoaded
        ? (context.read<DealBloc>().state as DealLoaded).deals
        : <DealModel>[];

    List<DealModel> filtered = allDeals;
    final query = _searchController.text.toLowerCase();

    if (query.isNotEmpty) {
      filtered = filtered.where((deal) {
        return deal.dealName.toLowerCase().contains(query) ||
            deal.dealEmail.toLowerCase().contains(query);
      }).toList();
    }

    if (_fromDate != null) {
      filtered = filtered
          .where((e) => !e.createdAt.isBefore(_fromDate!))
          .toList();
    }

    if (_toDate != null) {
      filtered = filtered.where((e) => !e.createdAt.isAfter(_toDate!)).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((e) => e.dealStatus == _selectedStatus)
          .toList();
    }

    if (_selectedCreatedBy != null) {
      filtered = filtered
          .where((e) => e.createdBy.uid == _selectedCreatedBy)
          .toList();
    }

    if (_value != null) {
      filtered = filtered.where((e) => e.dealValue == _value!).toList();
    }

    setState(() {
      _filteredDeals = filtered;
    });

    controller.setData(filtered);
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
                    Sheet.showSheet(context, widget: const DealCreate());
                  } else {
                    GeneralDialog.showRTLSheet(context, const DealCreate());
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
              ),
              const SizedBox(width: 10),
            ] else ...[
              ElevatedButton.icon(
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
            ],
            if (permissions?.canDelete ?? false) ...[
              if (_selectedDeals.isNotEmpty)
                ElevatedButton.icon(
                  label: Text(
                    "Delete",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  icon: const Icon(Iconsax.trash),
                  onPressed: () async {
                    var result = await showDialog(
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
                      final deletedDeals = List<DealModel>.from(_selectedDeals);

                      futureLoading(context);

                      // ✅ STEP 2: delete
                      for (var deal in deletedDeals) {
                        await DealService.deleteDeal(uid: deal.uid ?? '');
                      }

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      // ✅ STEP 3: clear selection
                      _selectedDeals.clear();
                      setState(() {});

                      // ✅ STEP 4: UNDO
                      FlushBar.show(
                        context,
                        '$_pageTitle deleted successfully',
                        actionLabel: 'UNDO',
                        onActionPressed: () async {
                          for (var deal in deletedDeals) {
                            await DealService.restoreDeal(
                              deal,
                            ); // 👈 implement this
                          }

                          // 🔥 refresh after undo
                          context.read<DealBloc>().add(StreamDeals());
                        },
                        // onDismissed: () {
                        //   // 🔥 refresh if no undo
                        //   context.read<DealBloc>().add(StreamDeals());
                        // },
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
              ElevatedButton.icon(
                label: Text(
                  "Delete",
                  style: Theme.of(context).textTheme.bodySmall,
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
        );

        final viewToggle = Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kIsDesktop)
                IconButton(
                  tooltip: "Refresh",
                  icon: const Icon(Iconsax.refresh),
                  iconSize: 18,
                  onPressed: () => _refreshDeals(context),
                ),

              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  _selectedView = 'Grid';
                  setState(() {});
                },
                icon: const Icon(Iconsax.grid_3, size: 18),
                color: _selectedView == 'Grid'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Container(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
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

  DataRow _buildDataRow(
    BuildContext context,
    DealModel deal,
    PaginatedDataController<DealModel> controllerWatch,
    PaginatedDataController<DealModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    bool isSelected = controllerWatch.selectedIds.contains(deal.uid);

    /// Open Deal View
    void openDeal(BuildContext context, DealModel deal) {
      final view = BlocProvider(
        create: (_) => DealBloc()..add(StreamDealComments(deal.uid!)),
        child: DealsView(deal: deal),
      );

      if (kIsMobile || width < 1000) {
        Sheet.showSheet(context, widget: view);
      } else {
        GeneralDialog.showRTLSheet(context, view);
      }
    }

    /// Reusable tappable DataCell
    DataCell dataCell(BuildContext context, Widget child) {
      return DataCell(
        InkWell(
          onTap: () => openDeal(context, deal),
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
        controllerRead.onSelected(deal.uid ?? '', selected);
        if (selected ?? false) {
          _selectedDeals.add(deal);
        } else {
          _selectedDeals.remove(deal);
        }
        setState(() {});
      },
      cells: [
        /// Deal Number
        dataCell(
          context,
          Text(
            deal.dealNumber?.toString() ?? '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),

        /// Deal Name
        dataCell(
          context,
          Text(
            deal.dealName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),

        /// Email
        dataCell(
          context,
          Text(deal.dealEmail, style: Theme.of(context).textTheme.bodySmall),
        ),

        /// Deal Value
        dataCell(
          context,
          Text(
            deal.dealValue.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Status
        dataCell(
          context,
          Text(
            CacheService.dealStatusByUid(deal.dealStatus ?? '')?.name ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Created At
        dataCell(
          context,
          Text(
            deal.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Created By
        dataCell(context, CreatedByWidget(userData: deal.createdBy)),

        /// Actions (❌ no row tap here)
        DataCell(
          Row(
            children: [
              if ((permissions?.canEdit ?? false) &&
                  (_isAdmin || deal.createdBy.uid == _currentUid)) ...[
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  color: AppColors.info,
                  splashRadius: 20,
                  onPressed: () {
                    if (kIsMobile || width < 1000 ) {
                      Sheet.showSheet(
                        context,
                        widget: DealEdit(uid: deal.uid ?? ''),
                      );
                    } else {
                      GeneralDialog.showRTLSheet(
                        context,
                        DealEdit(uid: deal.uid ?? ''),
                      );
                    }
                  },
                ),
              ] else ...[
                IconButton(
                  icon: Icon(Iconsax.edit, color: AppColors.grey400),
                  onPressed: null,
                ),
              ],

              if ((permissions?.canDelete ?? false) &&
                  (_isAdmin || deal.createdBy.uid == _currentUid)) ...[
                IconButton(
                  icon: const Icon(Iconsax.trash),
                  color: AppColors.danger,
                  splashRadius: 20,
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => ConfirmDialog(
                        title: 'Delete $_pageTitle',
                        content:
                            'Are you sure you want to delete this $_pageTitle?',
                      ),
                    );

                    if (result == true) {
                      try {
                        await DealService.deleteDeal(uid: deal.uid ?? '');

                        if (context.mounted) {
                          FlushBar.show(
                            context,
                            '$_pageTitle deleted successfully',
                            actionLabel: 'UNDO',
                            onActionPressed: () async {
                              await DealService.restoreDeal(deal);

                              context.read<DealBloc>().add(StreamDeals());
                            },
                          );
                        }
                      } catch (e, st) {
                        await ErrorService.recordError(e, st);
                        if (context.mounted) {
                          FlushBar.show(
                            context,
                            'Failed to delete $_pageTitle: $e',
                            isSuccess: false,
                          );
                        }
                      }
                    }
                  },
                ),
              ] else ...[
                IconButton(
                  icon: Icon(Iconsax.trash, color: AppColors.grey400),
                  onPressed: null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
