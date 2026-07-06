import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class RoleEdit extends StatefulWidget {
  final String uid;
  const RoleEdit({super.key, required this.uid});

  @override
  State<RoleEdit> createState() => _RoleEditState();
}

class _RoleEditState extends State<RoleEdit> {
  final TextEditingController _roleNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<PermissionModel> _rows = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  RoleModel? _roleModel;
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<void> _init() async {
    _roleModel = await RoleService.getRole(uid: widget.uid);
    _roleNameController.text = _roleModel?.name ?? '';
    _descriptionController.text = _roleModel?.description ?? '';
    _rows = AppStrings.accessPagesList
        .map((page) => PermissionModel(page: page))
        .toList();

    if (_roleModel?.permissions.isNotEmpty ?? false) {
      for (var element in _rows) {
        final permission = _roleModel?.permissions.firstWhereOrNull(
          (e) => e.page == element.page,
        );
        if (permission != null) {
          element.canCreate = permission.canCreate;
          element.canDelete = permission.canDelete;
          element.canEdit = permission.canEdit;
          element.canView = permission.canView;
          element.canExport = permission.canExport;
          element.canImport = permission.canImport;

          final hasImportExport = AppStrings.pagesWithImportExport.contains(
            element.page,
          );
          bool allSelected =
              element.canEdit &&
              element.canDelete &&
              element.canCreate &&
              element.canView;
          if (hasImportExport) {
            allSelected = allSelected && element.canExport && element.canImport;
          }
          element.selectAll = allSelected;
        }
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _roleNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormWidgets.buildHeader(context: context, title: "Update Role"),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: Theme.of(context).cardTheme.color,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 20.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Role Information",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Divider(color: AppColors.grey300, thickness: 1),
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, constraints) =>
                                      _buildFormFields(constraints),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          color: Theme.of(context).cardTheme.color,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Permissions",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Divider(color: AppColors.grey300, thickness: 1),
                                const SizedBox(height: 20),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 24,
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 40,
                                    dataRowMaxHeight: 48,
                                    columns: [
                                      DataColumn(
                                        label: Text(
                                          'Page',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Select All',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'View',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Create',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Edit',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Delete',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Export',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Import',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                    rows: List.generate(_rows.length, (index) {
                                      final row = _rows[index];
                                      final hasImportExport = AppStrings
                                          .pagesWithImportExport
                                          .contains(row.page);

                                      List<DataCell> cells = [
                                        DataCell(
                                          Text(
                                            row.page,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                        DataCell(
                                          Checkbox(
                                            value: row.selectAll,
                                            onChanged: (val) {
                                              if (val == null) return;
                                              setState(() {
                                                row.selectAll = val;
                                                row.canView = val;
                                                if (val) {
                                                  row.canCreate = val;
                                                  row.canEdit = val;
                                                  row.canDelete = val;
                                                  if (hasImportExport) {
                                                    row.canExport = val;
                                                    row.canImport = val;
                                                  }
                                                } else {
                                                  row.canCreate = false;
                                                  row.canEdit = false;
                                                  row.canDelete = false;
                                                  row.canExport = false;
                                                  row.canImport = false;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          Checkbox(
                                            value: row.canView,
                                            onChanged: (val) {
                                              if (val == null) return;
                                              setState(() {
                                                row.canView = val;
                                                if (!val) {
                                                  row.canCreate = false;
                                                  row.canEdit = false;
                                                  row.canDelete = false;
                                                  row.canExport = false;
                                                  row.canImport = false;
                                                  row.selectAll = false;
                                                } else {
                                                  bool allSelected =
                                                      row.canEdit &&
                                                      row.canDelete &&
                                                      row.canCreate;
                                                  if (hasImportExport) {
                                                    allSelected =
                                                        allSelected &&
                                                        row.canExport &&
                                                        row.canImport;
                                                  }
                                                  row.selectAll = allSelected;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ];

                                      if (row.canView) {
                                        cells.addAll([
                                          DataCell(
                                            Checkbox(
                                              value: row.canCreate,
                                              onChanged: (val) {
                                                if (val == null) return;
                                                setState(() {
                                                  row.canCreate = val;
                                                  bool allSelected =
                                                      row.canEdit &&
                                                      row.canDelete &&
                                                      row.canCreate;
                                                  if (hasImportExport) {
                                                    allSelected =
                                                        allSelected &&
                                                        row.canExport &&
                                                        row.canImport;
                                                  }
                                                  row.selectAll = allSelected;
                                                });
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            Checkbox(
                                              value: row.canEdit,
                                              onChanged: (val) {
                                                if (val == null) return;
                                                setState(() {
                                                  row.canEdit = val;
                                                  bool allSelected =
                                                      row.canEdit &&
                                                      row.canDelete &&
                                                      row.canCreate;
                                                  if (hasImportExport) {
                                                    allSelected =
                                                        allSelected &&
                                                        row.canExport &&
                                                        row.canImport;
                                                  }
                                                  row.selectAll = allSelected;
                                                });
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            Checkbox(
                                              value: row.canDelete,
                                              onChanged: (val) {
                                                if (val == null) return;
                                                setState(() {
                                                  row.canDelete = val;
                                                  bool allSelected =
                                                      row.canEdit &&
                                                      row.canDelete &&
                                                      row.canCreate;
                                                  if (hasImportExport) {
                                                    allSelected =
                                                        allSelected &&
                                                        row.canExport &&
                                                        row.canImport;
                                                  }
                                                  row.selectAll = allSelected;
                                                });
                                              },
                                            ),
                                          ),
                                        ]);

                                        if (hasImportExport) {
                                          cells.addAll([
                                            DataCell(
                                              Checkbox(
                                                value: row.canExport,
                                                onChanged: (val) {
                                                  if (val == null) return;
                                                  setState(() {
                                                    row.canExport = val;
                                                    bool allSelected =
                                                        row.canEdit &&
                                                        row.canDelete &&
                                                        row.canCreate &&
                                                        row.canExport &&
                                                        row.canImport;
                                                    row.selectAll = allSelected;
                                                  });
                                                },
                                              ),
                                            ),
                                            DataCell(
                                              Checkbox(
                                                value: row.canImport,
                                                onChanged: (val) {
                                                  if (val == null) return;
                                                  setState(() {
                                                    row.canImport = val;
                                                    bool allSelected =
                                                        row.canEdit &&
                                                        row.canDelete &&
                                                        row.canCreate &&
                                                        row.canExport &&
                                                        row.canImport;
                                                    row.selectAll = allSelected;
                                                  });
                                                },
                                              ),
                                            ),
                                          ]);
                                        } else {
                                          cells.addAll([
                                            const DataCell(SizedBox()),
                                            const DataCell(SizedBox()),
                                          ]);
                                        }
                                      } else {
                                        cells.addAll([
                                          const DataCell(SizedBox()),
                                          const DataCell(SizedBox()),
                                          const DataCell(SizedBox()),
                                          const DataCell(SizedBox()),
                                          const DataCell(SizedBox()),
                                        ]);
                                      }

                                      return DataRow(cells: cells);
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: true,
        ),
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >= (minColumnWidth * 3 + horizontalSpacing * (3 - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (3 - 1)) / 3
        : currentWidth;

    return Form(
      key: _formKey,
      child: Wrap(
        spacing: horizontalSpacing,
        runSpacing: verticalSpacing,
        children: [
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Role Name',
              controller: _roleNameController,
              hintText: 'Enter Role Name',
              isRequired: true,
              valid: (val) =>
                  val == null || val.isEmpty ? 'Role name is required' : null,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Description',
              controller: _descriptionController,
              hintText: 'Enter Description',
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        final duplicateError = await RoleService.checkRoleNameExists(
          name: _roleNameController.text.trim(),
          excludeUid: widget.uid,
        );
        if (duplicateError != null) {
          if (Navigator.canPop(context)) Navigator.pop(context);
          FlushBar.show(context, duplicateError, isSuccess: false);
          return;
        }

        var reducedRows = _rows
            .where(
              (row) =>
                  row.canView || row.canCreate || row.canEdit || row.canDelete,
            )
            .toList();
        RoleModel roleModel = RoleModel(
          name: _roleNameController.text.trim(),
          description: _descriptionController.text.trim(),
          permissions: reducedRows,
          createdBy: await Spdb.getUser(),
        );

        await RoleService.editRole(uid: widget.uid, role: roleModel);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Role updated successfully', isSuccess: true);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        debugPrint("${e.toString()}, ${st.toString()}");
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          e.toString(),
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
