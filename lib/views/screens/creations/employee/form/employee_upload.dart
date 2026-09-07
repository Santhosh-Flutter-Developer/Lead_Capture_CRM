import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class EmployeeUploadPage extends StatefulWidget {
  const EmployeeUploadPage({super.key});

  @override
  State<EmployeeUploadPage> createState() => _EmployeeUploadPageState();
}

class _EmployeeUploadPageState extends State<EmployeeUploadPage> {
  String? _fileName;
  int _fileSize = 0;
  List<List<String>> _rows = [];
  bool _loading = false;

  Future<void> _pickAndParse() async {
    setState(() => _loading = true);

    try {
      // Picking file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final ext = file.extension?.toLowerCase();

      // Previously this read the file via dart:io's File(path).readAsBytes().
      // dart:io has no real filesystem on Flutter Web, so File(...) is a
      // stub there — touching it throws "Unsupported operation:
      // _Namespace" the instant a file is picked, silently resetting the
      // screen back to the empty upload zone. Request the bytes directly
      // from file_picker instead (withData: true above), matching the
      // approach already used for lead uploads.
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Could not read file bytes.');
      List<List<String>> rows = [];
      if (ext == 'csv') {
        final str = utf8.decode(bytes);
        rows = CsvReader().parse(str);
      } else if (ext == 'xlsx') {
        rows = await XlsxReader().readFromBytes(bytes);
      }

      setState(() {
        _fileName = file.name;
        _fileSize = file.size;
        _rows = rows;
      });
    } catch (e) {
      debugPrint('Error parsing file: $e');
      FlushBar.show(context, 'Error: ${e.toString()}', isSuccess: false);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetFile() {
    setState(() {
      _fileName = null;
      _fileSize = 0;
      _rows = [];
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
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
        appBar: AppBar(
          // leading: IconButton(
          //   icon: const Icon(Iconsax.close_circle, color: AppColors.text),
          //   onPressed: () => Navigator.of(context).pop(),
          //   tooltip: 'Close',
          // ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Text(
            'Import Employees',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: Theme.of(context).colorScheme.outlineVariant,
              height: 1,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(
                Iconsax.more,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                showCustomMenu(context);
              },
              tooltip: "Options",
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Upload Employee List',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Upload Employee List',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Upload Zone or File Info
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _fileName == null
                        ? _buildUploadZone()
                        : _buildFileInfoCard(),
                  ),

                  const SizedBox(height: 32),

                  // Preview Section (Only visible if data exists)
                  if (_rows.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Data Preview (${_rows.length - 1} entries)',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        if (_rows.length > 50)
                          Chip(
                            label: Text(
                              'Showing first 50',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewTable(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _loading ? null : _pickAndParse,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Soft background tint
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: TextSpan(
                      text: 'Click to upload',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: ' or drag and drop',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supported formats: .CSV, .XLSX',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(
                0xFF217346,
              ).withValues(alpha: 0.1), // Green tint
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.table_view,
              color: Color(0xFF217346),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName ?? 'Unknown file',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFileSize(_fileSize),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _resetFile,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_rows.isEmpty) return const SizedBox.shrink();

    final headers = _rows.first;
    final body = _rows.length > 1 ? _rows.sublist(1) : <List<String>>[];
    final maxCols = headers.length > 10 ? 10 : headers.length; // Limit columns

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).scaffoldBackgroundColor,
            ),
            columnSpacing: 24,
            horizontalMargin: 24,
            columns: List.generate(
              maxCols,
              (i) => DataColumn(
                label: Text(
                  headers[i].toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            rows: List.generate(body.length > 50 ? 50 : body.length, (index) {
              final row = body[index];
              return DataRow(
                cells: List.generate(maxCols, (cIdx) {
                  final val = cIdx < row.length ? row[cIdx] : '';
                  return DataCell(
                    Text(
                      val,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _uploadEmployeeData() async {
    try {
      if (_rows.isEmpty) return;

      if (_rows.first.length < 19) {
        FlushBar.show(
          context,
          "Error: The uploaded file does not have the required columns.",
          isSuccess: false,
        );
        return;
      }

      futureLoading(context);

      int uploadedCount = 0;
      int skippedCount = 0;

      // assuming row 0 is header
      final totalRows = _rows.length - 1;

      // Tracks why a row was skipped, e.g. "Duplicate employee" -> 3 rows,
      // so the closing toast can show a reason breakdown like the leads
      // import does, instead of a bare added/skipped count.
      final Map<String, int> skipReasons = {};
      void recordSkip(String reason) {
        skippedCount++;
        skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
      }

      // Load every existing employee once so duplicates can be checked
      // in-memory against the whole file, instead of hitting Firestore
      // three times per row the way the single-employee form does.
      final existingEmployees =
          await EmployeeService.getAllEmployeesForDuplicateCheck();
      final existingKeys = <String>{
        for (final emp in existingEmployees)
          ...EmployeeService.duplicateKeysForEmployee(emp),
      };

      for (var i = 1; i < _rows.length; i++) {
        final row = _rows[i];

        try {
          final hasRequiredFields =
              row[0].trim().isNotEmpty && // employeeId
              row[1].trim().isNotEmpty && // name
              row[3].trim().isNotEmpty && // password
              row[4].trim().isNotEmpty && // designation
              row[5].trim().isNotEmpty && // department
              row[11].trim().isNotEmpty; // role

          if (!hasRequiredFields) {
            recordSkip('Missing required fields');
            continue;
          }

          final rowKeys = EmployeeService.duplicateKeysFor(
            employeeId: row[0],
            email: row[2],
            mobileNumber: row[7],
          );
          final isDuplicate = rowKeys.any(existingKeys.contains);
          if (isDuplicate) {
            recordSkip('Duplicate employee (already exists)');
            continue;
          }

          final designation =
              await DesignationService.getDesignationByNameOrCreateDesignation(
                name: row[4].trim(),
              );

          final departmentNames = row[5]
              .split(',')
              .map((d) => d.trim())
              .where((d) => d.isNotEmpty)
              .toList();

          final department = await Future.wait(
            departmentNames.map(
              (d) => DepartmentService.getDepartmentByNameOrCreateDepartment(
                name: d,
              ),
            ),
          );

          String? subDepartment;
          if (row[6].trim().isNotEmpty) {
            subDepartment =
                await SubDepartmentService.getSubDepartmentByNameOrCreateSubDepartment(
                  name: row[6].trim(),
                  department: department.first,
                );
          }

          final genderValue = row[8].trim().toLowerCase();
          var gender = 'Male';
          if (genderValue == 'female') gender = 'Female';

          final role = await RoleService.getRoleByNameOrCreateRole(
            name: row[11].trim(),
          );

          final reportingToVal = row[12]
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          List<String> reportingTo = [];
          for (var i in reportingToVal) {
            if (i.isNotEmpty) {
              var uid = await EmployeeService.getEmployeeById(employeeId: i);
              if (uid != null) {
                reportingTo.add(uid);
              }
            }
          }

          final maritalStatusValue = row[17].trim().toLowerCase();
          var maritalStatus = 'Single';
          if (maritalStatusValue == 'married') {
            maritalStatus = 'Married';
          }

          final employeeTypeValue = row[18].trim().toLowerCase();
          var employeeType = 'Full Time';
          if (employeeTypeValue == 'part time') {
            employeeType = 'Part Time';
          } else if (employeeTypeValue == 'on contact') {
            employeeType = 'On Contact';
          } else if (employeeTypeValue == 'internship') {
            employeeType = 'Internship';
          } else if (employeeTypeValue == 'trainee') {
            employeeType = 'Trainee';
          }

          final employeeModel = EmployeeModel(
            employeeId: row[0].trim(),
            name: row[1].trim(),
            email: row[2].trim(),
            password: row[3].trim(),
            designation: designation,
            department: department,
            mobileNumber: row[7].trim(),
            gender: gender,
            subDepartment: subDepartment,
            dateOfJoining: DateFormat("dd-MM-yyyy").parse(row[9].trim()),
            dateOfBirth: DateFormat("dd-MM-yyyy").parse(row[10].trim()),
            role: role,
            reportingTo: reportingTo,
            address: row[13].trim(),
            about: row[14].trim(),
            loginAllowed: row[15].trim().toLowerCase() == 'yes',
            receiveEmailNotifications: row[16].trim().toLowerCase() == 'yes',
            maritalStatus: maritalStatus,
            skills: '',
            employeeType: employeeType,
            createdBy: await Spdb.getUser(),
          );

          await EmployeeService.createEmployee(employee: employeeModel);
          uploadedCount++;
          // Register this new employee's keys so a duplicate later in the
          // same file is also caught, not just duplicates against what
          // already existed before the upload started.
          existingKeys.addAll(rowKeys);
        } catch (e, st) {
          // Show the real error so future failures are self-diagnosing
          // from the toast itself, instead of a generic "skipped".
          final reason =
              'Upload error: ${e.toString().replaceFirst('Exception: ', '')}';
          recordSkip(reason);
          debugPrint('Error uploading row ${i + 1}: $e, $st');
        }
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);

      final buffer = StringBuffer()
        ..writeln("Upload Completed")
        ..writeln(
          "Total: $totalRows  •  Added: $uploadedCount  •  Skipped: $skippedCount",
        );

      if (skipReasons.isNotEmpty) {
        final reasonLines = skipReasons.entries
            .map((e) => "${e.key}: ${e.value}")
            .join('\n');
        buffer.write(reasonLines);
      }

      FlushBar.show(
        context,
        buffer.toString().trimRight(),
        isSuccess: uploadedCount > 0,
        duration: skipReasons.isEmpty
            ? const Duration(seconds: 5)
            : Duration(seconds: 5 + skipReasons.length),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(
        context,
        "Error uploading data: ${e.toString()}",
        isSuccess: false,
      );
    }
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _uploadEmployeeData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          icon: Icon(
            Icons.check,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          label: Text(
            'Complete Import',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void showCustomMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Theme.of(
        context,
      ).colorScheme.shadow.withValues(alpha: 0.3), // light dim background
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secAnimation, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)), // slide up
          child: Opacity(
            opacity: animation.value,
            child: Stack(
              children: [
                Positioned(right: 16, top: 70, child: _CustomMenuCard()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomMenuCard extends StatelessWidget {
  const _CustomMenuCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              context,
              icon: Icons.file_download_outlined,
              iconColor: Theme.of(context).colorScheme.primary,
              label: "Employee Template",
              onTap: () async {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await Download.downloadFromAsset(
                  context,
                  "assets/templates/employee_upload_template.xlsx",
                  "Employee_Template.xlsx",
                );
              },
            ),
            _menuItem(
              context,
              icon: Icons.contact_page_outlined,
              iconColor: Theme.of(context).colorScheme.secondary,
              label: "Sample Employee Data",
              onTap: () async {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await Download.downloadFromAsset(
                  context,
                  "assets/templates/employee_upload_template_with_data.xlsx",
                  "Employee_Sample_Data.xlsx",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}