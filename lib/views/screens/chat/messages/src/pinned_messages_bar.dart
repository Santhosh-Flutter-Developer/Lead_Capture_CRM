part of 'chat_messages.dart';

/// A fixed bar shown directly under the chat app bar, similar to Bitrix24's
/// "Pinned messages" bar. It always stays visible while there is at least
/// one pinned message in the chat (the message itself is NOT removed from
/// the normal message flow - it still shows inline with a "Pinned" tag).
///
/// - Shows the current pinned message (sender + preview).
/// - If there is more than one pinned message, shows a "n/total" counter
///   with chevrons to step through them.
/// - Tapping the bar scrolls the chat to that exact message and briefly
///   highlights it.
/// - The close icon unpins the currently shown message.
class PinnedMessagesBar extends StatefulWidget {
  final List<MessagesModel> pinnedMessages;
  final ValueChanged<String> onTapMessage;

  const PinnedMessagesBar({
    super.key,
    required this.pinnedMessages,
    required this.onTapMessage,
  });

  @override
  State<PinnedMessagesBar> createState() => _PinnedMessagesBarState();
}

class _PinnedMessagesBarState extends State<PinnedMessagesBar> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant PinnedMessagesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinnedMessages.isEmpty) {
      _index = 0;
    } else if (_index >= widget.pinnedMessages.length) {
      _index = widget.pinnedMessages.length - 1;
    }
  }

  Future<void> _unpin(MessagesModel message) async {
    final chatData = ChatData.of(context);
    if (message.uid == null) return;
    await ChatService.togglePin(
      chatId: chatData.uid,
      messageId: message.uid!,
      value: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pinnedMessages.isEmpty) return const SizedBox.shrink();

    final count = widget.pinnedMessages.length;
    final safeIndex = _index.clamp(0, count - 1);
    final message = widget.pinnedMessages[safeIndex];

    final senderName =
        CacheService.getUserByUid(message.senderId)?.name ?? 'User';
    final preview = message.message.isNotEmpty
        ? message.message
        : (message.attachments.isNotEmpty ? 'Attachment' : '');

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () {
          if (message.uid != null) widget.onTapMessage(message.uid!);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.push_pin, size: 16, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Pinned message",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      "$senderName: $preview",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (count > 1) ...[
                Text(
                  "${safeIndex + 1}/$count",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Previous pinned message',
                  onPressed: () {
                    setState(() {
                      _index = (safeIndex - 1 + count) % count;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Next pinned message',
                  onPressed: () {
                    setState(() {
                      _index = (safeIndex + 1) % count;
                    });
                  },
                ),
              ],
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Unpin',
                onPressed: () => _unpin(message),
              ),
            ],
          ),
        ),
      ),
    );
  }
}