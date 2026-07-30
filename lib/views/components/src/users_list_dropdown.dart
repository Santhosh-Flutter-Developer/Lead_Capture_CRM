import 'package:flutter/material.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/constants/src/enum.dart';

class UsersListDropdown extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String? Function(dynamic)? validator;
  final Function(List<dynamic>)? onChangedList;
  final List<dynamic> initialValues;
  final bool includeCurrentUser;
  final bool includeGroups;

  const UsersListDropdown({
    super.key,
    required this.label,
    this.isRequired = false,
    this.validator,
    this.onChangedList,
    this.initialValues = const [],
    this.includeCurrentUser = true,
    this.includeGroups = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFutureSearchableDropdown<dynamic>(
      label: label,
      isRequired: isRequired,
      validator: validator,
      initialValues: initialValues,
      asyncItems: () async {
        var admins = await AdminService.getAllAdmins();

        List<dynamic> result = [];

        if (!includeCurrentUser) {
          var currentUser = await Spdb.getUser();
          if (currentUser.userType == UserType.admin) {
            admins = admins
                .where((admin) => admin.uid != currentUser.uid)
                .toList();
          }
        }

        result.addAll(admins);

        if (includeGroups) {
          var groups = await ChatService.getChatGroups();
          result.addAll(groups);
        }

        return result;
      },
      multiSelect: true,
      itemAsString: (users) {
        if (users is AdminModel) {
          return '${users.name} (Admin)';
        } else if (users is ChatModel) {
          return '${users.title ?? ''} (${users.participants.length} Members)';
        }
        return "";
      },
      onChangedList: onChangedList,
    );
  }
}
