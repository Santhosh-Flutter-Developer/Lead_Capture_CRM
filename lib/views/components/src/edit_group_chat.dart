import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path/path.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class EditGroupChat extends StatefulWidget {
  final ChatModel chat;
  final List<dynamic>? employees;
  final List<dynamic>? admins;

  const EditGroupChat({
    super.key,
    required this.chat,
    this.employees,
    this.admins,
  });

  @override
  State<EditGroupChat> createState() => _EditGroupChatState();
}

class _EditGroupChatState extends State<EditGroupChat> {
  final TextEditingController _groupName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final List<dynamic> _members = [];
  List<dynamic> _selectedMembers = [];

  late Future _future;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<void> _init() async {
    try {
      _members.clear();
      _selectedMembers.clear();

      final employees = await EmployeeService.getAllEmployees();
      final admins = await AdminService.getAllAdmins();

      _members.addAll(employees);
      _members.addAll(admins);

      // 2️⃣ Prefill group name & description
      _groupName.text = widget.chat.title ?? '';
      _description.text = widget.chat.description ?? '';

      // 3️⃣ Create participant ID set
      final Set<String> participantIds = widget.chat.participants
          .map((e) => e.toString())
          .toSet();

      // 4️⃣ Prefill selected members
      _selectedMembers = _members.where((member) {
        final memberId = (member.uid ?? member.id)?.toString();
        return memberId != null && participantIds.contains(memberId);
      }).toList();

      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      FlushBar.show(context as BuildContext, e.toString(), isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return ErrorDisplay(error: snapshot.error.toString());
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Edit Group",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Divider(),

                    // Group Name
                    Text(
                      "Group Name",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FormFields(
                      controller: _groupName,
                      hintText: "Enter group name",
                    ),

                    const SizedBox(height: 20),

                    // Description
                    Text(
                      "Description",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FormFields(
                      controller: _description,
                      hintText: "Enter group description",
                      maxLines: 3,
                    ),

                    const SizedBox(height: 20),

                    // Members
                    Text(
                      "Members",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FormMultiDropdowns(
                      items: _members
                          .map<String>((e) => e.name.trim())
                          .toList(),
                      selectedItems: _selectedMembers
                          .map<String>((e) => e.name.trim())
                          .toList(),
                      onListChanged: (list) {
                        setState(() {
                          _selectedMembers = _members
                              .where((m) => list.contains(m.name.trim()))
                              .toList();
                        });
                      },
                    ),

                    const SizedBox(height: 40),

                    // Save Button
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (_groupName.text.isEmpty ||
                              _selectedMembers.isEmpty) {
                            FlushBar.show(
                              context,
                              "Please fill all required fields.",
                              isSuccess: false,
                            );
                            return;
                          }

                          try {
                            futureLoading(context);

                            // final updatedChat = widget.chat.copyWith(
                            //   title: _groupName.text,
                            //   description: _description.text,
                            //   participants: _selectedMembers
                            //       .map((e) => e.uid ?? e.id ?? '')
                            //       .toList(),
                            //   participantsKey: _selectedMembers
                            //       .map((e) => e.uid ?? e.id ?? '')
                            //       .join('_'),
                            // );

                            await ChatService.updateGroupChat(
                              chatId: widget.chat.uid!,
                              title: _groupName.text.trim(),
                              description: _description.text.trim(),
                              participantIds: _selectedMembers
                                  .map<String>((e) => e.uid ?? e.id ?? '')
                                  .toList(),
                            );

                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            Navigator.pop(context, true);
                            FlushBar.show(context, "Group chat updated");
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
                        },
                        icon: const Icon(
                          Iconsax.messages_2,
                          color: AppColors.white,
                        ),
                        label: Text(
                          "Update Group",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
