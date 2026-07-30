part of 'chat_messages.dart';

class ChatBubble extends StatefulWidget {
  final String chatUid;
  final MessagesModel message;
  final bool isSender;
  final bool isLast;
  final bool isPinned;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;

  const ChatBubble({
    super.key,
    required this.chatUid,
    required this.message,
    required this.isSender,
    this.isLast = false,
    this.isPinned = false,
    this.onOpenChat,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  Offset _slideOffset = Offset.zero;
  bool _showSlideIcon = false;

  // Overlay & Hover Logic
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  Timer? _hoverTimer;
  bool _isMenuHovered = false;
  bool _isBubbleHovered = false;
  bool _isPopupOpen = false;

  late bool _isPinned;
  late MessagesModel _msg;
  MessagesModel? _replyChat;

  @override
  void initState() {
    super.initState();
    _msg = widget.message;
    _isPinned = _msg.isPinned;
    _initReplyMessage();
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _msg = widget.message;
      _isPinned = _msg.isPinned;
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _initReplyMessage() async {
    if (_msg.replyFor != null) {
      final message = await ChatService.getChatMessage(
        chatId: widget.chatUid,
        messageId: _msg.replyFor!,
      );
      if (mounted) setState(() => _replyChat = message);
    }
  }

  // --- Hover Logic with Delay ---

  void _onEnterBubble() {
    _isBubbleHovered = true;
    _showMenu();
  }

  void _onExitBubble() {
    _isBubbleHovered = false;
    _startHideTimer();
  }

  void _onEnterMenu() {
    _isMenuHovered = true;
    _showMenu(); // Cancel any hide timer
  }

  void _onExitMenu() {
    _isMenuHovered = false;
    _startHideTimer();
  }

  void _showMenu() {
    _hoverTimer?.cancel();
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  void _startHideTimer() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 150), () {
      // FIX: Don't hide if the popup menu is currently open
      if (!_isBubbleHovered && !_isMenuHovered && !_isPopupOpen && mounted) {
        _overlayController.hide();
      }
    });
  }

  // --- Gestures ---

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    double dx = details.primaryDelta!;
    setState(() {
      if (widget.isSender && dx < 0) {
        _slideOffset = Offset((_slideOffset.dx + dx).clamp(-60, 0), 0);
        _showSlideIcon = true;
      } else if (!widget.isSender && dx > 0) {
        _slideOffset = Offset((_slideOffset.dx + dx).clamp(0, 60), 0);
        _showSlideIcon = true;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final threshold = widget.isSender
        ? _slideOffset.dx <= -40
        : _slideOffset.dx >= 40;
    if (threshold) _triggerSwipeAction();
    setState(() {
      _slideOffset = Offset.zero;
      _showSlideIcon = false;
    });
  }

  void _triggerSwipeAction() {
    Provider.of<MessageProvider>(context, listen: false).replyMessage(_msg);
  }

  void _onDoubleTap() {
    _addReaction("❤️");
  }

  void _addReaction(String emoji) async {
    // Optimistic UI update could be added here
    final uid = await Spdb.getUid();
    if (uid == null) return;

    if (mounted) {
      _isMenuHovered = false;
      _overlayController.hide();
    }

    await ChatService.toggleReaction(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
      emoji: emoji,
      userId: uid,
    );

    final updated = await ChatService.getChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );
    if (mounted) setState(() => _msg = updated);
  }

  void _pinMessage() async {
    _overlayController.hide();
    await ChatService.togglePin(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
      value: !_isPinned,
    );
    final updated = await ChatService.getChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );
    if (mounted) {
      setState(() {
        _msg = updated;
        _isPinned = updated.isPinned;
      });
    }
  }

  void _handleDeleteMessage() async {
    _overlayController.hide();
    final confirm = await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) =>
          const ConfirmDialog(title: "Delete", content: "Delete this message?"),
    );
    if (confirm != true) return;
    await ChatService.deleteChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );
  }

  void _showMobileChatOptions() async {
    if (!kIsMobile) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Sheet.showSheet(
      context,
      widget: ChatOptions(delete: widget.isSender, edit: widget.isSender),
      size: 0.4,
    );

    if (result != null && mounted) {
      final provider = Provider.of<MessageProvider>(context, listen: false);
      if (result == 1) provider.editMessage(_msg);
      if (result == 2) _handleDeleteMessage();
      if (result == 3) provider.replyMessage(_msg);
      if (result == 4) Clipboard.setData(ClipboardData(text: _msg.message));
    }
  }

  void _onReactionTap(String emoji) async {
    final uid = await Spdb.getUid();
    if (uid == null) return;

    await ChatService.toggleReaction(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
      emoji: emoji,
      userId: uid,
    );

    final updated = await ChatService.getChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );

    if (mounted) setState(() => _msg = updated);
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (BuildContext context) {
            return CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: widget.isSender
                  ? Alignment.topRight
                  : Alignment.topLeft,
              followerAnchor: widget.isSender
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              offset: const Offset(0, -6),
              child: Align(
                alignment: widget.isSender
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: MouseRegion(
                  onEnter: (_) => _onEnterMenu(),
                  onExit: (_) => _onExitMenu(),
                  child: _ChatBubbleHoverMenu(
                    isSender: widget.isSender,
                    onReaction: _addReaction,
                    onMenuStateChanged: (isOpen) {
                      _isPopupOpen = isOpen;
                      // If closing, check if we need to hide the overlay
                      if (!isOpen) {
                        _startHideTimer();
                      }
                    },
                    actions: {
                      "reply": () {
                        _overlayController.hide();
                        messageProvider.replyMessage(_msg);
                      },
                      "copy": () {
                        _overlayController.hide();
                        Clipboard.setData(ClipboardData(text: _msg.message));
                      },
                      "pin": _pinMessage,
                      if (widget.isSender)
                        "edit": () {
                          _overlayController.hide();
                          messageProvider.editMessage(_msg);
                        },

                      if (widget.isSender) "delete": _handleDeleteMessage,
                    },
                  ),
                ),
              ),
            );
          },
          child: MouseRegion(
            onEnter: (_) {
              if (!kIsMobile) _onEnterBubble();
            },
            onExit: (_) {
              if (!kIsMobile) _onExitBubble();
            },
            child: GestureDetector(
              onDoubleTap: _onDoubleTap,
              onLongPress: () {
                if (kIsMobile) {
                  _onEnterMenu();
                }
              },
              onLongPressCancel: () {
                if (kIsMobile) {
                  _onExitMenu();
                }
              },
              child: _ChatBubbleCore(
                slideOffset: _slideOffset,
                showSlideIcon: _showSlideIcon,
                isSender: widget.isSender,
                message: _msg,
                replyChat: _replyChat,
                isLast: widget.isLast,
                isPinned: _isPinned,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                onLongPress: _showMobileChatOptions,
                onReactionTap: _onReactionTap,
                onOpenChat: widget.onOpenChat,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubbleCore extends StatelessWidget {
  final Offset slideOffset;
  final bool showSlideIcon;
  final bool isSender;
  final MessagesModel message;
  final MessagesModel? replyChat;
  final bool isLast;
  final bool isPinned;
  final ValueChanged<DragUpdateDetails> onHorizontalDragUpdate;
  final ValueChanged<DragEndDetails> onHorizontalDragEnd;
  final VoidCallback onLongPress;
  final Function(String)? onReactionTap;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;

  const _ChatBubbleCore({
    required this.slideOffset,
    required this.showSlideIcon,
    required this.isSender,
    required this.message,
    required this.replyChat,
    required this.isLast,
    required this.isPinned,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
    required this.onLongPress,
    this.onReactionTap,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final chatData = ChatData.of(context);
    final isGroupChat = chatData.isGroupChat;
    return Transform.translate(
      offset: slideOffset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (showSlideIcon)
            Positioned.fill(
              child: Align(
                alignment: isSender
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    Icons.reply,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: isSender
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 12, color: AppColors.orange),
                      SizedBox(width: 4),
                      Text(
                        "Pinned",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              if ((!isSender && isLast) || (isGroupChat && !isSender)) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    CacheService.adminByUid(message.senderId)?.name ?? 'User',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isSender) ...[
                    _ChatBubbleSenderAvatar(senderId: message.senderId),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: isSender
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _ChatBubbleMessageBox(
                          isSender: isSender,
                          message: message,
                          replyChat: replyChat,
                          onOpenChat: onOpenChat,
                        ),
                        if (message.reactions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: _ReactionChips(
                              reactions: message.reactions,
                              isSender: isSender,
                              onTap: onReactionTap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(message.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    if (isSender) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.seenBy.isNotEmpty ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.seenBy.isNotEmpty
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatBubbleMessageBox extends StatefulWidget {
  final bool isSender;
  final MessagesModel message;
  final MessagesModel? replyChat;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;

  const _ChatBubbleMessageBox({
    required this.isSender,
    required this.message,
    required this.replyChat,
    this.onOpenChat,
  });

  @override
  State<_ChatBubbleMessageBox> createState() => _ChatBubbleMessageBoxState();
}

class _ChatBubbleMessageBoxState extends State<_ChatBubbleMessageBox> {
  Timer? hoverTimer;

  @override
  void dispose() {
    hoverTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  Future<void> _openChat(BuildContext context, MentionModel mention) async {
    final cid = await Spdb.getCid();
    final uid = await Spdb.getUid();
    final opponentUid = mention.uid;

    if (uid == null) return;

    String? chatId = await ChatService.getChatUid(opponentUid);

    chatId ??= await ChatService.createIndividualChat(userId: opponentUid);

    final doc = await FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .get();

    if (!doc.exists) return;

    final chat = ChatModel.fromMap(doc.id, doc.data()!);

    // 🔹 Step 4: Navigate
    if (!kIsMobile && widget.onOpenChat != null) {
      widget.onOpenChat!(chat, opponentUid);
      return;
    }

    Navigate.route(
      context,
      ChatMessages(chat: chat, currentUser: uid, opponentUid: opponentUid),
    );
  }

  OverlayEntry? _overlayEntry;

  // void _showProfileOverlay(
  //   BuildContext context,
  //   Offset globalPosition,
  //   MentionModel mention,
  // ) {
  //   _hideProfileOverlay(); // prevent stacking

  //   final user = CacheService.adminByUid(mention.uid);
  //   if (user == null) return;

  //   final overlay = Overlay.of(context);
  //   final renderBox = overlay.context.findRenderObject() as RenderBox;

  //   final localOffset = renderBox.globalToLocal(globalPosition);

  //   final screenWidth = MediaQuery.of(context).size.width;
  //   final left = (localOffset.dx.clamp(10, screenWidth - 220)).toDouble();
  //   _overlayEntry = OverlayEntry(
  //     builder: (context) => Positioned(
  //       left: left,
  //       top: localOffset.dy + 20,
  //       child: Material(
  //         color: Colors.transparent,
  //         child: Container(
  //           constraints: const BoxConstraints(maxWidth: 200),
  //           padding: const EdgeInsets.all(8),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.circular(10),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withValues(alpha: 0.15),
  //                 blurRadius: 10,
  //               ),
  //             ],
  //           ),
  //           child: CreatedByWidget(userData: user),
  //         ),
  //       ),
  //     ),
  //   );
  //   overlay.insert(_overlayEntry!);
  // }

  void _hideProfileOverlay() {
    hoverTimer?.cancel();
    hoverTimer = Timer(const Duration(milliseconds: 150), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s\)\]\}]+)');
    final match = urlRegex.firstMatch(widget.message.message);
    final url = match?.group(0);

    return Column(
      crossAxisAlignment: widget.isSender
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (widget.message.message.isNotEmpty)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSender
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: widget.isSender
                    ? const Radius.circular(16)
                    : const Radius.circular(4),
                bottomRight: widget.isSender
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
              boxShadow: [
                if (!widget.isSender)
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.replyChat != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CacheService.adminByUid(
                                widget.replyChat!.senderId,
                              )?.name ??
                              'User',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyChat!.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                _buildMessageWithMentions(context, widget.message.message),
              ],
            ),
          ),

        // --- Attachment / URL Preview ---
        if (url != null && widget.message.attachments.isEmpty) ...[
          UrlPreview(url: url, isSender: widget.isSender),
        ] else if (widget.message.attachments.isNotEmpty) ...[
          AttachmentPreview(attachments: widget.message.attachments),
        ],
      ],
    );
  }

  Widget _buildMessageWithMentions(BuildContext context, String text) {
    final mentions = widget.message.mentions ?? [];
    if (mentions.isEmpty) {
      return Text(text);
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    final sortedMentions = [...mentions]
      ..sort((a, b) => (a.start ?? 0).compareTo(b.start ?? 0));

    for (final mention in sortedMentions) {
      final start = mention.start;
      final end = mention.end;

      if (start == null || end == null) continue;

      if (start < 0 ||
          end < 0 ||
          start > text.length ||
          end > text.length ||
          start >= end) {
        continue;
      }

      // Normal text before mention
      if (currentIndex < start) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, start),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        );
      }

      String mentionText = text.substring(start, end);
      if (mentionText.startsWith('@')) {
        mentionText = mentionText.substring(1);
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Builder(
            builder: (context) {
              String mentionText = text.substring(start, end);

              if (mentionText.startsWith('@')) {
                mentionText = mentionText.substring(1);
              }

              return MouseRegion(
                onEnter: (event) {
                  hoverTimer?.cancel();
                },
                onExit: (event) {
                  _hideProfileOverlay();
                },
                child: GestureDetector(
                  onTap: () => _openChat(context, mention),

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mentionText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      currentIndex = end;
    }

    // Remaining text
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _ReactionChips extends StatefulWidget {
  final Map<String, List<String>> reactions;
  final bool isSender;
  final Function(String)? onTap;
  const _ReactionChips({
    required this.reactions,
    required this.isSender,
    this.onTap,
  });

  @override
  State<_ReactionChips> createState() => _ReactionChipsState();
}

class _ReactionChipsState extends State<_ReactionChips> {
  @override
  Widget build(BuildContext context) {
    // reactions = { "😂": ["u1","u2"], "❤️": ["u3"] }
    final counts = <String, int>{};

    for (var entry in widget.reactions.entries) {
      final emoji = entry.key;
      final users = entry.value;
      counts[emoji] = users.length; // number of reactions for that emoji
    }

    return Wrap(
      alignment: widget.isSender ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: counts.entries.map((entry) {
        return GestureDetector(
          onTap: () => widget.onTap?.call(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).cardTheme.color!,
                width: 2,
              ),
            ),
            child: Text(
              "${entry.key} ${entry.value > 1 ? entry.value : ''}",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChatBubbleHoverMenu extends StatefulWidget {
  final bool isSender;
  final Function(String) onReaction;
  final Map<String, VoidCallback> actions;
  final ValueChanged<bool>? onMenuStateChanged; // FIX: New callback

  const _ChatBubbleHoverMenu({
    required this.isSender,
    required this.onReaction,
    required this.actions,
    this.onMenuStateChanged, // FIX: New callback
  });

  @override
  State<_ChatBubbleHoverMenu> createState() => _ChatBubbleHoverMenuState();
}

class _ChatBubbleHoverMenuState extends State<_ChatBubbleHoverMenu> {
  @override
  Widget build(BuildContext context) {
    final emojis = ["👍", "❤️", "😂", "😮", "😢", "🔥"];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...emojis.map(
            (e) => _HoverEmoji(emoji: e, onTap: () => widget.onReaction(e)),
          ),
          Container(
            height: 20,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          _HoverIcon(icon: Icons.reply, onTap: widget.actions['reply']),
          _HoverIcon(
            icon: Icons.more_horiz,
            onTap: () {
              final RenderBox button = context.findRenderObject() as RenderBox;
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject() as RenderBox;

              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  button.localToGlobal(Offset.zero, ancestor: overlay),
                  button.localToGlobal(
                    button.size.bottomRight(Offset.zero),
                    ancestor: overlay,
                  ),
                ),
                Offset.zero & overlay.size,
              );

              // FIX: Notify parent that menu is open (prevents hide)
              widget.onMenuStateChanged?.call(true);

              showMenu(
                context: context,
                position: position,
                items: [
                  for (var i in widget.actions.keys)
                    PopupMenuItem(
                      value: i,
                      child: Text(
                        i.capitalizeFirst,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                ],
              ).then((value) {
                // FIX: Notify parent that menu is closed
                widget.onMenuStateChanged?.call(false);

                if (!mounted) return;
                if (value != null) {
                  widget.actions[value]!();
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

class _HoverEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _HoverEmoji({required this.emoji, required this.onTap});

  @override
  State<_HoverEmoji> createState() => _HoverEmojiState();
}

class _HoverEmojiState extends State<_HoverEmoji> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          // ignore: deprecated_member_use
          transform: Matrix4.identity()..scale(_hover ? 1.2 : 1.0),
          child: Text(
            widget.emoji,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _HoverIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HoverIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      splashRadius: 16,
      onPressed: onTap,
    );
  }
}

class _ChatBubbleSenderAvatar extends StatelessWidget {
  final String senderId;
  const _ChatBubbleSenderAvatar({required this.senderId});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 14,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
