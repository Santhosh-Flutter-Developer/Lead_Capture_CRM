import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class TicketCreate extends StatefulWidget {
  final List<EmployeeModel>? employees;

  const TicketCreate({super.key, this.employees});

  @override
  State<TicketCreate> createState() => _TicketCreateState();
}

class _TicketCreateState extends State<TicketCreate> {
  late Future _future;
  TicketPriority _priorityLevel = TicketPriority.medium;
  TicketCategory _category = TicketCategory.technicalSupport;
  TicketStatus _status = TicketStatus.open;
  TicketModeOfContact _modeOfContact = TicketModeOfContact.phone;
  final TextEditingController _ticketTitle = TextEditingController();
  final TextEditingController _ticketDescription = TextEditingController();
  final TextEditingController _clientName = TextEditingController();
  final TextEditingController _clientCompanyName = TextEditingController();
  final TextEditingController _deadline = TextEditingController();
  final TextEditingController _reminder = TextEditingController();

  final List<String> _selectedAssignTo = [];
  final List<String> _selectedCreatedBy = [];
  final List<String> _selectedObservers = [];
  final List<String> _selectedParticipants = [];

  List<ProjectModel> _projectList = [];
  List<TaskModel> _taskList = [];
  String? _selectedProject;
  String? _selectedTask;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<File> _selectedAttachments = [];
  DateTime? _selectedDeadline;
  DateTime? _selectedReminder;

  @override
  void initState() {
    super.initState();
    _future = _init();

    if (widget.employees != null && widget.employees!.isNotEmpty) {
      _selectedAssignTo.addAll(
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
            title: "Create New Ticket",
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
                      maxWidth: isDesktop ? 1400 : double.infinity,
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
                  title: "Ticket Details",
                  icon: Iconsax.document_text,
                  child: Column(
                    children: [
                      FormFields(
                        controller: _clientName,
                        label: "Client Name",
                        hintText: "Enter client name",
                        valid: (v) => Validation.commonValidation(
                          input: v,
                          label: "Client Name",
                          isReq: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FormFields(
                        controller: _clientCompanyName,
                        label: "Client Company Name",
                        hintText: "Enter company name (optional)",
                      ),
                      const SizedBox(height: 16),
                      _buildModeOfContactSelector(),
                      const SizedBox(height: 16),
                      FormFields(
                        controller: _ticketTitle,
                        label: "Ticket Title",
                        hintText: "Enter ticket title",
                        valid: (v) => Validation.commonValidation(
                          input: v,
                          label: "Ticket Title",
                          isReq: true,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                        "Task",
                        _taskList.map((e) => e.taskName).toList(),
                        (val) {
                          _selectedTask = _taskList
                              .firstWhere((e) => e.taskName == val)
                              .uid;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: "Ticket Settings",
                  icon: Iconsax.calendar_1,
                  child: Column(
                    children: [
                      _buildCategorySelector(),
                      const Divider(height: 32),
                      _buildStatusSelector(),
                      const Divider(height: 32),
                      _buildPrioritySelector(),
                      const Divider(height: 32),
                      _buildDeadlinePicker(),
                      const SizedBox(height: 16),
                      _buildReminderPicker(),
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
            title: "Ticket Details",
            icon: Iconsax.document_text,
            child: Column(
              children: [
                FormFields(
                  controller: _clientName,
                  label: "Client Name",
                  hintText: "Enter client name",
                  valid: (v) => Validation.commonValidation(
                    input: v,
                    label: "Client Name",
                    isReq: true,
                  ),
                ),
                const SizedBox(height: 16),
                FormFields(
                  controller: _clientCompanyName,
                  label: "Client Company Name",
                  hintText: "Enter company name (optional)",
                ),
                const SizedBox(height: 16),
                _buildModeOfContactSelector(),
                const SizedBox(height: 16),
                FormFields(
                  controller: _ticketTitle,
                  label: "Ticket Title",
                  hintText: "Enter ticket title",
                  valid: (v) => Validation.commonValidation(
                    input: v,
                    label: "Ticket Title",
                    isReq: true,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDescriptionField(),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                  "Task",
                  _taskList.map((e) => e.taskName).toList(),
                  (val) {
                    _selectedTask = _taskList
                        .firstWhere((e) => e.taskName == val)
                        .uid;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Ticket Settings",
            icon: Iconsax.calendar_1,
            child: Column(
              children: [
                _buildCategorySelector(),
                const SizedBox(height: 16),
                _buildStatusSelector(),
                const SizedBox(height: 16),
                _buildPrioritySelector(),
                const SizedBox(height: 16),
                _buildDeadlinePicker(),
                const SizedBox(height: 16),
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

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _ticketDescription,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: "Ticket Description",
        hintText: 'Describe the ticket details...',
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

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Priority Level",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TicketPriority.values.map((priority) {
            final isSelected = _priorityLevel == priority;
            return FilterChip(
              label: Text(priority.label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _priorityLevel = priority;
                });
              },
              selectedColor: _getPriorityColor(priority).withValues(alpha: 0.2),
              checkmarkColor: _getPriorityColor(priority),
              labelStyle: TextStyle(
                color: isSelected
                    ? _getPriorityColor(priority)
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? _getPriorityColor(priority)
                    : Theme.of(context).colorScheme.outline,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ticket Category",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketCategory>(
          initialValue: _category,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: TicketCategory.values.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category.label),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _category = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ticket Status",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketStatus>(
          initialValue: _status,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: TicketStatus.values.map((status) {
            return DropdownMenuItem(value: status, child: Text(status.label));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _status = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildModeOfContactSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Mode of Contact",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketModeOfContact>(
          initialValue: _modeOfContact,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: TicketModeOfContact.values.map((mode) {
            return DropdownMenuItem(value: mode, child: Text(mode.label));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _modeOfContact = value!;
            });
          },
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
            _selectedAssignTo.clear();
            _selectedAssignTo.addAll(list.map((e) => e.uid!));
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

  Widget _buildDeadlinePicker() {
    return FormFields(
      controller: _deadline,
      readOnly: true,
      onTap: () async {
        var date = await datePicker(context);
        if (date != null) {
          var time = await pickTime(context, null);
          if (time != null) {
            setState(() {
              _selectedDeadline = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              _deadline.text = "${date.formatDate} ${time.format(context)}";
            });
          }
        }
      },
      hintText: 'Select deadline (optional)',
      suffixIcon: const Icon(Iconsax.calendar_edit),
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
      hintText: 'Set reminder (optional)',
      suffixIcon: const Icon(Iconsax.notification),
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
              if (files != null) {
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
                        path.basename(file.path),
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
              "Create Ticket",
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
          List<String> urls = await StorageService.uploadFilesInBatch(
            files: _selectedAttachments,
            folder: StorageFolder.ticketAttachments,
          );
          for (var i = 0; i < _selectedAttachments.length; i++) {
            var file = _selectedAttachments[i];
            attachments.add(
              FileModel(
                name: path.basename(file.path),
                extension: path.extension(file.path).replaceAll('.', ''),
                size: file.lengthSync(),
                url: urls[i],
                mimeType: lookupMimeType(file.path) ?? '',
              ),
            );
          }
        }

        final ticket = CustomerTicketModel(
          clientName: _clientName.text,
          clientCompanyName: _clientCompanyName.text,
          modeOfContact: _modeOfContact,
          ticketTitle: _ticketTitle.text,
          ticketDescription: _ticketDescription.text,
          assignTo: _selectedAssignTo,
          createdBy: _selectedCreatedBy,
          observers: _selectedObservers,
          participants: _selectedParticipants,
          priorityLevel: _priorityLevel,
          deadline: _selectedDeadline,
          reminder: _selectedReminder,
          category: _category,
          status: _status,
          attachments: attachments,
          ticketCreatedBy: await Spdb.getUser(),
          project: _selectedProject,
          task: _selectedTask,
        );

        await TicketService.createTicket(ticket: ticket);
        Navigator.pop(context); // Pop loading
        Navigator.pop(context, true); // Close form
        FlushBar.show(context, 'Ticket created successfully', isSuccess: true);
      } catch (e, st) {
        Navigator.pop(context); // Pop loading
        ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
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
}
