part of 'chat_messages.dart';

class ChatInputBar extends StatefulWidget {
  final ChatModel chat;
  final String? threadId;
  const ChatInputBar({super.key, required this.chat, this.threadId});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final List<PlatformFile> _pickedFiles = [];
  bool _showMentionList = false;
  List<MentionModel> _allUsers = [];
  List<MentionModel> _filteredUsers = [];
  bool get hasText => _controller.text.trim().isNotEmpty;
  final List<MentionModel> _mentions = [];
  String getExt(String path) {
    return path.split('?').first.split('#').first.split('.').last.toLowerCase();
  }

  String _getMimeType(String ext) {
    ext = ext.toLowerCase();
    if (imageExtensions.contains(ext)) return 'image/$ext';
    if (videoExtensions.contains(ext)) return 'video/$ext';
    if (audioExtensions.contains(ext)) return 'audio/$ext';

    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      withData: kIsWeb,
      allowedExtensions: [
        'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'tiff', // images
        'mp4', 'mov', 'avi', 'mkv', 'webm', // videos
        'mp3', 'wav', 'aac', // audio
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', // documents
      ],
    );

    if (files != null && files.files.isNotEmpty) {
      setState(() {
        _pickedFiles.addAll(files.files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  MessageProvider? _messageProvider;
  bool _isReply = false;
  bool _isEdit = false;
  bool _isRecording = false;
  MessagesModel? _chat;
  // String? replyForName;
  // String? replyForAvatar;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (!HardwareKeyboard.instance.isShiftPressed) {
            _sendMessage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
    _loadUsers();
    _controller.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageProvider = Provider.of<MessageProvider>(context, listen: false);
      _messageProvider?.addListener(_onMessageProviderChange);
    });
  }

  Future<void> _loadUsers() async {
    if (!widget.chat.isGroupChat) return;
    final participants = widget.chat.participants;
    final currentUid = await Spdb.getUid();

    List<MentionModel> users = [];

    for (var uid in participants) {
      if (uid == currentUid) continue;

      final user = CacheService.getUserByUid(uid);

      if (user is EmployeeModel) {
        users.add(
          MentionModel(
            uid: user.uid ?? '',
            name: user.name,
            image: user.profileImageUrl,
          ),
        );
      } else if (user is AdminModel) {
        users.add(
          MentionModel(
            uid: user.uid ?? '',
            name: user.name,
            image: user.profileImageUrl,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      debugPrint("Mention users: ${_allUsers.map((e) => e.name)}");
    });
  }

  void _onMessageProviderChange() {
    if (!mounted) return;

    setState(() {
      _isReply = _messageProvider?.isReply ?? false;
      _isEdit = _messageProvider?.isEdit ?? false;
      _isRecording = _messageProvider?.isRecording ?? false;
      _chat = _messageProvider?.chat;
    });

    if (_isEdit && _chat != null) {
      // Wait until the widget is ready before updating controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.value = TextEditingValue(
          text: _chat?.message ?? '',
          selection: TextSelection.collapsed(
            offset: _chat?.message.length ?? 0,
          ),
        );
      });
    }
  }

  void _onTextChanged() {
    if (!widget.chat.isGroupChat) return;
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0) return;

    final subText = text.substring(0, cursorPos);
    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]*)$').firstMatch(subText);

    _mentions.removeWhere((m) => !text.contains('@${m.name}'));

    if (match != null) {
      final query = match.group(1)?.toLowerCase() ?? '';

      setState(() {
        _showMentionList = true;
        _filteredUsers = _allUsers.where((user) {
          return user.name.toLowerCase().contains(query);
        }).toList();
      });
    } else {
      setState(() {
        _showMentionList = false;
      });
    }
  }

  void _selectMention(MentionModel user) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final subText = text.substring(0, cursorPos);

    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]*)$').firstMatch(subText);

    if (match != null) {
      final mentionStart = match.start + (subText[match.start] == ' ' ? 1 : 0);

      final mentionText = '@${user.name} ';
      final end = mentionStart + mentionText.length;

      final newText = text.replaceRange(mentionStart, cursorPos, mentionText);

      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: end);

      // Remove duplicate mention
      _mentions.removeWhere((m) => m.uid == user.uid);

      _mentions.add(
        MentionModel(
          uid: user.uid,
          name: user.name,
          start: mentionStart,
          end: end,
        ),
      );

      setState(() {
        _showMentionList = false;
      });
    }
  }

  Future<List<FileModel>> _uploadFiles(List<PlatformFile> files) async {
    List<FileModel> uploadedFiles = [];

    for (final pf in files) {
      final fileName = pf.name;
      final ext = fileName.split('.').last.toLowerCase();
      final size = pf.size;

      final String url;
      if (kIsWeb) {
        url = await StorageService.uploadBytes(
          bytes: pf.bytes!,
          fileName: fileName,
          folder: StorageFolder.chats,
        );
      } else {
        url = await StorageService.uploadFile(
          file: File(pf.path!),
          folder: StorageFolder.chats,
        );
      }

      uploadedFiles.add(
        FileModel(
          url: url,
          name: fileName,
          size: (size / 1024).round(),
          extension: ext,
          mimeType: _getMimeType(ext),
          createdAt: DateTime.now(),
        ),
      );
    }
    return uploadedFiles;
  }

  @override
  void dispose() {
    _messageProvider?.removeListener(_onMessageProviderChange);
    _controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Timer? _timer;

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _startRecording() async {
    var messageProvider = Provider.of<MessageProvider>(context, listen: false);
    messageProvider.startRecording();
    await AudioRecorder.startRecording();
    _startTimer();
  }

  void _stopRecording() async {
    var messageProvider = Provider.of<MessageProvider>(context, listen: false);
    messageProvider.stopRecording();
    var output = await AudioRecorder.stopRecording();
    if (output != null && output.isNotEmpty) {
      // Audio recorder returns a file path (native) or blob URL (web)
      // Wrap as PlatformFile so _uploadFiles handles it uniformly
      if (!kIsWeb) {
        _pickedFiles.add(PlatformFile(
          name: 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
          size: 0,
          path: output,
        ));
      }
      // Web blob URL audio upload not supported yet — skip silently
    }
    _stopTimer();
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  late final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final chatData = ChatData.of(context);
    final currentUser = chatData.currentUser;
    final canPost = widget.chat.canPostMessage(currentUser);

    if (!canPost) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              "Only administrators can post in this channel.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
          if (_isReply) _replyMessage(_chat, context, _messageProvider),
          if (_isEdit) _editMessage(_chat, context, _messageProvider),
          if (_isRecording) _recording(),
          if (_pickedFiles.isNotEmpty) _pickedFilesView(),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  // var result = await Sheet.showSheet(context,
                  //     widget: const PickOption(uploadDoc: true), size: 0.3);
                  // if (result != null) {
                  //   if (result == 1) {
                  //     var image = await PickImage.captureImage();
                  //     if (image != null) {
                  //       _pickedFiles.add(image);
                  //       setState(() {});
                  //     }
                  //   } else if (result == 2) {
                  //     var images = await PickImage.pickMultipleImages();
                  //     if (images.isNotEmpty) {
                  //       _pickedFiles.addAll(images);
                  //       setState(() {});
                  //     }
                  //   } else {
                  var files = await FilePick.pickFiles(context);
                  if (files != null) {
                    if (files.isNotEmpty) {
                      _pickedFiles.addAll(files);
                      setState(() {});
                    }
                  }
                  //   }
                  // }
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showMentionList && widget.chat.isGroupChat)
                      _mentionList(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 5,
                        onChanged: (value) async {
                          setState(() {});
                          // if (value.isNotEmpty) {
                          //   await ChatService.updateTypingOnChat(
                          //     chatId: uid,
                          //     status: true,
                          //   );
                          // } else {
                          //   await ChatService.updateTypingOnChat(
                          //     chatId: uid,
                          //     status: false,
                          //   );
                          // }
                        },
                        onEditingComplete: () async {
                          // await ChatService.updateTypingOnChat(
                          //   chatId: uid,
                          //   status: false,
                          // );
                        },
                        onTapOutside: (event) async {
                          // await ChatService.updateTypingOnChat(
                          //   chatId: uid,
                          //   status: false,
                          // );
                        },
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          hintText: "Send a message...",
                          border: InputBorder.none,
                          filled: true,
                          fillColor: AppColors.transparent,
                          suffixIcon: !hasText && _pickedFiles.isEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.image_outlined),
                                  onPressed: _pickFiles,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasText && _pickedFiles.isEmpty) ...[
                if (kIsMobile) ...[
                  if (!_isRecording) ...[
                    IconButton(
                      icon: const Icon(Icons.mic_rounded),
                      onPressed: _startRecording,
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.stop_rounded),
                      onPressed: _stopRecording,
                    ),
                  ],
                ],
              ] else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Iconsax.send_2,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 18,
                    ),
                    onPressed: () async => await _sendMessage(),
                  ),
                ),
            ],
          ),
        ],
      );
  }

  List<MentionModel> _recalculateMentions(String text) {
    List<MentionModel> updated = [];

    for (final m in _mentions) {
      final index = text.indexOf('@${m.name}');
      if (index != -1) {
        updated.add(
          MentionModel(
            uid: m.uid,
            name: m.name,
            start: index,
            end: index + m.name.length + 1,
          ),
        );
      }
    }

    return updated;
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;

    final chatData = ChatData.of(context);
    final uid = chatData.uid;

    final message = _controller.text.trim();

    if (_pickedFiles.isEmpty && message.isEmpty) return;

    // Store local copies BEFORE clearing UI
    final pickedFiles = List<PlatformFile>.from(_pickedFiles);

    final updatedMentions = widget.chat.isGroupChat
        ? _recalculateMentions(message)
        : <MentionModel>[];

    final replyId = _isReply ? _chat?.uid : null;

    // 🚀 INSTANT UI CLEAR
    _controller.clear();
    _pickedFiles.clear();
    _mentions.clear();

    _messageProvider?.clearMessage();

    if (mounted) {
      setState(() {});
    }

    try {
      List<FileModel> attachments = [];

      // Upload only if files exist
      if (pickedFiles.isNotEmpty) {
        attachments = await _uploadFiles(pickedFiles);
      }

      if (_isEdit) {
        await ChatService.editChatMessage(
          uid: uid,
          chatId: _chat?.uid ?? '',
          message: message,
          attachments: attachments,
        );
      } else {
        await ChatService.sendChatMessage(
          chatId: uid,
          message: message,
          attachments: attachments,
          replyFor: replyId,
          mentions: updatedMentions,
          threadId: widget.threadId,
        );
      }

      ChatService.sendNotification(chatId: uid, message: message, isChat: true);
    } catch (e) {
      debugPrint("Send message error: $e");
    }
  }

  final imageExtensions = ["png", "jpg", "jpeg", "webp", "bmp", "gif", "tiff"];
  final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
  final audioExtensions = ['mp3', 'wav', 'aac'];
  final docExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];

  Padding _pickedFilesView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 110,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_pickedFiles.length, (index) {
              final pf = _pickedFiles[index];
              final ext = pf.name.split('.').last.toLowerCase();
              return Stack(
                children: [
                  _buildFilePreview(pf, ext),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _removeFile(index),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.5),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile pf, String ext) {
    const size = 100.0;

    if (["jpg", "jpeg", "png", "gif", "webp"].contains(ext)) {
      ImageProvider imageProvider;
      if (kIsWeb && pf.bytes != null) {
        imageProvider = MemoryImage(pf.bytes!);
      } else {
        imageProvider = FileImage(File(pf.path!));
      }
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      );
    }

    if (["mp4", "mov", "avi", "mkv"].contains(ext)) {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black,
        ),
        child: const Icon(Icons.videocam, color: Colors.white),
      );
    }

    if (["mp3", "aac", "wav", "m4a"].contains(ext)) {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: const Icon(Icons.audiotrack, color: Colors.white),
      );
    }

    if (ext == "pdf") {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.errorContainer,
        ),
        child: const Icon(Icons.picture_as_pdf, size: 40, color: Colors.white),
      );
    }

    if (["doc", "docx"].contains(ext)) {
      return _iconPreview(size, Colors.blue, Icons.description, ext);
    }

    if (["xls", "xlsx"].contains(ext)) {
      return _iconPreview(size, Colors.green, Icons.table_chart, ext);
    }

    if (["ppt", "pptx"].contains(ext)) {
      return _iconPreview(size, Colors.deepOrange, Icons.slideshow, ext);
    }

    if (["zip", "rar", "7z"].contains(ext)) {
      return _iconPreview(size, Colors.grey, Icons.archive, ext);
    }

    if (["txt", "csv", "json"].contains(ext)) {
      return _iconPreview(size, Colors.brown, Icons.notes, ext);
    }

    return _iconPreview(size, Colors.black45, Icons.insert_drive_file, ext);
  }

  Widget _iconPreview(double size, Color color, IconData icon, String ext) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 4),
            Text(
              ext.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Padding _replyMessage(
    MessagesModel? chat,
    BuildContext context,
    MessageProvider? messageProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.1),
                offset: const Offset(0, -3),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
            color: Theme.of(context).cardTheme.color,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar
                          ((CacheService.getUserByUid(
                                        chat?.senderId ?? '',
                                      )?.profileImageUrl) !=
                                      null &&
                                  (CacheService.getUserByUid(
                                    chat?.senderId ?? '',
                                  )?.profileImageUrl)!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: CachedNetworkImage(
                                    imageUrl: (CacheService.getUserByUid(
                                      chat?.senderId ?? '',
                                    )?.profileImageUrl)!,
                                    placeholder: (context, url) =>
                                        Shimmer.fromColors(
                                          baseColor: AppColors.grey300,
                                          highlightColor: AppColors.grey100,
                                          child: Container(
                                            color: Theme.of(
                                              context,
                                            ).cardTheme.color,
                                          ),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                    height: 20,
                                    width: 20,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child:
                                      ((CacheService.getUserByUid(
                                                chat?.senderId ?? '',
                                              )?.profileImageUrl) ==
                                              null ||
                                          (CacheService.getUserByUid(
                                            chat?.senderId ?? '',
                                          )?.profileImageUrl)!.isEmpty)
                                      ? const Icon(Iconsax.user, size: 12)
                                      : null,
                                ),

                          const SizedBox(width: 5),
                          // Name
                          Text(
                            CacheService.getUserByUid(
                                  chat?.senderId ?? '',
                                )?.name ??
                                '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Message with ellipsis
                      SizedBox(
                        width: double.infinity, // Force width constraint
                        child: Text(
                          chat?.message ?? '',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () =>
                      setState(() => messageProvider?.clearMessage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mentionList() {
    if (_filteredUsers.isEmpty) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          "No users found",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];

          return InkWell(
            onTap: () => _selectMention(user),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  /// Avatar
                  _buildMentionAvatar(user),

                  const SizedBox(width: 10),

                  /// Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _highlightName(user.name),
                        const SizedBox(height: 2),
                        Text(
                          "Tap to mention",
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  /// Optional icon
                  Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMentionAvatar(MentionModel user) {
    if (user.image != null && user.image!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: CachedNetworkImage(
          imageUrl: user.image!,
          height: 36,
          width: 36,
          fit: BoxFit.cover,
          placeholder: (_, _) => CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, _, _) => _initialAvatar(user.name),
        ),
      );
    }

    return _initialAvatar(user.name);
  }

  Widget _initialAvatar(String name) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _highlightName(String name) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0) return Text(name);

    final subText = text.substring(0, cursorPos);
    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]*)$').firstMatch(subText);

    if (match == null) return Text(name);

    final query = match.group(1)?.toLowerCase() ?? '';

    if (query.isEmpty) {
      return Text(name, style: const TextStyle(fontWeight: FontWeight.w500));
    }

    final startIndex = name.toLowerCase().indexOf(query);

    if (startIndex == -1) {
      return Text(name);
    }

    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: name.substring(0, startIndex),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          TextSpan(
            text: name.substring(startIndex, endIndex),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: name.substring(endIndex),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Padding _editMessage(
    MessagesModel? chat,
    BuildContext context,
    MessageProvider? messageProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.1),
                offset: const Offset(0, -3),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
            color: Theme.of(context).cardTheme.color,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "You",
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Message with ellipsis
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          chat?.message ?? '',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () =>
                      setState(() => messageProvider?.clearMessage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Padding _recording() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.1),
                offset: const Offset(0, -3),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
            color: Theme.of(context).cardTheme.color,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Recording Audio",
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Timer display
                      SizedBox(
                        width: double.infinity, // Force width constraint
                        child: Text(
                          _formatDuration(_timer?.tick ?? 0),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}