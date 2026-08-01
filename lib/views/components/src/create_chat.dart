import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';

class CreateChat extends StatefulWidget {
  final dynamic employee;
  final List<dynamic>? employees;

  const CreateChat({super.key, this.employee, this.employees});

  @override
  State<CreateChat> createState() => _CreateChatState();
}

class _CreateChatState extends State<CreateChat>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _groupName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _chatMessage = TextEditingController();
  final List<dynamic> _members = [];
  final List<dynamic> _selectedMembers = [];
  final List<dynamic> _employees = [];
  final List<dynamic> _admins = [];

  late Future _future;

  // Replaced two specific selections with a single selected user id
  String? _selectedUserId;
  dynamic
  _selectedUser; // optional — holds the selected object if you want to show details

  @override
  void initState() {
    _future = _init();
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  Future<void> _init() async {
    try {
      _members.clear();
      _employees.clear();
      _admins.clear();

      var employees = await EmployeeService.getAllEmployees();
      var admins = await AdminService.getAllAdmins();

      _members.addAll(employees);
      _members.addAll(admins);

      _employees.addAll(employees); // employees only
      _admins.addAll(admins); // admins only

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
    _chatMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return ErrorDisplay(error: snapshot.error.toString());
            } else {
              return Column(
                children: [
                  PreferredSize(
                    preferredSize: const Size(double.infinity, 50),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        padding: EdgeInsets.zero,
                        controller: _tabController,
                        labelColor: Theme.of(context).colorScheme.onSurface,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        tabs: [
                          Tab(
                            child: Text(
                              "Individual",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Tab(
                            child: Text(
                              "Group",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // -------------------- Individual Chat Tab --------------------
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create Chat",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const Divider(),

                              // --- SINGLE combined dropdown for employees + admins ---
                              FormDropdownSearch(
                                label: 'Select User',
                                // show both employee and admin names
                                items: _members.map((e) => e.name).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    // find selected object in members by name
                                    var selected = _members.firstWhere(
                                      (m) => m.name == value,
                                    );
                                    // store id and the object
                                    setState(() {
                                      _selectedUserId =
                                          selected.uid ?? selected.id ?? "";
                                      _selectedUser = selected;
                                    });
                                  } else {
                                    setState(() {
                                      _selectedUserId = null;
                                      _selectedUser = null;
                                    });
                                  }
                                },
                              ),

                              const SizedBox(height: 8),

                              if (_selectedUser != null)
                                Row(
                                  children: [
                                    Icon(
                                      _selectedUser is AdminModel
                                          ? Icons.shield
                                          : Icons.person,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedUser is AdminModel
                                          ? "Admin"
                                          : "Employee",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 8),

                              TextFormField(
                                controller: _chatMessage,
                                maxLines: 3,
                                validator: (val) => val == null || val.isEmpty
                                    ? 'Chat message is required'
                                    : null,

                                enableSuggestions: true,
                                autocorrect: true,
                                spellCheckConfiguration:
                                    const SpellCheckConfiguration(),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Enter chat message',
                                  hintText: 'Enter Description',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // --- Create Button ---
                              Center(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 50,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    // Use single selected user id
                                    final selectedUser = _selectedUserId;

                                    // Check if user is selected
                                    if (selectedUser == null ||
                                        selectedUser.isEmpty) {
                                      FlushBar.show(
                                        context,
                                        "Please select a user to chat with.",
                                        isSuccess: false,
                                      );
                                      return;
                                    }

                                    // Check if msg is not empty
                                    if (_chatMessage.text.isEmpty) {
                                      FlushBar.show(
                                        context,
                                        "Please enter the chat message.",
                                        isSuccess: false,
                                      );
                                      return;
                                    }

                                    try {
                                      futureLoading(context);

                                      // Call API with non-null String

                                      debugPrint(
                                        "the chat selected user on the create chat $selectedUser ",
                                      );
                                      final chatId =
                                          await ChatService.createIndividualChat(
                                            userId: selectedUser,
                                          );

                                      await ChatService.sendChatMessage(
                                        chatId: chatId,
                                        message: _chatMessage.text,
                                        attachments: [],
                                        replyFor: null,
                                      );

                                      _chatMessage.clear();
                                      setState(() {});

                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      Navigator.pop(context, true);
                                      FlushBar.show(context, "Chat created");
                                    } catch (e, st) {
                                      await ErrorService.recordError(e, st);
                                      debugPrint(
                                        "${e.toString()}, ${st.toString()}",
                                      );
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
                                  icon: Icon(
                                    Iconsax.message,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                  label: Text(
                                    "Create Chat",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // -------------------- Group Chat Tab (unchanged) --------------------
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create Group",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const Divider(),
                              // --- Group Name ---
                              Text(
                                "Group Name",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              FormFields(
                                controller: _groupName,
                                hintText: "Enter group name",
                              ),

                              const SizedBox(height: 20),

                              // --- Description ---
                              Text(
                                "Description",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              FormFields(
                                controller: _description,
                                hintText: "Enter group description",
                                maxLines: 3,
                              ),

                              const SizedBox(height: 20),

                              // --- Members Dropdown ---
                              Text(
                                "Add Members",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              FormMultiDropdowns(
                                isRequired: true,
                                items: _members
                                    .map<Object>((e) => e.name)
                                    .toList(),
                                onListChanged: (selectedList) {
                                  // Example: update selected members
                                  setState(() {
                                    _selectedMembers.clear();
                                    _selectedMembers.addAll(
                                      _members
                                          .where(
                                            (m) =>
                                                selectedList.contains(m.name),
                                          )
                                          .toList(),
                                    );
                                  });
                                },
                              ),

                              const SizedBox(height: 40),

                              Center(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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

                                      var sessionUser = await Spdb.getUser();

                                      final creatorName = sessionUser.name;
                                      final creatorUid = sessionUser.uid;

                                      // ✅ Step 1: Collect selected members
                                      List<String> participants =
                                          _selectedMembers
                                              .map<String>(
                                                (e) => e.uid ?? e.id ?? '',
                                              )
                                              .toList();

                                      // ✅ Step 2: Add creator if not already added
                                      if (!participants.contains(creatorUid)) {
                                        participants.add(creatorUid);
                                      }

                                      // ✅ Step 3: Create participantsKey
                                      participants
                                          .sort(); // 🔥 important for consistency
                                      final participantsKey = participants.join(
                                        '_',
                                      );

                                      ChatModel chatModel = ChatModel(
                                        createdBy: creatorUid,
                                        participants: participants,
                                        participantsKey: participantsKey,
                                        title: _groupName.text,
                                        description: _description.text,
                                        isGroupChat: true,
                                        isPinned: false,
                                        isFavorite: false,
                                        lastMessage: LastMessageModel(
                                          message: "$creatorName created group",
                                          timestamp: DateTime.now(),
                                          senderId: creatorUid,
                                        ),
                                      );

                                      await ChatService.createGroupChat(
                                        model: chatModel,
                                      );

                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      Navigator.pop(context, true);

                                      FlushBar.show(
                                        context,
                                        "Group chat created",
                                      );
                                    } catch (e, st) {
                                      await ErrorService.recordError(e, st);

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
                                  icon: Icon(
                                    Iconsax.messages_2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                  label: Text(
                                    "Create Group",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
