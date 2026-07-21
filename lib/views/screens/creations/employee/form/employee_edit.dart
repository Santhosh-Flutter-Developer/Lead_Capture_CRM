import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';

class EmployeeEdit extends StatefulWidget {
  final String uid;
  final AdminModel? admin;
  const EmployeeEdit({super.key, required this.uid, this.admin});

  @override
  State<EmployeeEdit> createState() => _EmployeeEditState();
}

class _EmployeeEditState extends State<EmployeeEdit> {
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _dateOfJoiningController =
      TextEditingController();
  DateTime? _selectedDateOfJoining;
  final TextEditingController _dateOfBirthController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  bool _passwordVisible = false;

  List<RoleModel> _rolesList = [];
  List<DesignationModel> _designationList = [];
  List<DepartmentModel> _departmentList = [];
  List<SubDepartmentModel> _subDepartmentList = [];
  final List<dynamic> _initialReportingTo = [];

  final List<String> _reportingTo = [];
  final List<String> _department = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;

  String? _gender;
  String _loginAllowed = 'Yes';
  String _receiveEmailNotifications = 'Yes';
  String _maritalStatus = 'Single';
  String? _employeeType;
  String _outsideOffice = 'No';

  File? _selectedProfileImage;
  String? _profileImageUrl;
  bool _oldProfileImageRemoved = false;

  RoleModel? _roleModel;
  DesignationModel? _designationModel;
  DepartmentModel? _departmentModel;
  SubDepartmentModel? _subDepartmentModel;
  EmployeeModel? employee;
  EmployeeModel? _originalEmployee;
  AdminModel? _originalAdmin;
  bool _isActive = true;

  // State preservation for current form values when toggling Make as Admin
  String? _preservedEmployeeId;
  String? _preservedDesignation;
  List<String> _preservedDepartment = [];
  String? _preservedSubDepartment;
  String? _preservedGender;
  String? _preservedDateOfJoining;
  String? _preservedRole;
  List<String> _preservedReportingTo = [];

  @override
  void initState() {
    super.initState();
    _future = _init();

    if (employee != null) {
      _isActive = employee!.isActive;
    }
  }

  Future<void> _init() async {
    try {
      _rolesList.clear();
      _designationList.clear();
      _departmentList.clear();
      _subDepartmentList.clear();
      _initialReportingTo.clear();

      if (widget.admin != null) {
        _originalAdmin = widget.admin;
        _employeeIdController.text = "";
        _nameController.text = widget.admin!.name;
        _emailController.text = widget.admin!.email;
        _passwordController.text = widget.admin!.password;
        _mobileNumberController.text = widget.admin!.mobileNumber;
        _selectedDateOfBirth = widget.admin!.createdAt;
        isAdmin = true;

        // Try to fetch employee data from trash if it exists
        try {
          final cid = await Spdb.getCid();
          final snap = await FirebaseFirestore.instance
              .collection(Collections.users.name)
              .doc(cid)
              .collection(Collections.trash.name)
              .where('documentId', isEqualTo: widget.uid)
              .where('collection', isEqualTo: 'employees')
              .limit(1)
              .get();

          if (snap.docs.isNotEmpty) {
            final trashData = snap.docs.first.data();
            final employeeData = trashData['data'] as Map<String, dynamic>?;
            if (employeeData != null) {
              employee = EmployeeModel.fromMap(widget.uid, employeeData);
              _originalEmployee = employee;

              _preservedEmployeeId = employee!.employeeId;
              _preservedDesignation = employee!.designation;
              _preservedDepartment = List.from(employee!.department ?? []);
              _preservedSubDepartment = employee!.subDepartment;
              _preservedGender = employee!.gender;
              _preservedDateOfJoining = employee!.dateOfJoining.formatDate;
              _preservedRole = employee!.role;
              _preservedReportingTo = List.from(employee!.reportingTo ?? []);

              _skillsController.text = employee!.skills;
              _addressController.text = employee!.address;
              _aboutController.text = employee!.about;
              _loginAllowed = employee!.loginAllowed ? 'Yes' : 'No';
              _receiveEmailNotifications = employee!.receiveEmailNotifications
                  ? 'Yes'
                  : 'No';
              _maritalStatus = employee!.maritalStatus;
              _employeeType = employee!.employeeType;
              _outsideOffice = employee!.outsideOffice ? 'Yes' : 'No';
            }
          }
        } catch (e) {
          debugPrint("Failed to fetch employee from trash: $e");
        }
      } else {
        _rolesList = await RoleService.getAllRoles();
        _designationList = await DesignationService.getAllDesignations();
        _departmentList = await DepartmentService.getAllDepartments();

        employee = await EmployeeService.getEmployee(uid: widget.uid);
        _originalEmployee = employee;
        _employeeIdController.text = employee!.employeeId;
        _nameController.text = employee!.name;
        _emailController.text = employee!.email;
        _passwordController.text = employee!.password;
        _mobileNumberController.text = employee!.mobileNumber;
        _dateOfJoiningController.text = employee!.dateOfJoining.formatDate;
        _selectedDateOfJoining = employee!.dateOfJoining;
        _dateOfBirthController.text = employee!.dateOfBirth?.formatDate ?? '';
        _selectedDateOfBirth = employee!.dateOfBirth;
        _addressController.text = employee!.address;
        _aboutController.text = employee!.about;
        _skillsController.text = employee!.skills;

        _gender = employee!.gender;
        _loginAllowed = employee!.loginAllowed ? 'Yes' : 'No';
        _receiveEmailNotifications = employee!.receiveEmailNotifications
            ? 'Yes'
            : 'No';
        _maritalStatus = employee!.maritalStatus;
        _isActive = employee!.isActive;
        _employeeType = employee!.employeeType;
        _outsideOffice = employee!.outsideOffice ? 'Yes' : 'No';
        _profileImageUrl = employee!.profileImageUrl;

        _roleModel = await RoleService.getRole(uid: employee!.role);
        _designationModel = await DesignationService.getDesignation(
          uid: employee!.designation,
        );

        if (employee!.department != null && employee!.department!.isNotEmpty) {
          _department.clear();
          _department.addAll(employee!.department!);
        }

        if (_departmentModel != null) {
          _subDepartmentList =
              await SubDepartmentService.getSubDepartmentsByDepId(
                depId: _departmentModel!.uid ?? '',
              );
        }

        if (employee!.subDepartment != null &&
            employee!.subDepartment!.isNotEmpty) {
          _subDepartmentModel = await SubDepartmentService.getSubDepartment(
            uid: employee!.subDepartment ?? '',
          );
        }

        for (var i in (employee?.reportingTo ?? [])) {
          var emp = await EmployeeService.getEmployee(uid: i);
          if (emp != null) {
            _initialReportingTo.add(emp);
          } else {
            var admin = await AdminService.getAdmin(uid: i);
            if (admin != null) {
              _initialReportingTo.add(admin);
            }
          }
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

  Future<void> _handleIsAdminChange(bool value) async {
    if (value == isAdmin) return;

    if (value) {
      // Switching to admin mode - preserve current employee field values
      _preservedEmployeeId = _employeeIdController.text;
      _preservedDesignation = _designationModel?.uid;
      _preservedDepartment = List.from(_department);
      _preservedSubDepartment = _subDepartmentModel?.uid;
      _preservedGender = _gender;
      _preservedDateOfJoining = _dateOfJoiningController.text;
      _preservedRole = _roleModel?.uid;
      _preservedReportingTo = List.from(_reportingTo);

      // Clear employee-specific fields for admin view
      _employeeIdController.text = "";
      _dateOfJoiningController.text = "";
      _gender = null;
      _department.clear();
      _reportingTo.clear();
      _designationModel = null;
      _subDepartmentModel = null;
      _roleModel = null;
    } else {
      // Switching to employee mode - restore preserved values
      _employeeIdController.text =
          _preservedEmployeeId ?? _originalEmployee?.employeeId ?? '';
      _dateOfJoiningController.text =
          _preservedDateOfJoining ??
          _originalEmployee?.dateOfJoining.formatDate ??
          '';
      _gender = _preservedGender ?? _originalEmployee?.gender;

      _department.clear();
      if (_preservedDepartment.isNotEmpty) {
        _department.addAll(_preservedDepartment);
      } else if (_originalEmployee?.department != null &&
          _originalEmployee!.department!.isNotEmpty) {
        _department.addAll(_originalEmployee!.department!);
      }

      _reportingTo.clear();
      if (_preservedReportingTo.isNotEmpty) {
        _reportingTo.addAll(_preservedReportingTo);
      } else if (_originalEmployee?.reportingTo != null) {
        _reportingTo.addAll(_originalEmployee!.reportingTo!);
      }

      // Ensure dropdown lists are loaded
      if (_rolesList.isEmpty) {
        _rolesList = await RoleService.getAllRoles();
      }
      if (_designationList.isEmpty) {
        _designationList = await DesignationService.getAllDesignations();
      }
      if (_departmentList.isEmpty) {
        _departmentList = await DepartmentService.getAllDepartments();
      }

      // Restore dropdown models
      if (_preservedDesignation != null) {
        _designationModel = _designationList.firstWhere(
          (d) => d.uid == _preservedDesignation,
          orElse: () => _designationList.first,
        );
      } else if (_originalEmployee?.designation != null) {
        _designationModel = await DesignationService.getDesignation(
          uid: _originalEmployee!.designation,
        );
      }

      if (_preservedSubDepartment != null) {
        _subDepartmentList.clear();
        for (var depId in _department) {
          final subDeps = await SubDepartmentService.getSubDepartmentsByDepId(
            depId: depId,
          );
          _subDepartmentList.addAll(subDeps);
        }
        try {
          _subDepartmentModel = _subDepartmentList.firstWhere(
            (sd) => sd.uid == _preservedSubDepartment,
          );
        } catch (e) {
          _subDepartmentModel = _subDepartmentList.isNotEmpty
              ? _subDepartmentList.first
              : null;
        }
      } else if (_originalEmployee?.subDepartment != null) {
        _subDepartmentList.clear();
        for (var depId in _department) {
          final subDeps = await SubDepartmentService.getSubDepartmentsByDepId(
            depId: depId,
          );
          _subDepartmentList.addAll(subDeps);
        }
        _subDepartmentModel = await SubDepartmentService.getSubDepartment(
          uid: _originalEmployee!.subDepartment ?? '',
        );
      }

      if (_preservedRole != null) {
        _roleModel = _rolesList.firstWhere(
          (r) => r.uid == _preservedRole,
          orElse: () => _rolesList.first,
        );
      } else if (_originalEmployee?.role != null) {
        _roleModel = await RoleService.getRole(uid: _originalEmployee!.role);
      }

      // Restore reporting to list
      if (_preservedReportingTo.isNotEmpty) {
        _initialReportingTo.clear();
        for (var uid in _preservedReportingTo) {
          var emp = await EmployeeService.getEmployee(uid: uid);
          if (emp != null) {
            _initialReportingTo.add(emp);
          } else {
            var admin = await AdminService.getAdmin(uid: uid);
            if (admin != null) {
              _initialReportingTo.add(admin);
            }
          }
        }
      }
    }

    setState(() {
      isAdmin = value;
    });
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileNumberController.dispose();
    _dateOfJoiningController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    _skillsController.dispose();

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormWidgets.buildHeader(
                        context: context,
                        title: "Update Employee",
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: "Employee Details",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildFormFields(constraints, 4),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: "Contact Information",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildContactFormFields(constraints, 2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: "Other Details",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildOthersFormFields(constraints, 4),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: "Profile Photo",
                        child: Center(child: _buildProfileUploader()),
                      ),
                      const SizedBox(height: 80),
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
      color: Theme.of(context).cardTheme.color,
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

  void _markProfileImageReplaced() {
    if (_profileImageUrl != null) {
      _profileImageUrl = null;
      _oldProfileImageRemoved = true;
    }
  }

  Future<void> pickImage() async {
    // On Windows: use file picker only
    if (kIsWindows) {
      await _pickImageFromFile();
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final xFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
      );
      if (xFile == null) return;
      final rotated = await FlutterExifRotation.rotateImage(path: xFile.path);

      if (mounted) {
        setState(() {
          _selectedProfileImage = rotated;
          _markProfileImageReplaced();
        });
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, 'Failed to pick image: $e', isSuccess: false);
      }
    }
  }

  /// Windows-only: Pick an image file.
  Future<void> _pickImageFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Select a profile photo',
      );

      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;

      final imageFile = File(pickedPath);

      if (mounted) {
        setState(() {
          _selectedProfileImage = imageFile;
          _markProfileImageReplaced();
        });
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, 'Failed to pick image: $e', isSuccess: false);
      }
    }
  }

  Widget _buildProfileUploader() {
    if (_selectedProfileImage != null || _profileImageUrl != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: pickImage,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _profileImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _profileImageUrl!,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: AppColors.grey300,
                            highlightColor: AppColors.grey100,
                            child: Container(color: AppColors.white),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                          height: 130,
                          width: 130,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          _selectedProfileImage!,
                          height: 130,
                          width: 130,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      _selectedProfileImage = null;
                      if (_profileImageUrl != null) {
                        _profileImageUrl = null;
                        _oldProfileImageRemoved = true;
                      }
                      setState(() {});
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: pickImage,
            child: Text(
              kIsWindows ? 'Tap to change photo' : 'Tap to change photo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: pickImage,
      child: DottedBorder(
        options: RectDottedBorderOptions(),
        child: Container(
          height: 130,
          width: 130,
          decoration: const BoxDecoration(
            color: AppColors.grey200,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  kIsWindows ? Icons.upload_file_rounded : Iconsax.gallery,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  kIsWindows ? 'Choose Image File' : 'Upload Photo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    // Minimum width per column (you can tweak this)
    const double minColumnWidth = 220.0;

    // Calculate the maximum number of columns that can fit
    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    // Calculate each item width
    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Employee Id',
              controller: _employeeIdController,
              hintText: 'Enter Employee Id',
              isRequired: true,
              valid: (input) => Validation.commonValidation(
                input: input,
                label: 'Employee Id',
                isReq: true,
              ),
            ),
          ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Employee Name',
            controller: _nameController,
            hintText: 'Enter Employee Name',
            isRequired: true,
            valid: (input) => Validation.validName(
              input: input,
              label: 'Employee Name',
              isReq: true,
            ),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Email',
            controller: _emailController,
            hintText: 'Enter Email',
            isRequired: isAdmin,
            valid: (input) =>
                Validation.validEmail(input: input, isReq: isAdmin),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Enter Password',
            isRequired: true,
            valid: (input) =>
                Validation.passwordValidation(input: input, isReq: true),
            obsecureText: !_passwordVisible,
            suffixIcon: IconButton(
              onPressed: () => setState(() {
                _passwordVisible = !_passwordVisible;
              }),
              icon: _passwordVisible
                  ? const Icon(Iconsax.eye)
                  : const Icon(Iconsax.eye_slash),
            ),
          ),
        ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem:
                  _designationModel != null &&
                      _designationModel!.name.isNotEmpty
                  ? _designationModel?.name
                  : null,
              items: _designationList.map((e) => e.name.toString()).toList(),
              label: 'Designation',
              isRequired: true,
              onChanged: (value) {
                _designationModel = _designationList.firstWhere(
                  (element) => element.name == value,
                );
              },
              validator: (value) {
                if (value == null) {
                  return "* Required";
                }
                return null;
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Department",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                CustomSearchableDropdown<String>(
                  items: _departmentList.map((e) => e.name.toString()).toList(),
                  multiSelect: true,

                  initialValues: _departmentList
                      .where((d) => _department.contains(d.uid))
                      .map((d) => d.name)
                      .toList(),

                  itemAsString: (s) => s,

                  onChangedList: (selectedNames) async {
                    _department.clear();

                    for (var name in selectedNames) {
                      final dep = _departmentList.firstWhere(
                        (d) => d.name == name,
                      );
                      if (dep.uid != null) {
                        _department.add(dep.uid!);
                      }
                    }

                    _subDepartmentList.clear();

                    for (var depId in _department) {
                      final subDeps =
                          await SubDepartmentService.getSubDepartmentsByDepId(
                            depId: depId,
                          );
                      _subDepartmentList.addAll(subDeps);
                    }

                    setState(() {});
                  },
                ),
              ],
            ),
          ),

        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem:
                  _subDepartmentModel != null &&
                      _subDepartmentModel!.name.isNotEmpty
                  ? _subDepartmentModel?.name
                  : null,
              items: _subDepartmentList.map((e) => e.name.toString()).toList(),
              label: 'Sub Department',
              onChanged: (value) {
                _subDepartmentModel = _subDepartmentList.firstWhere(
                  (element) => element.name == value,
                );
              },
            ),
          ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Mobile Number',
            controller: _mobileNumberController,
            hintText: 'Enter Mobile Number',
            valid: (input) =>
                Validation.validMobileNumber(input: input, isReq: false),
          ),
        ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem: _gender != null && _gender!.isNotEmpty
                  ? _gender
                  : null,
              items: const ['Male', 'Female', 'Others'],
              label: 'Gender',
              isRequired: true,
              onChanged: (value) {
                if (value != null) {
                  _gender = value.toString();
                }
              },
              validator: (value) {
                if (value == null) {
                  return "* Required";
                }
                return null;
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Joining Date',
              controller: _dateOfJoiningController,
              hintText: 'DD/MM/YYYY',
              readOnly: true,
              isRequired: true,
              valid: (input) => Validation.commonValidation(
                input: input,
                label: 'Joining Date',
                isReq: true,
              ),
              onTap: () async {
                var result = await datePicker(context);
                if (result != null) {
                  _dateOfJoiningController.text = result.formatDate;
                  _selectedDateOfJoining = result;
                }
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Birth Date',
              controller: _dateOfBirthController,
              hintText: 'DD/MM/YYYY',
              readOnly: true,
              onTap: () async {
                var result = await datePicker(
                  context,
                  lastDate: DateTime.now(),
                );
                if (result != null) {
                  _dateOfBirthController.text = result.formatDate;
                  _selectedDateOfBirth = result;
                }
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem: _roleModel != null && _roleModel!.name.isNotEmpty
                  ? _roleModel?.name
                  : null,
              items: _rolesList.map((e) => e.name.toString()).toList(),
              label: 'Role',
              isRequired: true,
              onChanged: (value) {
                _roleModel = _rolesList.firstWhere(
                  (element) => element.name == value,
                );
              },
              validator: (value) {
                if (value == null) {
                  return "* Required";
                }
                return null;
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: UsersListDropdown(
              label: 'Reporting To',
              initialValues: _initialReportingTo,
              onChangedList: (list) {
                _reportingTo.clear();
                _reportingTo.addAll(list.map((e) => e.uid!));
                _initialReportingTo.clear();
                _initialReportingTo.addAll(list);
              },
              includeCurrentUser: false,
            ),
          ),
        Container(
          width: itemWidth,
          padding: EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: isAdmin,
                onChanged: (value) {
                  if (value != null) {
                    _handleIsAdminChange(value);
                  }
                },
              ),
              Text("Make as Admin"),
            ],
          ),
        ),

        Container(
          width: itemWidth,
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Switch(
                value: _isActive,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                _isActive ? 'Active' : 'Inactive',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool isAdmin = false;

  Widget _buildContactFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    // Minimum width per column (you can tweak this)
    const double minColumnWidth = 220.0;

    // Calculate the maximum number of columns that can fit
    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    // Calculate each item width
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
            label: 'Address',
            controller: _addressController,
            hintText: 'Enter Address',
            maxLines: 2,
            valid: (input) =>
                Validation.validAddress(input: input ?? '', isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'About',
            controller: _aboutController,
            hintText: 'Enter About',
            maxLines: 2,
            valid: (input) => Validation.commonValidation(
              input: input,
              label: 'About',
              isReq: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOthersFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    // Minimum width per column (you can tweak this)
    const double minColumnWidth = 220.0;

    // Calculate the maximum number of columns that can fit
    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    // Calculate each item width
    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const ['Yes', 'No'],
            initialItem: _loginAllowed,
            label: 'Login Allowed',
            onChanged: (value) {
              if (value != null) {
                _loginAllowed = value.toString();
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const ['Yes', 'No'],
            initialItem: _receiveEmailNotifications,
            label: 'Receive Email Notifications',
            onChanged: (value) {
              if (value != null) {
                _receiveEmailNotifications = value.toString();
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const ['Single', 'Married'],
            initialItem: _maritalStatus,
            label: 'Marital Status',
            onChanged: (value) {
              if (value != null) {
                _maritalStatus = value.toString();
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const [
              'Full Time',
              'Part Time',
              'On Contract',
              'Internship',
              'Trainee',
            ],
            label: 'Employee Type',
            initialItem: _employeeType != null && _employeeType!.isNotEmpty
                ? _employeeType
                : null,
            onChanged: (value) {
              if (value != null) {
                _employeeType = value.toString();
              }
            },
          ),
        ),
        // SizedBox(
        //   width: itemWidth,
        //   child: FormDropdownSearch(
        //     items: const ['Yes', 'No'],
        //     initialItem: _outsideOffice,
        //     label: 'Allow Outside Office Punch',
        //     onChanged: (value) {
        //       if (value != null) {
        //         _outsideOffice = value.toString();
        //       }
        //     },
        //   ),
        // ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (isAdmin) {
          futureLoading(context);

          String? profileImageUrl;

          if (_selectedProfileImage != null) {
            profileImageUrl = await StorageService.uploadFile(
              file: _selectedProfileImage!,
              folder: StorageFolder.adminProfile,
            );
          }

          AdminModel adminModel = AdminModel(
            uid: widget.uid,
            email: _emailController.text.trim(),
            name: _nameController.text.trim(),
            password: _passwordController.text,
            mobileNumber: _mobileNumberController.text.trim(),
            profileImageUrl: profileImageUrl,
            isActive: _isActive,
            createdBy: await Spdb.getUser(),
          );

          await AdminService.updateAdmin(id: widget.uid, data: adminModel);

          // Delete the employee document since they're now an admin
          try {
            await EmployeeService.deleteEmployee(uid: widget.uid);
          } catch (e) {
            // If deleting fails, just log it but don't fail the whole process
            debugPrint(
              "Failed to delete employee document after converting to admin: $e",
            );
          }

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          Navigator.pop(context, true);
          FlushBar.show(context, "Admin updated successfully", isSuccess: true);
        } else {
          futureLoading(context);

          var duplicateError = await EmployeeService.checkEmployeeExists(
            employeeId: _employeeIdController.text,
            email: _emailController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
            excludeUid: widget.uid,
          );

          if (duplicateError != null) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            FlushBar.show(context, duplicateError, isSuccess: false);
            return;
          }

          // Determine final profile image URL:
          // - Use newly uploaded image if one was picked
          // - Keep existing URL if the image was not removed
          // - Use null if the image was explicitly removed
          String? profileImageUrl;
          if (_selectedProfileImage != null) {
            profileImageUrl = await StorageService.uploadFile(
              file: _selectedProfileImage!,
              folder: StorageFolder.userPhotos,
            );
          } else if (!_oldProfileImageRemoved) {
            profileImageUrl = _profileImageUrl;
          }

          if (_oldProfileImageRemoved) {
            await EmployeeService.deleteEmployeeImage(uid: widget.uid);
          }

          EmployeeModel employeeModel = EmployeeModel(
            uid: widget.uid,
            employeeId: _employeeIdController.text,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            designation: _designationModel?.uid ?? '',
            department: _department,
            subDepartment: _subDepartmentModel?.uid,
            mobileNumber: _mobileNumberController.text.trim(),
            gender: _gender ?? 'Male',
            dateOfJoining:
                _selectedDateOfJoining ??
                _originalEmployee?.dateOfJoining ??
                DateTime.now(),
            dateOfBirth: _selectedDateOfBirth,
            role: _roleModel?.uid ?? '',
            address: _addressController.text.trim(),
            about: _aboutController.text.trim(),
            loginAllowed: _loginAllowed == 'Yes',
            receiveEmailNotifications: _receiveEmailNotifications == 'Yes',
            maritalStatus: _maritalStatus,
            isActive: _isActive,
            employeeType: _employeeType ?? '',
            profileImageUrl: profileImageUrl,
            skills: _skillsController.text.trim(),
            reportingTo: _reportingTo,
            outsideOffice: _outsideOffice == 'Yes',
            createdBy: await Spdb.getUser(),
          );

          // Delete the admin document since they're now an employee
          try {
            await AdminService.deleteAdmin(uid: widget.uid);
          } catch (e) {
            debugPrint("Failed to delete admin document: $e");
          }

          final cid = await Spdb.getCid();
          await FirebaseFirestore.instance
              .collection(Collections.users.name)
              .doc(cid)
              .collection(Collections.employees.name)
              .doc(widget.uid)
              .set(employeeModel.toMap());

          // Delete the trash entry for this employee
          try {
            final snap = await FirebaseFirestore.instance
                .collection(Collections.users.name)
                .doc(cid)
                .collection(Collections.trash.name)
                .where('documentId', isEqualTo: widget.uid)
                .where('collection', isEqualTo: 'employees')
                .get();
            for (var doc in snap.docs) {
              await doc.reference.delete();
            }
          } catch (e) {
            debugPrint("Failed to delete trash entry: $e");
          }

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          Navigator.pop(context, true);

          FlushBar.show(
            context,
            'Employee updated successfully',
            isSuccess: true,
          );
        }
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
