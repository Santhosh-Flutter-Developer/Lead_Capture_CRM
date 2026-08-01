import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/views/screens/creations/employee/form/employee_upload.dart';
import 'package:provider/provider.dart';
import '../form/employee_create.dart';
import '../form/employee_details.dart';
import '../form/employee_edit.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/views/views.dart';
import 'package:flutter/foundation.dart';
import '/utils/utils.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/theme/theme.dart';
import 'bloc/employee_bloc.dart';

const String _pageTitle = "Employees";

class EmployeeListing extends StatelessWidget {
  const EmployeeListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UsersBloc()..add(StreamUsers()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<UserRowModel>(
          initialSortColumnIndex: 0,
          filterLogic: (employee, query) {
            final q = query.toLowerCase();
            return employee.name.toLowerCase().contains(q) ||
                employee.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 0:
                compare = a.uid.toLowerCase().compareTo(b.uid.toLowerCase());
                break;
              case 1:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              case 2:
                compare = a.email.toLowerCase().compareTo(
                  b.email.toLowerCase(),
                );
                break;
              case 3:
                compare = a.isActive.toString().compareTo(
                  b.isActive.toString(),
                );
                break;
              default:
                compare = (a.uid).compareTo(b.uid);
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (employee) => employee.uid,
        ),
        child: const EmployeeListingView(),
      ),
    );
  }
}

class EmployeeListingView extends StatefulWidget {
  const EmployeeListingView({super.key});

  @override
  State<EmployeeListingView> createState() => _EmployeeListingViewState();
}

class _EmployeeListingViewState extends State<EmployeeListingView> {
  final List<UserRowModel> _selectedEmployees = [];
  final List<UserRowModel> _employeesList = [];
  PermissionModel? permissions;
  PermissionModel? tasksPermissions;
  bool _isAdmin = false;
  final ScrollController _hScrollController = ScrollController();

  final TextEditingController _chatMessage = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    tasksPermissions = await PermissionService.getPermissions('Tasks');
    _isAdmin = await Spdb.isAdminLoggedIn();
    setState(() {});
  }

  Future<void> _refreshUsers() async {
    context.read<UsersBloc>().add(StreamUsers());
  }

  TextStyle _primaryCellStyle(BuildContext context, {FontWeight? fontWeight}) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      color: context.colors.textPrimary,
      fontWeight: fontWeight,
    );
  }

  TextStyle _secondaryCellStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: context.colors.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final controllerRead = context
        .read<PaginatedDataController<UserRowModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<UserRowModel>>();
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<UsersBloc, UsersState>(
        listenWhen: (previous, current) => current is UsersLoaded,
        listener: (context, state) {
          if (state is UsersLoaded) {
            controllerRead.setData(state.users);
            _employeesList.clear();
            _employeesList.addAll(state.users);
          }
        },

        child: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state is UsersLoading) {
              return const WaitingLoading();
            }

            if (state is UsersLoaded) {
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshUsers(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                    const SizedBox(height: 10),

                    _buildActionRow(),
                    const SizedBox(height: 20),
                    controllerWatch.paginatedItems.isEmpty
                        ? NoData(
                            text: state.users.isEmpty
                                ? "No employees available"
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
                                            columnSpacing: 12,
                                            horizontalMargin: 8,
                                            // dataRowMinHeight: 40,
                                            // dataRowMaxHeight: 40,
                                            // headingRowHeight: 40,
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
                                                  color: context
                                                      .colors
                                                      .textPrimary,
                                                ),
                                            dataTextStyle: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: context
                                                      .colors
                                                      .textPrimary,
                                                ),

                                            columns: [
                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "Employee ID",
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.arrow_upward,
                                                        size: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                onSort: controllerRead.setSort,
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
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
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                onSort: controllerRead.setSort,
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "Department",
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.arrow_upward,
                                                        size: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                onSort: controllerRead.setSort,
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Text(
                                                    "Role",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "Email",
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.arrow_upward,
                                                        size: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                onSort: controllerRead.setSort,
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Text(
                                                    "Mobile app",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Text(
                                                    "Desktop app",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "Status",
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.arrow_upward,
                                                        size: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                onSort: controllerRead.setSort,
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Text(
                                                    "Created By",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ),

                                              DataColumn(
                                                label: IntrinsicWidth(
                                                  child: Text(
                                                    "Action",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ),
                                            ],

                                            rows: controllerWatch.paginatedItems
                                                .asMap()
                                                .entries
                                                .map(
                                                  (entry) => _buildDataRow(
                                                    context,
                                                    entry.value, // user
                                                    entry.key, // 👈 index
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
                                  child: PaginationControls<UserRowModel>(),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              );
            }

            if (state is UsersError) {
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

  Future<void> handleDelete(BuildContext context, UserRowModel user) async {
    // ❌ prevent admin delete
    if (!user.isEmployee) {
      FlushBar.show(context, 'Admin cannot be deleted', isSuccess: false);
      return;
    }

    // ✅ STEP 1: CHECK ASSIGNED
    final isAssigned = await EmployeeService.isEmployeeAssigned(
      user.employeeId ?? '',
    );

    if (isAssigned) {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text(
            'This employee is associated with chats/projects/tasks.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // ✅ STEP 2: CONFIRM
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Delete Employee',
        content: 'Are you sure you want to delete ${user.name}?',
      ),
    );

    if (confirm != true) return;

    try {
      // ✅ STEP 3: BACKUP
      final deletedEmployee = user.toEmployeeModel();

      // ✅ STEP 4: DELETE
      await EmployeeService.deleteEmployee(uid: user.uid);

      if (!context.mounted) return;

      // ✅ STEP 5: UNDO
      FlushBar.show(
        context,
        'Employee deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await EmployeeService.restoreEmployee(deletedEmployee);

          if (!context.mounted) return;

          // 🔥 refresh list
          context.read<UsersBloc>().add(StreamUsers());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);

      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
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
              hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    final width = MediaQuery.of(context).size.width;
    return LayoutBuilder(
      builder: (context, constraints) {
        // final bool isMobile = constraints.maxWidth < 600;

        final buttons = <Widget>[];

        // Add Employee Button
        if (permissions?.canCreate ?? false) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: () {
                if (kIsMobile || width < 1000) {
                  Sheet.showSheet(context, widget: const EmployeeCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const EmployeeCreate());
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
          );
        } else {
          buttons.add(
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
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        // Upload Button (Gated by canImport)
        if (permissions?.canImport ?? false) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: () {
                if (kIsMobile || width < 1000) {
                  Sheet.showSheet(context, widget: const EmployeeUploadPage());
                } else {
                  GeneralDialog.showRTLSheet(
                    context,
                    const EmployeeUploadPage(),
                  );
                }
              },
              icon: const Icon(Iconsax.cloud_plus, size: 18),
              label: Text(
                "Upload",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          );
        } else {
          buttons.add(
            ElevatedButton.icon(
              onPressed: null,
              icon: Icon(
                Iconsax.cloud_plus,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              label: Text(
                "Upload",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        buttons.add(const SizedBox(width: 10));

        buttons.add(
          OutlinedButton.icon(
            onPressed: () async {
              await Download.downloadFromAsset(
                context,
                "assets/templates/employee_upload_template.xlsx",
                "Employee_Template.xlsx",
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text("Template"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        );

        buttons.add(
          OutlinedButton.icon(
            onPressed: () async {
              await Download.downloadFromAsset(
                context,
                "assets/templates/employee_upload_template_with_data.xlsx",
                "Employee_Sample_Data.xlsx",
              );
            },
            icon: const Icon(Icons.contact_page_outlined, size: 18),
            label: const Text("Sample Data"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
              side: BorderSide(color: Theme.of(context).colorScheme.secondary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        );

        buttons.add(
          ElevatedButton.icon(
            label: Text(
              "Export",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            icon: Icon(Iconsax.export_3),
            onPressed:
                (permissions?.canExport ?? false) == false ||
                    _employeesList.isEmpty
                ? null
                : () async {
                    try {
                      List<List<String>> exportData = [];
                      exportData.add([
                        'Employee Id',
                        'Name',
                        'Email',
                        'Designation',
                        'Department',
                        'Sub Department',
                        'Mobile Number',
                        'Profile Image',
                        'Gender',
                        'Date Of Joining',
                        'Date Of Birth',
                        'Role',
                        'Address',
                        'About',
                        'Login Allowed',
                        'Receive Email Notifications',
                        'Employee Type',
                        'Reporting To',
                        'Marital Status',
                        'Is Active',
                        'Created At',
                      ]);
                      for (var i in _employeesList) {
                        List<String> row = [];
                        row.addAll([
                          i.employeeId ?? "",
                          i.name,
                          i.email,
                          CacheService.designationByUid(
                                i.designation ?? "",
                              )?.name ??
                              '',
                          i.department != null && i.department!.isNotEmpty
                              ? i.department!
                                    .map(
                                      (uid) =>
                                          CacheService.departmentByUid(
                                            uid,
                                          )?.name ??
                                          '',
                                    )
                                    .join(', ')
                              : '',
                          i.subDepartment != null
                              ? CacheService.subDepartmentByUid(
                                      i.subDepartment!,
                                    )?.name ??
                                    ''
                              : '',
                          i.mobileNumber,
                          i.profileImageUrl ?? '',
                          i.gender ?? "",
                          i.dateOfJoining?.formatDate ?? '',
                          i.dateOfBirth?.formatDate ?? '',
                          CacheService.roleByUid(i.role ?? "")?.name ?? '',
                          i.address ?? "",
                          i.about ?? "",
                          (i.loginAllowed ?? false) ? "Yes" : "No",
                          (i.receiveEmailNotifications ?? false) ? "Yes" : "No",
                          i.employeeType ?? '',

                          i.reportingTo != null && i.reportingTo!.isNotEmpty
                              ? i.reportingTo!
                                    .map(
                                      (uid) =>
                                          CacheService.getUserByUid(
                                            uid,
                                          )?.name ??
                                          '',
                                    )
                                    .join(', ')
                              : '',
                          i.maritalStatus ?? "",
                          i.isActive ? "Yes" : "No",
                          i.createdAt.formatDateTime,
                        ]);
                        exportData.add(row);
                      }
                      var fileBytes = await XlsxWriter().create(exportData);
                      var filePath = await saveFileToDownloads(
                        fileBytes,
                        fileName: '$_pageTitle List.xlsx',
                      );
                      if (!kIsWeb) openfile(filePath, context);
                    } catch (e) {
                      FlushBar.show(context, e.toString(), isSuccess: false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );

        buttons.add(
          ElevatedButton.icon(
            label: Text(
              "Worflow",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            icon: Icon(Iconsax.data),
            onPressed: () async {
              try {
                futureLoading(context);
                var resultMap = [];
                var employees = await EmployeeService.getAllEmployees();
                for (var i in employees) {
                  var result = await EmployeeService.getUserWorkflow(
                    userId: i.uid,
                  );
                  var subResultMap = {};
                  for (var i = 0; i < result.length; i++) {
                    subResultMap[i.toString()] = result[i];
                  }

                  resultMap.add({i.uid: subResultMap});
                }
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                if (kIsDesktop || (kIsWeb && width >= 1000)) {
                  GeneralDialog.showRTLSheet(
                    context,
                    OrgChart(rawData: resultMap),
                  );
                } else if (kIsMobile || (kIsWeb && width < 1000)) {
                  Sheet.showSheet(
                    context,
                    widget: OrgChart(rawData: resultMap),
                  );
                }
              } catch (e) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                FlushBar.show(context, e.toString(), isSuccess: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        );

        if (_selectedEmployees.isNotEmpty) {
          buttons.add(
            (permissions?.canDelete ?? false && _isAdmin)
                ? ElevatedButton.icon(
                    label: Text(
                      "Delete",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                    ),
                    icon: const Icon(Iconsax.trash),
                    onPressed: () async {
                      if (_selectedEmployees.isEmpty) return;

                      // ✅ STEP 1: check assigned
                      for (final employee in _selectedEmployees) {
                        final isAssigned =
                            await EmployeeService.isEmployeeAssigned(
                              employee.employeeId ?? '',
                            );

                        if (isAssigned) {
                          if (!context.mounted) return;

                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Cannot Delete'),
                              content: Text(
                                'One or more selected employees are associated and cannot be deleted.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                      }

                      // ✅ STEP 2: confirm
                      final confirm = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ConfirmDialog(
                          title: 'Delete',
                          content:
                              'Are you sure you want to delete $_pageTitle?',
                        ),
                      );

                      if (confirm != true) return;

                      try {
                        // ✅ STEP 3: BACKUP
                        final deletedEmployees = _selectedEmployees
                            .where((e) => e.isEmployee)
                            .map((e) => e.toEmployeeModel())
                            .toList();

                        // ✅ STEP 4: LOADER
                        futureLoading(context);

                        // ✅ STEP 5: DELETE
                        for (final emp in _selectedEmployees) {
                          if (emp.uid.isNotEmpty && emp.isEmployee) {
                            await EmployeeService.deleteEmployee(uid: emp.uid);
                          }
                        }

                        // ✅ STEP 6: CLOSE LOADER
                        if (Navigator.canPop(context)) Navigator.pop(context);

                        // ✅ STEP 7: CLEAR SELECTION
                        _selectedEmployees.clear();
                        setState(() {});

                        // ✅ STEP 8: SHOW UNDO
                        FlushBar.show(
                          context,
                          'Employee deleted successfully',
                          actionLabel: 'UNDO',
                          onActionPressed: () async {
                            for (final emp in deletedEmployees) {
                              await EmployeeService.restoreEmployee(emp);
                            }

                            if (!context.mounted) return;

                            // 🔥 refresh users
                            context.read<UsersBloc>().add(StreamUsers());
                          },
                        );
                      } catch (e, st) {
                        if (Navigator.canPop(context)) Navigator.pop(context);

                        await ErrorService.recordError(e, st);

                        FlushBar.show(context, e.toString(), isSuccess: false);
                      }
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    label: Text(
                      "Delete",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    icon: const Icon(Iconsax.trash),
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
          );
        }
        if (_selectedEmployees.isNotEmpty) {
          // Chat Button
          buttons.add(
            ElevatedButton.icon(
              onPressed: () async {
                if (_selectedEmployees.isEmpty) {
                  FlushBar.show(
                    context,
                    "Please select at least one employee.",
                    isSuccess: false,
                  );
                  return;
                }
                final bool isSingle = _selectedEmployees.length == 1;
                final GlobalKey<FormState> formKey = GlobalKey<FormState>();

                final bool? confirm = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Text(
                      isSingle ? "Create Chat" : "Create Group Chat",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    content: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSingle
                                ? "Do you want to start a chat with ${_selectedEmployees.first.name}?"
                                : "Do you want to create a group chat with ${_selectedEmployees.length} employees?",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          FormFields(
                            label: 'Enter chat message',
                            controller: _chatMessage,
                            hintText: 'Enter Description',
                            maxLines: 3,
                            isRequired: true,
                            valid: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Chat message is required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          "Cancel",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          Navigator.pop(context, true);
                        },
                        child: Text(
                          "Confirm",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  futureLoading(context);

                  final sessionUser = await Spdb.getUser();
                  final creator = CacheService.getUserByUid(sessionUser.uid);

                  final creatorUid = creator?.uid ?? sessionUser.uid ?? '';
                  final creatorName = creator?.name ?? "";

                  if (isSingle) {
                    final emp = _selectedEmployees.first;

                    if (emp.uid.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }

                    // if (_chatMessage.text.isEmpty) {
                    //   FlushBar.show(
                    //     context,
                    //     "Please enter the chat message.",
                    //     isSuccess: false,
                    //   );
                    //   return;
                    // }

                    var chatId = await ChatService.createIndividualChat(
                      userId: emp.uid,
                    );

                    await ChatService.sendChatMessage(
                      chatId: chatId,
                      message: _chatMessage.text,
                      attachments: [],
                      replyFor: null,
                    );

                    Navigator.pop(context);
                    var currentUserUid = await Spdb.getUid();
                    if (currentUserUid != null) {
                      if (!mounted) return;
                      if (kIsDesktop) {
                        GeneralDialog.showRTLSheet(
                          context,
                          ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      } else if (kIsMobile) {
                        Sheet.showSheet(
                          context,
                          widget: ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      }
                    }
                    _chatMessage.clear();
                    setState(() {});
                    FlushBar.show(context, "Chat created");
                    return;
                  }

                  var groupUsers = [
                    ..._selectedEmployees
                        .map((e) => e.uid)
                        .where((id) => id.isNotEmpty),
                    sessionUser.uid,
                  ];

                  final chatModel = ChatModel(
                    createdBy: creatorUid,
                    participants: groupUsers,
                    participantsKey: groupUsers.join('_'),
                    title: "Group Chat",
                    description: "",
                    isGroupChat: true,
                    isPinned: false,
                    isFavorite: false,
                    lastMessage: LastMessageModel(
                      message: "$creatorName created group",
                      timestamp: DateTime.now(),
                      senderId: creatorUid,
                    ),
                  );

                  var chatId = await ChatService.createGroupChat(
                    model: chatModel,
                  );
                  Navigator.pop(context);

                  if (chatId != null) {
                    var currentUserUid = await Spdb.getUid();
                    if (currentUserUid != null) {
                      if (!mounted) return;
                      if (kIsDesktop) {
                        GeneralDialog.showRTLSheet(
                          context,
                          ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      } else if (kIsMobile) {
                        Sheet.showSheet(
                          context,
                          widget: ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      }
                    }
                  }

                  FlushBar.show(context, "Group chat created");
                } catch (e, st) {
                  await ErrorService.recordError(e, st);
                  Navigator.pop(context);
                  FlushBar.show(
                    context,
                    e.toString(),
                    isSuccess: false,
                    error: e,
                    stackTrace: st,
                  );
                }
              },
              icon: const Icon(Icons.chat, size: 18),
              label: Text(
                _selectedEmployees.length == 1
                    ? 'Chat with ${_selectedEmployees.first.name}'
                    : 'Group Chat (${_selectedEmployees.length})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onTertiaryContainer,
              ),
            ),
          );

          buttons.add(
            (tasksPermissions?.canCreate ?? false)
                ? ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskCreate(
                            employees: _selectedEmployees
                                .map((e) => e.toEmployeeModel())
                                .toList(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.task, size: 18),
                    label: Text(
                      "Create Task",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: null,
                    icon: Icon(
                      Icons.task,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      "Create Task",
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
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: kIsMobile || width < 1000
                      ? Wrap(spacing: 10, runSpacing: 10, children: buttons)
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: buttons),
                        ),
                ),

                IconButton(
                  tooltip: "Refresh",
                  icon: const Icon(Iconsax.refresh),
                  onPressed: _refreshUsers,
                  iconSize: 18,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget buildPlatformCell({
    required IconData icon,
    required String? platformLabel,
    required DateTime? lastLogin,
  }) {
    if (platformLabel == null && lastLogin == null) {
      return Text('No activity', style: _secondaryCellStyle(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              platformLabel ?? 'Unknown device',
              style: _primaryCellStyle(context, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (lastLogin != null)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              DateFormat('dd MMM, hh:mm a').format(lastLogin),
              style: _secondaryCellStyle(context),
            ),
          ),
      ],
    );
  }

  PlatformType? getPlatformFromDevice(DeviceModel device) {
    final platform = (device.platform ?? '').toLowerCase();
    if (platform.contains('android') || platform.contains('ios')) {
      return PlatformType.mobile;
    } else if (platform.contains('windows') ||
        platform.contains('mac') ||
        platform.contains('linux') ||
        platform.contains('microsoft')) {
      return PlatformType.desktop;
    }
    return null;
  }

  DateTime? getLastLoginByPlatform(
    List<DeviceModel> devices,
    PlatformType type,
  ) {
    final filtered = devices.where((d) => getPlatformFromDevice(d) == type);
    if (filtered.isEmpty) return null;

    return filtered
        .map((d) => d.lastLoginAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (prev, curr) {
          if (prev == null) return curr;
          return curr.isAfter(prev) ? curr : prev;
        });
  }

  String? getPlatformLabelByType(List<DeviceModel> devices, PlatformType type) {
    final filtered = devices.where((d) => getPlatformFromDevice(d) == type);
    if (filtered.isEmpty) return null;

    final sorted = filtered.toList()
      ..sort((a, b) {
        final aTime = a.lastLoginAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastLoginAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // descending
      });

    final device = sorted.first;
    return device.model?.isNotEmpty == true
        ? device.model
        : device.platform?.isNotEmpty == true
        ? device.platform
        : 'Unknown';
  }

  DataRow _buildDataRow(
    BuildContext context,
    UserRowModel user,
    int index,
    PaginatedDataController<UserRowModel> controllerWatch,
    PaginatedDataController<UserRowModel> controllerRead,
  ) {
    final width = MediaQuery.of(context).size.width;
    final devices = (user.devices ?? [])
        .map((e) => DeviceModel.fromMap(e))
        .toList();
    final mobileLastLogin = getLastLoginByPlatform(
      devices,
      PlatformType.mobile,
    );
    final desktopLastLogin = getLastLoginByPlatform(
      devices,
      PlatformType.desktop,
    );

    final mobilePlatformLabel = getPlatformLabelByType(
      devices,
      PlatformType.mobile,
    );
    final desktopPlatformLabel = getPlatformLabelByType(
      devices,
      PlatformType.desktop,
    );

    final isSelected = controllerWatch.selectedIds.contains(user.uid);

    // String getDepartmentNames(EmployeeModel? employee) {
    //   if (employee!.department == null || employee.department!.isEmpty) {
    //     return '';
    //   }

    //   return employee.department!
    //       .map((uid) => CacheService.departmentByUid(uid)?.name ?? '')
    //       .where((name) => name.isNotEmpty)
    //       .join(', ');
    // }

    void openUser(BuildContext context, UserRowModel user) {
      if (kIsMobile || width < 1000) {
        Sheet.showSheet(
          context,
          widget: user.isAdmin
              ? AdminProfile(admin: user.toAdminModel())
              : EmployeeDetails(employee: user.toEmployeeModel()),
        );
      } else {
        GeneralDialog.showRTLSheet(
          context,
          user.isAdmin
              ? AdminProfile(admin: user.toAdminModel())
              : EmployeeDetails(employee: user.toEmployeeModel()),
        );
      }
    }

    DataCell dataCell(BuildContext context, Widget child) {
      return DataCell(
        InkWell(
          onTap: () {
            openUser(context, user);
          },
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
        controllerRead.onSelected(user.uid, selected);
        if (selected ?? false) {
          if (!_selectedEmployees.any((e) => e.uid == user.uid)) {
            _selectedEmployees.add(user);
            _employeesList.add(user);
          }
        } else {
          _selectedEmployees.removeWhere((e) => e.uid == user.uid);
          _employeesList.removeWhere((e) => e.uid == user.uid);
        }
        setState(() {});
      },
      cells: [
        /// Employee ID
        dataCell(
          context,
          Text(
            user.employeeId ?? "",
            style: _primaryCellStyle(context, fontWeight: FontWeight.w500),
          ),
        ),

        /// Name + Avatar
        dataCell(
          context,
          Row(
            children: [
              UserAvatar(
                size: 32,
                showCrown: true,
                userData: UserDataModel(
                  uid: user.uid,
                  name: user.name,
                  profilePic: user.profileImageUrl,
                  userType: user.isAdmin ? UserType.admin : UserType.employee,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.name,
                      style: _primaryCellStyle(
                        context,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((CacheService.designationByUid(
                              user.designation ?? '',
                            )?.name ??
                            '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        CacheService.designationByUid(
                              user.designation ?? '',
                            )?.name ??
                            '',
                        style: _secondaryCellStyle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        /// Department
        dataCell(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.department != null && user.department!.isNotEmpty
                    ? user.department!
                          .map(
                            (uid) =>
                                CacheService.departmentByUid(uid)?.name ?? '',
                          )
                          .where((name) => name.isNotEmpty)
                          .join(', ')
                    : '',
                style: _primaryCellStyle(context, fontWeight: FontWeight.w500),
              ),

              if (user.subDepartment != null && user.subDepartment!.isNotEmpty)
                Text(
                  CacheService.subDepartmentByUid(user.subDepartment!)?.name ??
                      '',
                  style: _secondaryCellStyle(context),
                ),
            ],
          ),
        ),

        /// Role
        dataCell(
          context,
          Text(
            CacheService.roleByUid(user.role ?? '')?.name ?? '',
            style: _primaryCellStyle(context),
          ),
        ),

        /// Email
        dataCell(context, Text(user.email, style: _primaryCellStyle(context))),

        /// Mobile Platform
        dataCell(
          context,
          buildPlatformCell(
            icon: Icons.phone_android,
            platformLabel: mobilePlatformLabel,
            lastLogin: mobileLastLogin,
          ),
        ),

        /// Desktop Platform
        dataCell(
          context,
          buildPlatformCell(
            icon: Icons.desktop_windows,
            platformLabel: desktopPlatformLabel,
            lastLogin: desktopLastLogin,
          ),
        ),

        /// Status
        dataCell(
          context,
          controllerWatch.paginatedItems.isEmpty
              ? const NoData(text: "No matching records found")
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),

        /// Created By
        dataCell(context, CreatedByWidget(userData: user.createdBy)),

        /// Actions (no row tap)
        DataCell(
          Row(
            children: [
              (permissions?.canEdit ?? false)
                  ? IconButton(
                      icon: const Icon(Iconsax.edit),
                      color: Theme.of(context).colorScheme.secondary,
                      onPressed: () {
                        if (kIsMobile || width < 1000) {
                          Sheet.showSheet(
                            context,
                            widget: EmployeeEdit(
                              uid: user.uid,
                              admin: user.isAdmin ? user.toAdminModel() : null,
                            ),
                          );
                        } else {
                          GeneralDialog.showRTLSheet(
                            context,
                            EmployeeEdit(
                              uid: user.uid,
                              admin: user.isAdmin ? user.toAdminModel() : null,
                            ),
                          );
                        }
                      },
                    )
                  : IconButton(
                      icon: Icon(
                        Iconsax.edit,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: null,
                    ),
              if (!user.isAdmin)
                (permissions?.canDelete ?? false)
                    ? IconButton(
                        icon: const Icon(Iconsax.trash),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () async {
                          handleDelete(context, user);
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
}
