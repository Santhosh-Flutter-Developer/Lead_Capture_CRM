import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/views/views.dart';

class CompanyRegistration extends StatefulWidget {
  const CompanyRegistration({super.key});

  @override
  State<CompanyRegistration> createState() => _CompanyRegistrationState();
}

class _CompanyRegistrationState extends State<CompanyRegistration> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  // Controllers
  final TextEditingController _companyName = TextEditingController();
  final TextEditingController _companyEmail = TextEditingController();
  final TextEditingController _adminName = TextEditingController();
  final TextEditingController _adminEmail = TextEditingController();
  final TextEditingController _password = TextEditingController();

  File? _logo;
  Uint8List? _logoBytes;
  bool _passwordVisible = false;
  @override
  void dispose() {
    _companyName.dispose();
    _companyEmail.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearForm() {
    _companyName.clear();
    _companyEmail.clear();
    _adminName.clear();
    _adminEmail.clear();
    _password.clear();

    setState(() {
      _logo = null;
      _logoBytes = null;
      _passwordVisible = false;
      _currentStep = 0;
    });

    _formKey.currentState?.reset();
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (!kIsWeb) {
          _logo = File(image.path);
        } else {
          _logoBytes = bytes;
        }
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);
        final existingAdmin = await AuthService.checkEmailExists(
          email: _adminEmail.text.trim(),
        );

        if (existingAdmin != null) {
          if (Navigator.canPop(context)) Navigator.pop(context);

          FlushBar.show(
            context,
            "Admin email already exists",
            isSuccess: false,
          );

          return;
        }

        var result = await AuthService.registerCompany(
          name: _companyName.text.trim(),
          adminEmail: _adminEmail.text.trim(),
          adminName: _adminName.text.trim(),
          password: _password.text.trim(),
          logo: kIsWeb?null:_logo,
          logoBytes: kIsWeb? _logoBytes: null,
        );

        if (Navigator.canPop(context)) Navigator.pop(context);

        if (result["status"]) {
          FlushBar.show(context, result["message"], isSuccess: true);
          _clearForm();
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Login()),
            );
          });
        } else {
          FlushBar.show(context, result['error'], isSuccess: false);
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStepper(),
                      const SizedBox(height: 25),

                      if (_currentStep == 0) ...[
                        // Logo Picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[100],
                            backgroundImage:_logoBytes !=null?MemoryImage(_logoBytes!): (_logo != null
                                ? FileImage(_logo!)
                                : null),
                            child: (_logoBytes==null && _logo == null)
                                ? const Icon(
                                    Iconsax.camera,
                                    color: Colors.blueAccent,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Company Details Section
                        _sectionTitle("Company Details"),
                        _customField("Company Name", _companyName, Iconsax.box),
                        _customField(
                          "Business Email",
                          _companyEmail,
                          Iconsax.sms,
                          isEmail: true,
                        ),
                      ] else if (_currentStep == 1) ...[
                        // Admin Setup Section
                        _sectionTitle("Super Admin Setup"),
                        _customField("Full Name", _adminName, Iconsax.user),
                        _customField(
                          "Admin Email",
                          _adminEmail,
                          Iconsax.sms,
                          isEmail: true,
                        ),
                        _passwordField(),
                      ],

                      const SizedBox(height: 35),

                      // Navigation Buttons
                      _buildNavigationButtons(),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Iconsax.login, size: 18),
                          label: Text(
                            "Back to Login",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ["Company", "Admin"];

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        // Even indices = step nodes, odd indices = connector lines
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < _currentStep;
          final isActive =
              stepIndex == _currentStep - 1 || stepIndex == _currentStep;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 24),
              color: isCompleted || isActive
                  ? Colors.blue
                  : Colors.grey.shade300,
            ),
          );
        }

        final index = i ~/ 2;
        final isCompleted = index < _currentStep;
        final isActive = index == _currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted || isActive ? Colors.blue : Colors.white,
                border: Border.all(
                  color: isCompleted || isActive
                      ? Colors.blue
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.grey.shade400,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isCompleted || isActive
                    ? Colors.blue
                    : Colors.grey.shade400,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }

  Widget _customField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: 8),
          FormFields(
            controller: controller,
            hintText: "Enter $label",
            prefixIcon: Icon(icon, size: 20),
            valid: (value) {
              if (isEmail) {
                return Validation.validEmail(input: value, isReq: true);
              }
              return Validation.commonValidation(
                input: value?.trim() ?? '',
                isReq: true,
                label: label,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Admin Password",
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.grey700,
          ),
        ),
        const SizedBox(height: 8),
        FormFields(
          controller: _password,
          obsecureText: !_passwordVisible,
          hintText: "Create password",
          prefixIcon: const Icon(Iconsax.lock, size: 20),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
            icon: Icon(
              _passwordVisible ? Iconsax.eye : Iconsax.eye_slash,
              size: 20,
            ),
          ),
          valid: (value) =>
              Validation.passwordValidation(input: value, isReq: true),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset(ImageAssets.logoTransparent, height: 45, width: 45),
          ],
        ),
        const Divider(height: 30, thickness: 1.2),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Register Company",
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C1F23),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Back"),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _currentStep < 1
              ? Container(
                  height: 45,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0052D4),
                        Color(0xFF4364F7),
                        Color(0xFF6FB1FC),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _currentStep++;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Next",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : _buildSubmitButton(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        onPressed: _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          "Create Account",textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
