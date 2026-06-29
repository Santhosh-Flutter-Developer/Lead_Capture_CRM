import 'package:flutter/material.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class ProjectEdit extends StatefulWidget {
  final String uid;
  const ProjectEdit({super.key, required this.uid});

  @override
  State<ProjectEdit> createState() => _ProjectEditState();
}

class _ProjectEditState extends State<ProjectEdit> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController =
      TextEditingController();
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
  ClientModel? _selectedClientModel;
  String? _selectedProjectOwner;
  EmployeeModel? _selectedProjectOwnerModel;
  EmployeeModel? _selectedTeamLeadModel;
  String? _selectedTeamLead;
  List<String> _selectedProjectMembers = [];
  final List<EmployeeModel> _selectedProjectMemberModels = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;
  late ProjectModel _projectModel;

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

      _projectModel = await ProjectService.getProject(uid: widget.uid);
      _projectNameController.text = _projectModel.projectName;
      _projectDescriptionController.text = _projectModel.projectDescription;
      _projectCodeController.text = _projectModel.projectCode ?? '';
      _categoryController.text = _projectModel.category ?? '';
      _startDateController.text = _projectModel.startDate != null
          ? _projectModel.startDate!.formatDate
          : '';
      _selectedStartDate = _projectModel.startDate;
      _endDateController.text = _projectModel.endDate != null
          ? _projectModel.endDate!.formatDate
          : '';
      _selectedEndDate = _projectModel.endDate;
      _deadlineController.text = _projectModel.deadline != null
          ? _projectModel.deadline!.formatDate
          : '';
      _selectedDeadlineDate = _projectModel.deadline;
      _tagsController.text = _projectModel.tags ?? '';

      _selectedClient = _projectModel.client;
      if (_projectModel.client != null) {
        _selectedClientModel = await ClientService.getClient(
          uid: _projectModel.client!,
        );
      }
      _selectedProjectOwner = _projectModel.projectOwner;
      _selectedProjectOwnerModel = await EmployeeService.getEmployee(
        uid: _projectModel.projectOwner,
      );

      // Initialize Team Lead
      _selectedTeamLead = _projectModel.teamLead;
      _selectedTeamLeadModel = await EmployeeService.getEmployee(
        uid: _projectModel.teamLead,
      );

      _selectedProjectMembers.clear();
      _selectedProjectMemberModels.clear();
      _selectedProjectMembers = _projectModel.members;
      _selectedProjectMemberModels.clear();
      for (var i in _selectedProjectMembers) {
        var employee = await EmployeeService.getEmployee(uid: i);
        if (employee != null) {
          _selectedProjectMemberModels.add(employee);
        }
      }

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
    // _clientNameController.dispose();
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
                        title: "Update Project",
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
          isEdit: true,
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
            initialItem: _selectedProjectOwnerModel?.name,
            label: 'Project Lead',
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
            initialItem: _selectedTeamLeadModel?.name,
            label: 'Team Lead',
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
                initialValues: _selectedProjectMemberModels
                    .map((e) => e.name)
                    .toList(),
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
            label: 'Client',
            initialItem: _selectedClientModel?.isCompany == true
                ? _selectedClientModel?.companyName
                : _selectedClientModel?.clientName,
            items: _clientList
                .map(
                  (e) => e.isCompany
                      ? (e.companyName ?? '')
                      : (e.clientName ?? ''),
                )
                .where((e) => e.isNotEmpty)
                .toList(),
            onChanged: (value) async {
              var clientModel = _clientList.firstWhere(
                (element) =>
                    (element.isCompany
                        ? element.companyName
                        : element.clientName) ==
                    value,
              );
              _selectedClient = clientModel.uid;

              setState(() {});
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

        // var projectCodeExists = _projectCodeController.text.isNotEmpty
        //     ? await ProjectService.checkProjectCodeExists(
        //         code: _projectCodeController.text,
        //         uid: widget.uid,
        //       )
        //     : true;

        // if (projectCodeExists) {
        //   if (Navigator.canPop(context)) {
        //     Navigator.pop(context);
        //   }
        //   FlushBar.show(
        //     context,
        //     'Project Code already exists',
        //     isSuccess: false,
        //   );
        //   return;
        // }

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

        await ProjectService.editProject(
          uid: widget.uid,
          project: projectModel,
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Project updated successfully', isSuccess: true);
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
