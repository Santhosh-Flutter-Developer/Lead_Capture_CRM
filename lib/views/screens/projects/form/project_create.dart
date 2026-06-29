import 'package:flutter/material.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class ProjectCreate extends StatefulWidget {
  const ProjectCreate({super.key});

  @override
  State<ProjectCreate> createState() => _ProjectCreateState();
}

class _ProjectCreateState extends State<ProjectCreate> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController =
      TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _projectCodeController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  DateTime? _selectedDeadlineDate;

  List<EmployeeModel> _employeesList = [];
  List<ClientModel> _clientList = [];
  String? _selectedClient;
  String? _selectedProjectOwner;
  String? _selectedTeamLead;
  final List<String> _selectedProjectMembers = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    try {
      _clientList.clear();
      _employeesList.clear();
      _employeesList = await EmployeeService.getAllEmployees();
      _clientList = await ClientService.getAllClients();
      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    _clientNameController.dispose();
    _projectCodeController.dispose();
    _categoryController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _deadlineController.dispose();
    _tagsController.dispose();
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

            return SingleChildScrollView(
              child: Center(
                child: Form(
                  key: _formKey,
                  child: Column(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormWidgets.buildHeader(
                        context: context,
                        title: "Create Project",
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: "Project Details",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildFormFields(constraints, 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: false,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Project Name',
            controller: _projectNameController,
            hintText: 'Enter Project Name',
            isRequired: true,
            valid: (input) => input == null || input.isEmpty
                ? 'Project Name is required'
                : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Project Description',
            controller: _projectDescriptionController,
            hintText: 'Enter Project Description',
            maxLines: 2,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: 'Project Lead',
            isRequired: true,
            validator: (input) => input == null || input.isEmpty
                ? 'Project Lead is required'
                : null,
            items: _employeesList.map((e) => e.name).toList(),
            onChanged: (value) async {
              var employeeModel = _employeesList.firstWhere(
                (element) => element.name == value,
              );
              _selectedProjectOwner = employeeModel.uid;

              setState(() {});
            },
          ),
        ),

        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: 'Team Lead',
            isRequired: true,
            validator: (input) =>
                input == null || input.isEmpty ? 'Team Lead is required' : null,
            items: _employeesList.map((e) => e.name).toList(),
            onChanged: (value) async {
              var employeeModel = _employeesList.firstWhere(
                (element) => element.name == value,
              );
              _selectedTeamLead = employeeModel.uid;

              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Members',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              CustomSearchableDropdown(
                items: _employeesList.map((e) => e.name).toList(),
                multiSelect: true,
                onChangedList: (list) {
                  for (var i in list) {
                    final emp = _employeesList.firstWhere(
                      (element) => element.name == i,
                    );

                    if (emp.uid != null) {
                      if (!_selectedProjectMembers.contains(emp.uid)) {
                        _selectedProjectMembers.add(emp.uid!);
                      }
                    }
                  }
                },
                itemAsString: (s) => s,
              ),
            ],
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            key: ValueKey(_clientList.length),
            label: 'Client',
            items: _clientList
                .map(
                  (e) => e.isCompany
                      ? (e.companyName ?? '')
                      : (e.clientName ?? ''),
                )
                .where((e) => e.isNotEmpty)
                .toList(),
            onChanged: (value) {
              final clientModel = _clientList.firstWhere(
                (element) =>
                    (element.isCompany
                        ? element.companyName
                        : element.clientName) ==
                    value,
              );

              setState(() {
                _selectedClient = clientModel.uid;
              });
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Project Code',
            controller: _projectCodeController,
            hintText: 'Enter Project Code',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Category',
            controller: _categoryController,
            hintText: 'Enter Category',
          ),
        ),

        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Start Date',
            controller: _startDateController,
            hintText: 'DD/MM/YYYY',
            readOnly: true,
            onTap: () async {
              var selectedDate = await datePicker(context);
              if (selectedDate != null) {
                _startDateController.text = selectedDate.formatDate;
                _selectedStartDate = selectedDate;
                setState(() {});
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'End Date',
            controller: _endDateController,
            hintText: 'DD/MM/YYYY',
            readOnly: true,
            onTap: () async {
              var selectedDate = await datePicker(context);
              if (selectedDate != null) {
                _endDateController.text = selectedDate.formatDate;
                _selectedEndDate = selectedDate;
                setState(() {});
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Deadline',
            controller: _deadlineController,
            hintText: 'DD/MM/YYYY',
            readOnly: true,
            onTap: () async {
              var selectedDate = await datePicker(context);
              if (selectedDate != null) {
                _deadlineController.text = selectedDate.formatDate;
                _selectedDeadlineDate = selectedDate;
                setState(() {});
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Tags',
            controller: _tagsController,
            hintText: 'Eg. UI, API, Urgent',
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        var projectCodeExists = _projectCodeController.text.isNotEmpty
            ? await ProjectService.checkProjectCodeExists(
                code: _projectCodeController.text,
              )
            : false;

        if (projectCodeExists) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(
            context,
            'Project Code already exists',
            isSuccess: false,
          );
          return;
        }

        ProjectModel projectModel = ProjectModel(
          projectName: _projectNameController.text,
          projectDescription: _projectDescriptionController.text,
          projectOwner: _selectedProjectOwner ?? '',
          teamLead: _selectedTeamLead ?? '',
          members: _selectedProjectMembers,
          client: _selectedClient,
          projectCode: _projectCodeController.text,
          category: _categoryController.text,
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
          deadline: _selectedDeadlineDate,
          tags: _tagsController.text,
          createdBy: await Spdb.getUser(),
        );

        await ProjectService.createProject(project: projectModel);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Project created successfully', isSuccess: true);
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
