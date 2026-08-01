import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/views/screens/auth/src/company_registration.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);
        String input = _email.text.trim();
        var result = await AuthService.checkLogin(
          email: input,
          password: _password.text.trim(),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (!result["status"]) {
          FlushBar.show(context, result['error'], isSuccess: false);
          return;
        }
        String? companyLogo = result["companyLogo"];
        FlushBar.show(context, "Login Successful");

        bool isEmployee = result.containsKey("userData");
        if (isEmployee) {
          var data = result["userData"];
          var uid = result["uid"];
          EmployeeModel emp = EmployeeModel.fromMap(uid, data);
          if (emp.isInitialPasswordChanged == false) {
            Navigate.routeReplace(
              context,
              ChangeInitialPassword(
                companyId: result["collectionId"],
                employee: emp,
              ),
            );
            return;
          }
          if (emp.receiveEmailNotifications) {
            LoginAlertModel alertInfo =
                await LoginAlertDeviceInfo.getLoginAlertInfo();
            await EmailService.sendEmail(
              to: [emp.email.trim()],
              toName: [emp.name],
              subject: "New login alert",
              message: EmailTemplates.loginAlert
                  .replaceAll("{ip_address}", alertInfo.ipAddress)
                  .replaceAll("{location}", alertInfo.location)
                  .replaceAll("{datetime}", alertInfo.dateTime.listingDateTime)
                  .replaceAll("{device}", alertInfo.device),
            );
          }
          await Spdb.setEmployeeLogin(
            model: emp,
            cid: result["collectionId"],
            logoUrl: companyLogo,
          );
          RoleModel role = await RoleService.getRole(uid: emp.role);
          await PermissionService.savePermissions(role.permissions);
          await CacheService.syncAllCollections();
          if (kIsDesktop) {
            FirestoreNotificationListener.listenForNotifications();
          }
          Navigate.routeReplace(context, MainScreen(isAdmin: false));
          return;
        }

        var data = result["adminData"];
        var uid = result["uid"];
        AdminModel admin = AdminModel.fromMap(uid, data);
        await Spdb.setAdminLogin(
          model: admin,
          cid: result["collectionId"],
          logoUrl: companyLogo,
        );
        // await _storeDeviceLocationOnLogin();
        await PermissionService.savePermissions(AppStrings.permissionsTrueMap);

        await AuthService.saveLoginLogs(
          log: LoginLogsModel(
            loginAlert: (await LoginAlertDeviceInfo.getLoginAlertInfo()),
            user: await Spdb.getUser(),
          ),
        );
        if (kIsDesktop) {
          FirestoreNotificationListener.listenForNotifications();
        }
        Navigate.routeReplace(context, MainScreen(isAdmin: true));
      } catch (e, st) {
        // if (Navigator.canPop(context)) {
        //   Navigator.pop(context);
        // }
        await ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          ImageAssets.logoTransparent,
                          height: 55,
                          width: 55,
                        ),
                      ),
                      const Divider(height: 30, thickness: 1.2),
                      const SizedBox(height: 10),
                      Text(
                        "Login",
                        style: Theme.of(context).textTheme.headlineSmall!
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have account?",
                            style: Theme.of(context).textTheme.bodyLarge!
                                .copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          TextButton(
                            child: Text(
                              "Register",
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            onPressed: () {
                              Navigate.route(
                                context,
                                const CompanyRegistration(),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Email ID",
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          FormFields(
                            controller: _email,
                            valid: (value) => Validation.validEmail(
                              input: value ?? '',
                              isReq: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            hintText: "Enter Email ID",
                            prefixIcon: const Icon(Iconsax.user, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Password",
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          FormFields(
                            valid: (value) => Validation.commonValidation(
                              input: value ?? '',
                              isReq: true,
                              label: "Password",
                            ),
                            controller: _password,
                            keyboardType: TextInputType.visiblePassword,
                            hintText: "Enter password",
                            obsecureText: !_passwordVisible,
                            prefixIcon: const Icon(Iconsax.lock, size: 20),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() {
                                _passwordVisible = !_passwordVisible;
                              }),
                              icon: Icon(
                                _passwordVisible
                                    ? Iconsax.eye
                                    : Iconsax.eye_slash,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigate.route(
                                context,
                                const ForgotPassword(),
                              ),
                              child: Text(
                                "Forgot Password?",
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
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
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
}
