import 'package:flutter/material.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

class SubDepartmentEdit extends StatefulWidget {
  final String uid;
  const SubDepartmentEdit({super.key, required this.uid});

  @override
  State<SubDepartmentEdit> createState() => _SubDepartmentEditState();
}

class _SubDepartmentEditState extends State<SubDepartmentEdit> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  SubDepartmentModel? _subDepartmentModel;
  DepartmentModel? _selectedDepartment;
  late Future _future;

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    _subDepartmentModel = await SubDepartmentService.getSubDepartment(
      uid: widget.uid,
    );

    _nameController.text = _subDepartmentModel?.name ?? '';
    _descriptionController.text = _subDepartmentModel?.description ?? '';

    _selectedDepartment = await DepartmentService.getDepartment(
      uid: _subDepartmentModel?.department ?? '',
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              );
            }

            return Column(
              children: [
                FormWidgets.buildHeader(
                  context: context,
                  title: "Update Sub Department",
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 500),
                      child: Card(
                        color: Theme.of(context).cardTheme.color,
                        elevation: 7,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 24.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sub Department Information",
                                style: Theme.of(context).textTheme.titleMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Divider(color: Theme.of(context).colorScheme.outlineVariant, thickness: 1),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildFormFields(constraints),
                              ),
                            ],
                          ),
                        ),
                      ),
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
              label: 'Sub Department Name',
              controller: _nameController,
              hintText: 'Enter sub department name',
              isRequired: true,
              valid: (input) => input == null || input.isEmpty
                  ? 'Sub Department Name is required'
                  : null,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: CustomFutureSearchableDropdown<DepartmentModel>(
              label: 'Department',
              isRequired: true,
              validator: (_) {
                if (_selectedDepartment == null) {
                  return 'Department is required';
                }
                return null;
              },
              initialValue: _selectedDepartment,
              asyncItems: () async {
                var departments = await DepartmentService.getAllDepartments();
                return departments;
              },
              itemAsString: (departments) => departments.name,
              onChanged: (selectedDep) {
                setState(() {
                  _selectedDepartment = selectedDep;
                });
              },
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Description',
              controller: _descriptionController,
              hintText: 'Enter description (optional)',
              maxLines: 4,
              keyboardType: TextInputType.multiline,
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

        String? duplicateError = await SubDepartmentService.checkSubDepartmentExists(
          name: _nameController.text.trim(),
          excludeUid: widget.uid,
        );

        if (duplicateError != null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(
            context,
            duplicateError,
            isSuccess: false,
          );
          return;
        }

        final subDepartmentModel = SubDepartmentModel(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          department: _selectedDepartment?.uid ?? '',
          createdBy: await Spdb.getUser(),
        );

        await SubDepartmentService.editSubDepartment(
          uid: widget.uid,
          subDepartment: subDepartmentModel,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(
          context,
          'Sub Department updated successfully',
          isSuccess: true,
        );
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
