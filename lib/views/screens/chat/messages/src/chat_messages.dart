import 'dart:async';
import 'dart:io' show File; // used in non-web branches only
import 'package:flutter/foundation.dart';
import 'package:leadcapture/utils/src/download_io.dart'
    if (dart.library.html) 'package:leadcapture/utils/src/download_web.dart'
    show saveFileToDownloads;
import 'package:any_link_preview/any_link_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:line_icons/line_icon.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';

part 'chat_data.dart';
part 'chat_bubble.dart';
part 'input_bar.dart';
part 'chat_options.dart';
part 'chat_top_bar.dart';
part 'utility.dart';

/// The main screen for displaying chat messages.
///
/// This widget sets up the stream for messages and handles the business logic
/// for marking messages as "seen" in the background.
class ChatMessages extends StatefulWidget {
  final ChatModel chat;
  final String currentUser;
  final String opponentUid;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;
  const ChatMessages({
    super.key,
    required this.chat,
    required this.currentUser,
    required this.opponentUid,
    this.onOpenChat,
  });

  @override
  State<ChatMessages> createState() => _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  late Stream<List<MessagesModel>> _stream;
  StreamSubscription<List<MessagesModel>>? _subscription;
  bool _isSearching = false;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  List<MessagesModel> _recentMessages = [];
  List<MessagesModel> _historicalMessages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    _stream = ChatService.getChatMessagesStream(
      uid: widget.chat.uid ?? '',
      limit: 30,
    ).asBroadcastStream();

    _subscription = _stream.listen((messages) {
      _markMessagesAsSeen(messages);
      if (mounted) {
        setState(() {
          _recentMessages = messages;
          _initialLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  List<MessagesModel> _getCombinedMessages() {
    final seenUids = <String>{};
    final List<MessagesModel> combined = [];

    for (var msg in _recentMessages) {
      if (msg.uid != null && seenUids.add(msg.uid!)) {
        combined.add(msg);
      }
    }
    for (var msg in _historicalMessages) {
      if (msg.uid != null && seenUids.add(msg.uid!)) {
        combined.add(msg);
      }
    }

    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return combined;
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    final combined = _getCombinedMessages();
    if (combined.isEmpty) {
      setState(() {
        _isLoadingMore = false;
      });
      return;
    }

    final oldestMessage = combined.last;
    try {
      final newPage = await ChatService.getChatMessagesPage(
        uid: widget.chat.uid ?? '',
        limit: 30,
        lastTimestamp: oldestMessage.timestamp,
      );

      if (newPage.length < 30) {
        _hasMore = false;
      }

      if (mounted) {
        setState(() {
          _historicalMessages.addAll(newPage);
          _isLoadingMore = false;
        });
      }
    } catch (e, st) {
      debugPrint("Error loading more messages: $e\n$st");
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// A background task to mark incoming messages as seen.
  void _markMessagesAsSeen(List<MessagesModel> messages) {
    Spdb.getUid().then((uid) async {
      if (uid == null) return;
      for (var msg in messages) {
        if (!msg.seenBy.contains(uid) && msg.senderId != widget.currentUser) {
          await ChatService.updateSeenChat(
            chatId: widget.chat.uid ?? '',
            messageId: msg.uid ?? '',
          );
          // This mutation is local-only to prevent re-triggering
          msg.seenBy.add(uid);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ChatData(
      uid: widget.chat.uid ?? '',
      currentUser: widget.currentUser,
      isGroupChat: widget.chat.isGroupChat,
      chat: widget.chat,
      child: Scaffold(
        appBar: kIsMobile || width < 1000
            ? ChatTopBar(
                userUid: widget.opponentUid,
                currentUserUid: widget.currentUser,
                lastSeen: DateTime.now().formatTime,
                chat: widget.chat,
                isSearching: _isSearching,

                onSearchChanged: (value) {
                  setState(() {
                    _isSearching = true;
                    _searchQuery = value;
                  });
                },

                onSearchClose: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                  });
                },
              )
            : ChatTopBarDesktop(
                userUid: widget.opponentUid,
                currentUserUid: widget.currentUser,
                lastSeen: DateTime.now().formatTime,
                chat: widget.chat,
                isSearching: _isSearching,

                onSearchChanged: (value) {
                  setState(() {
                    _isSearching = true;
                    _searchQuery = value;
                  });
                },

                onSearchClose: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                  });
                },
              ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: _initialLoading
                ? const WaitingLoading()
                : Builder(
                    builder: (context) {
                      final allChats = _getCombinedMessages();

                      final chats = _searchQuery.isEmpty
                          ? allChats
                          : allChats.where((msg) {
                              final text = (msg.message).toLowerCase();

                              return text.contains(_searchQuery.toLowerCase());
                            }).toList();
                      return Column(
                        children: [
                          Expanded(
                            child: BuildSliverChat(
                              chats: chats,
                              scrollController: _scrollController,
                              isLoadingMore: _isLoadingMore,
                              searchQuery: _searchQuery,
                              onOpenChat: widget.onOpenChat,
                            ),
                          ),
                          ChatInputBar(chat: widget.chat),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// This widget takes a flat list of messages, groups them by date,
/// and builds the reversible chat list with date separators.
class BuildSliverChat extends StatefulWidget {
  final List<MessagesModel> chats;
  final String searchQuery;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;
  final ScrollController scrollController;
  final bool isLoadingMore;

  const BuildSliverChat({
    super.key,
    required this.chats,
    required this.scrollController,
    required this.isLoadingMore,
    this.searchQuery = '',
    this.onOpenChat,
  });

  @override
  State<BuildSliverChat> createState() => _BuildSliverChatState();
}

class _BuildSliverChatState extends State<BuildSliverChat> {
  bool _showGoToBottomButton = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void didUpdateWidget(covariant BuildSliverChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scrollListener);
      widget.scrollController.addListener(_scrollListener);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (!mounted) return;
    // Show "Go to Bottom" if not already at the bottom (i.e. pixels > 50)
    if (widget.scrollController.offset > 50 && !_showGoToBottomButton) {
      setState(() {
        _showGoToBottomButton = true;
      });
    }
    // Hide it when near the bottom
    else if (widget.scrollController.offset <= 50 && _showGoToBottomButton) {
      setState(() {
        _showGoToBottomButton = false;
      });
    }
  }

  /// Groups a flat list of chats into a map keyed by date labels.
  Map<String, List<MessagesModel>> _groupChatsByDate(
    List<MessagesModel> chats,
  ) {
    Map<String, List<MessagesModel>> grouped = {};

    for (var chat in chats) {
      final date = chat.timestamp;
      final now = DateTime.now();
      String key;

      if (_isSameDate(date, now)) {
        key = 'Today';
      } else if (_isSameDate(date, now.subtract(const Duration(days: 1)))) {
        key = 'Yesterday';
      } else {
        key = DateFormat('MMM d, yyyy').format(date);
      }

      grouped.putIfAbsent(key, () => []).add(chat);
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final aDate = _parseDateKey(a.key);
        final bDate = _parseDateKey(b.key);
        return aDate.compareTo(bDate);
      });

    final sortedMap = <String, List<MessagesModel>>{};
    for (final entry in sortedEntries) {
      sortedMap[entry.key] = entry.value;
    }

    return sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    final chatData = ChatData.of(context);
    final uid = chatData.uid;
    final currentUser = chatData.currentUser;
    final pinned = widget.chats.where((m) => m.isPinned).toList();
    final normal = widget.chats.where((m) => !m.isPinned).toList();

    final groupedChats = _groupChatsByDate(normal);

    final List<Widget> slivers = [];

    // If we are loading more historical messages, show spinner at the top of scroll view
    // Since reverse: true is set, index 0 of slivers (before reverse) is the bottom of the array
    // which gets placed at the top of the viewport when reversed.
    if (widget.isLoadingMore) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    if (pinned.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Text(
                  "Pinned messages",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),

              ...pinned.map((msg) {
                return ChatBubble(
                  message: msg,
                  isPinned: true,
                  isSender: msg.senderId == currentUser,
                  chatUid: uid,
                  onOpenChat: widget.onOpenChat,
                );
              }),
            ],
          ),
        ),
      );
    }

    for (var entry in groupedChats.entries) {
      final dateLabel = entry.key;
      final chats = entry.value;

      slivers.add(
        SliverToBoxAdapter(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final message = chats[index];
            return ChatBubble(
              key: ValueKey(message.uid),
              chatUid: uid,
              message: message,
              isSender: message.senderId == currentUser,
              isLast: message.senderId == currentUser,
              onOpenChat: widget.onOpenChat,
            );
          }, childCount: chats.length),
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: widget.scrollController,
          reverse: true, // This makes the list start at the bottom
          slivers: slivers.reversed
              .toList(), // This reverses the *order of groups* (e.g., Today, Yesterday)
        ),
        if (_showGoToBottomButton)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  widget.scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                icon: Icon(
                  Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                label: Text(
                  "Go to Bottom",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- TOP-LEVEL HELPER FUNCTIONS ---

/// Checks if two DateTimes are on the same calendar day.
bool _isSameDate(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

/// Parses a date key ('Today', 'Yesterday', or 'MMM d, yyyy') into a DateTime.
DateTime _parseDateKey(String key) {
  final now = DateTime.now();
  if (key == 'Today') {
    return DateTime(now.year, now.month, now.day);
  } else if (key == 'Yesterday') {
    final yesterday = now.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day);
  } else {
    return DateFormat('MMM d, yyyy').parse(key);
  }
}

class ThreadSheet extends StatelessWidget {
  final MessagesModel parentMessage;
  final ChatModel chat;

  const ThreadSheet({
    super.key,
    required this.parentMessage,
    required this.chat,
  });

  static void show(BuildContext context, MessagesModel parentMessage, ChatModel chat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThreadSheet(parentMessage: parentMessage, chat: chat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.85,
      margin: EdgeInsets.only(top: 24, bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Iconsax.message_programming,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Thread Reply",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parentMessage.senderName ?? "User",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    parentMessage.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(),
            
            Expanded(
              child: StreamBuilder<List<MessagesModel>>(
                stream: ChatService.getThreadMessagesStream(
                  chatId: chat.uid ?? '',
                  parentMessageId: parentMessage.uid ?? '',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  final replies = snapshot.data ?? [];
                  if (replies.isEmpty) {
                    return Center(
                      child: Text(
                        "No replies yet. Be the first to reply!",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      final reply = replies[index];
                      final isSender = reply.senderId == parentMessage.senderId;
                      return ChatBubble(
                        chatUid: chat.uid ?? '',
                        message: reply,
                        isSender: isSender,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            
            ChatInputBar(
              chat: chat,
              threadId: parentMessage.uid,
            ),
          ],
        ),
      ),
    );
  }
}