import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class TaskCreate extends StatefulWidget {
  final List<EmployeeModel>? employees;

  const TaskCreate({super.key, this.employees});

  @override
  State<TaskCreate> createState() => _TaskCreateState();
}

class _TaskCreateState extends State<TaskCreate> {
  late Future _future;
  bool _highPriority = false;
  final bool _taskStatusSummary = false;
  final TextEditingController _taskName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _deadLine = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _reminder = TextEditingController();

  List<ProjectModel> _projectList = [];
  List<LeadModel> _leadList = [];
  List<TaskModel> _taskList = [];

  final List<String> _selectedAssignees = [];
  final List<String> _selectedCreatedBy = [];
  final List<String> _selectedObservers = [];
  final List<String> _selectedParticipants = [];

  String? _selectedProject;
  String? _selectedLead;
  String? _selectedSubTaskOf;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<PlatformFile> _selectedAttachments = [];
  DateTime? _selectedDeadLine;
  DateTime? _selectedReminder;
  bool _deadlineRequired = true;

  @override
  void initState() {
    super.initState();
    _future = _init();

    if (widget.employees != null && widget.employees!.isNotEmpty) {
      _selectedAssignees.addAll(
        widget.employees!
            .where((e) => e.uid != null)
            .map((e) => e.uid!)
            .toList(),
      );
    }
  }

  Future<void> _init() async {
    try {
      _projectList = await ProjectService.getAllProjects();
      _leadList = await LeadService.getAllLeads();
      _taskList = await TaskService.getAllTasks();
    } catch (e) {
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 900;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: FormWidgets.buildHeader(
            context: context,
            title: "Create New Task",
          ),
          body: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const WaitingLoading();
              } else if (snapshot.hasError) {
                return ErrorDisplay(error: snapshot.error.toString());
              }

              return Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1200 : double.infinity,
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: isDesktop
                        ? _buildDesktopLayout()
                        : _buildMobileLayout(),
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: _buildActionBottomBar(),
        );
      },
    );
  }

  /// DESKTOP LAYOUT: Two columns
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Primary Info
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: "Task Details",
                  icon: Iconsax.document_text,
                  child: Column(
                    children: [
                      _buildTaskNameField(),
                      const SizedBox(height: 20),
                      _buildDescriptionField(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: "Assignments",
                  icon: Iconsax.user_add,
                  child: _buildAssignmentGrid(),
                ),
                const SizedBox(height: 20),
                _buildAttachmentSection(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // RIGHT COLUMN: Settings & Metadata
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildSectionCard(
                  title: "Planning",
                  icon: Iconsax.calendar_1,
                  child: Column(
                    children: [
                      _buildPriorityToggle(),
                      const Divider(height: 32),
                      _buildDeadlinePicker(),
                      const SizedBox(height: 16),
                      _buildReminderPicker(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: "Context",
                  icon: Iconsax.hierarchy,
                  child: Column(
                    children: [
                      _buildDropdownField(
                        "Project",
                        _projectList.map((e) => e.projectName).toList(),
                        (val) {
                          _selectedProject = _projectList
                              .firstWhere((e) => e.projectName == val)
                              .uid;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        "Subtask of",
                        _taskList.map((e) => e.taskName).toList(),
                        (val) {
                          _selectedSubTaskOf = _taskList
                              .firstWhere((e) => e.taskName == val)
                              .uid;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        "Lead",
                        _leadList.map((e) => e.leadName).toList(),
                        (val) {
                          _selectedLead = _leadList
                              .firstWhere((e) => e.leadName == val)
                              .uid;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTagsField(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// MOBILE LAYOUT: Single Column
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSectionCard(
            title: "Task Details",
            icon: Iconsax.document_text,
            child: Column(
              children: [
                _buildTaskNameField(),
                const SizedBox(height: 16),
                _buildDescriptionField(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Planning",
            icon: Iconsax.calendar_1,
            child: Column(
              children: [
                _buildPriorityToggle(),
                _buildDeadlinePicker(),
                _buildReminderPicker(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Assignments",
            icon: Iconsax.user_add,
            child: _buildAssignmentGrid(),
          ),
          const SizedBox(height: 16),
          _buildAttachmentSection(),
        ],
      ),
    );
  }

  // --- REUSABLE COMPONENT BUILDERS ---

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTaskNameField() {
    return TextFormField(
      controller: _taskName,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Enter Task Title...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      validator: (v) => Validation.commonValidation(
        input: v,
        label: 'Task Name',
        isReq: true,
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _description,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'Describe the requirements and objectives...',
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPriorityToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _highPriority
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.priority_high,
                size: 16,
                color: _highPriority
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                "High Priority",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _highPriority
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: _highPriority,
          activeTrackColor: Theme.of(context).colorScheme.errorContainer,
          onChanged: (val) => setState(() => _highPriority = val),
        ),
      ],
    );
  }

  Widget _buildAssignmentGrid() {
    return Column(
      children: [
        UsersListDropdown(
          label: 'Assign To',
          initialValues: widget.employees ?? [],
          onChangedList: (list) {
            _selectedAssignees.clear();
            _selectedAssignees.addAll(list.map((e) => e.uid!));
          },
        ),
        const SizedBox(height: 12),
        UsersListDropdown(
          label: 'Participants',
          onChangedList: (list) {
            _selectedParticipants.clear();
            _selectedParticipants.addAll(list.map((e) => e.uid!));
          },
        ),
        const SizedBox(height: 12),
        UsersListDropdown(
          label: 'Observers',
          onChangedList: (list) {
            _selectedObservers.clear();
            _selectedObservers.addAll(list.map((e) => e.uid!));
          },
        ),
        const SizedBox(height: 12),
        UsersListDropdown(
          label: 'Created By',
          onChangedList: (list) {
            _selectedCreatedBy.clear();
            _selectedCreatedBy.addAll(list.map((e) => e.uid!));
          },
        ),
      ],
    );
  }

  Widget _buildDeadlinePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _deadlineRequired,
              onChanged: (val) => setState(() => _deadlineRequired = val!),
            ),
            const Text("Deadline Required"),
          ],
        ),
        FormFields(
          enabled: _deadlineRequired,
          controller: _deadLine,
          readOnly: true,
          onTap: () async {
            var date = await datePicker(context);
            if (date != null) {
              var time = await pickTime(context, null);
              if (time != null) {
                setState(() {
                  _selectedDeadLine = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                  _deadLine.text = "${date.formatDate} ${time.format(context)}";
                });
              }
            }
          },
          hintText: 'Select date & time',
          suffixIcon: const Icon(Iconsax.calendar_edit),
        ),
      ],
    );
  }

  Widget _buildReminderPicker() {
    return FormFields(
      controller: _reminder,
      readOnly: true,
      onTap: () async {
        var date = await datePicker(context);
        if (date != null) {
          var time = await pickTime(context, null);
          if (time != null) {
            setState(() {
              _selectedReminder = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              _reminder.text = "${date.formatDate} ${time.format(context)}";
            });
          }
        }
      },
      hintText: 'Set Reminder',
      suffixIcon: const Icon(Iconsax.notification),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    Function(dynamic) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FormDropdownSearch(items: items, onChanged: onChanged),
      ],
    );
  }

  Widget _buildTagsField() {
    return FormFields(
      hintText: 'Tag1, Tag2...',
      controller: _tags,
      label: 'Tags',
    );
  }

  Widget _buildAttachmentSection() {
    return _buildSectionCard(
      title: "Attachments",
      icon: Iconsax.paperclip,
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              var files = await FilePick.pickFiles(context);
              if (files != null && files.isNotEmpty) {
                setState(() => _selectedAttachments.addAll(files));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  style: BorderStyle.none,
                ),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Iconsax.cloud_plus,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text("Click to upload or drag and drop"),
                  Text(
                    "Support for PDF, DOC, images up to 10MB",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAttachments
                  .map(
                    (file) => Chip(
                      avatar: const Icon(Iconsax.document, size: 16),
                      label: Text(
                        file.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () =>
                          setState(() => _selectedAttachments.remove(file)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Discard"),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Iconsax.add_circle),
            label: const Text(
              "Create Task",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _submitForm,
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);
        List<FileModel> attachments = [];

        if (_selectedAttachments.isNotEmpty) {
          final fileDataList = await Future.wait(
            _selectedAttachments.map((pf) async {
              final bytes = await platformFileToBytes(pf);
              return (bytes: bytes, fileName: pf.name);
            }),
          );
          List<String> urls = await StorageService.uploadBytesInBatch(
            files: fileDataList,
            folder: StorageFolder.taskAttachments,
          );
          for (var i = 0; i < _selectedAttachments.length; i++) {
            final pf = _selectedAttachments[i];
            final ext = pf.extension ?? '';
            final mimeType = lookupMimeType(pf.name) ?? '';
            attachments.add(
              FileModel(
                name: pf.name,
                extension: ext,
                size: pf.size,
                url: urls[i],
                mimeType: mimeType,
              ),
            );
          }
        }

        final task = TaskModel(
          taskName: _taskName.text,
          description: _description.text,
          project: _selectedProject,
          subTaskOf: _selectedSubTaskOf,
          lead: _selectedLead,
          deadline: _selectedDeadLine,
          deadlineRequired: _deadlineRequired,
          highPriority: _highPriority,
          statusSummaryRequired: _taskStatusSummary,
          assignees: _selectedAssignees,
          createdBy: _selectedCreatedBy,
          observers: _selectedObservers,
          participants: _selectedParticipants,
          reminder: _selectedReminder,
          tags: _tags.text.split(','),
          attachments: attachments,
          taskCreatedBy: await Spdb.getUser(),
        );

        await TaskService.createTask(task: task);
        Navigator.pop(context); // Pop loading
        Navigator.pop(context, true); // Close form
        FlushBar.show(context, 'Task created successfully', isSuccess: true);
      } catch (e, st) {
        Navigator.pop(context); // Pop loading
        ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }
}
