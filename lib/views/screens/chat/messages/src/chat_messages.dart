import 'dart:async';
import 'dart:io' show File, Platform; // used in non-web branches only
import 'package:flutter/foundation.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icon.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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

  @override
  void initState() {
    super.initState();

    _stream = ChatService.getChatMessagesStream(
      uid: widget.chat.uid ?? '',
    ).asBroadcastStream();

    // This subscription handles the *side-effect* of marking messages as seen.
    // It does NOT call setState or manage UI data.
    _subscription = _stream.listen(_markMessagesAsSeen);
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
          // Don't mutate the message object - let the stream update naturally
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ChatData(
      uid: widget.chat.uid ?? '',
      currentUser: widget.currentUser,
      isGroupChat: widget.chat.isGroupChat,
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
            // The StreamBuilder is now the *only* thing responsible for UI data
            child: StreamBuilder<List<MessagesModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const WaitingLoading();
                } else if (snapshot.hasError) {
                  return ErrorDisplay(error: snapshot.error.toString());
                }

                final allChats = snapshot.data ?? [];

                final chats = _searchQuery.isEmpty
                    ? allChats
                    : allChats.where((msg) {
                        final text = (msg.message).toLowerCase();

                        return text.contains(_searchQuery.toLowerCase());
                      }).toList();
                return Column(
                  children: [
                    Expanded(
                      // Pass the raw list to BuildSliverChat
                      child: BuildSliverChat(
                        chats: chats,
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
  const BuildSliverChat({
    super.key,
    required this.chats,
    this.searchQuery = '',
    this.onOpenChat,
  });

  @override
  State<BuildSliverChat> createState() => _BuildSliverChatState();
}

class _BuildSliverChatState extends State<BuildSliverChat> {
  final ScrollController _scrollController = ScrollController();
  bool _showGoToBottomButton = false;

  @override
  void initState() {
    _scrollController.addListener(() {
      // Show "Go to Bottom" if not already at the bottom (i.e. pixels > 50)
      if (_scrollController.offset > 50 && !_showGoToBottomButton) {
        setState(() {
          _showGoToBottomButton = true;
        });
      }
      // Hide it when near the bottom
      else if (_scrollController.offset <= 50 && _showGoToBottomButton) {
        setState(() {
          _showGoToBottomButton = false;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    if (pinned.isNotEmpty) {
      slivers.insert(
        0,
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
              // The 'isLast' logic seems to be for seenBy.
              // Note: This logic assumes chats are sorted newest-to-oldest per day.
              // If they are sorted oldest-to-newest, this should be `index == chats.length - 1`.
              // Based on `reverse: true` in CustomScrollView, assuming 0 is the *newest*.
              isLast: message.senderId == currentUser && index == 0,
              onOpenChat: widget.onOpenChat,
            );
          }, childCount: chats.length),
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
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
                  _scrollController.animateTo(
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
