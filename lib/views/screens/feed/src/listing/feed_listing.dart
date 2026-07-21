import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/theme/theme.dart';

part 'comment_sheet.dart';

// --- Unified Dashboard Palette ---
class FeedAppColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
}

class _CommentAuthorDisplay {
  final String name;
  final String avatar;

  const _CommentAuthorDisplay({required this.name, required this.avatar});
}

class FeedListing extends StatefulWidget {
  const FeedListing({super.key});

  @override
  State<FeedListing> createState() => _FeedListingState();
}

class _FeedListingState extends State<FeedListing> {
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    context.read<FeedBloc>().add(LoadFeeds());
  }

  Future<void> _loadCurrentUser() async {
    _currentUserUid = await Spdb.getUid();
    setState(() {});
  }

  void _refreshFeed() {
    context.read<FeedBloc>().add(RefreshFeeds());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final crossAxisCount = isDesktop
        ? 3
        : 2; // Pro dashboard often uses 3 on wide screens

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: kIsMobile
          ? AppBar(
              leading: Back(color: Theme.of(context).colorScheme.onSurface),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              centerTitle: false,
              title: Text(
                "Community Feed",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Iconsax.refresh,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: _refreshFeed,
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Theme.of(context).dividerColor,
                  height: 1,
                ),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        onPressed: () async {
          if (kIsMobile) {
            final result = await Sheet.showSheet(
              context,
              widget: const FeedCreate(),
            );
            if (result == true && mounted) {
              _refreshFeed();
            }
          } else {
            final result = await GeneralDialog.showRTLSheet(
              context,
              const FeedCreate(),
            );
            if (result == true && mounted) {
              _refreshFeed();
            }
          }
        },
        child: const Icon(Iconsax.add, color: Colors.white),
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading) {
            return const Center(child: WaitingLoading());
          }
          if (state is FeedError) return ErrorDisplay(error: state.message);

          if (state is FeedLoaded) {
            if (state.feeds.isEmpty) {
              return const Center(child: Text("No posts in the stream."));
            }

            return RefreshIndicator(
              onRefresh: () async => _refreshFeed(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          0.72, // Taller aspect ratio for Instagram-like feel with text
                    ),
                    itemCount: state.feeds.length,
                    itemBuilder: (context, index) {
                      return FeedCard(
                        key: ValueKey(state.feeds[index].uid),
                        feed: state.feeds[index],
                        currentUserUid: _currentUserUid,
                        onRefresh: _refreshFeed,
                      );
                    },
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class FeedCard extends StatefulWidget {
  final FeedModel feed;
  final String? currentUserUid;
  final VoidCallback onRefresh;

  const FeedCard({
    super.key,
    required this.feed,
    this.currentUserUid,
    required this.onRefresh,
  });

  @override
  State<FeedCard> createState() => FeedCardState();
}

class FeedCardState extends State<FeedCard> {
  int _currentImageIndex = 0;
  late bool _isLiked;
  late bool _isSaved;
  late int _likeCount;
  late String _postAuthorName;
  late String _postAuthorAvatar;

  int get _commentCount {
    final localCount = widget.feed.comments?.length ?? 0;
    if (localCount > 0) return localCount;
    return widget.feed.commentsCount;
  }

  Future<_CommentAuthorDisplay?> _loadCommentAuthorDisplay(String uid) async {
    final cachedUser = CacheService.getUserByUid(uid);
    if (cachedUser is EmployeeModel) {
      return _CommentAuthorDisplay(
        name: cachedUser.name,
        avatar: cachedUser.profileImageUrl ?? '',
      );
    }

    if (cachedUser is AdminModel) {
      return _CommentAuthorDisplay(
        name: cachedUser.name,
        avatar: cachedUser.profileImageUrl ?? '',
      );
    }

    final employee = await EmployeeService.getEmployee(uid: uid);
    if (employee != null) {
      return _CommentAuthorDisplay(
        name: employee.name,
        avatar: employee.profileImageUrl ?? '',
      );
    }

    final admin = await AdminService.getAdmin(uid: uid);
    if (admin != null) {
      return _CommentAuthorDisplay(
        name: admin.name,
        avatar: admin.profileImageUrl ?? '',
      );
    }

    return const _CommentAuthorDisplay(name: 'Unknown user', avatar: '');
  }

  Future<void> _loadPostAuthorDisplay() async {
    final display = await _loadCommentAuthorDisplay(widget.feed.authorId);
    if (!mounted || display == null) return;

    setState(() {
      _postAuthorName = display.name;
      _postAuthorAvatar = display.avatar;
    });
  }

  Future<Map<String, _CommentAuthorDisplay>> _loadCommentAuthors(
    List<CommentModel> comments,
  ) async {
    final result = <String, _CommentAuthorDisplay>{};
    final ids = comments
        .map((c) => c.authorId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();

    for (final id in ids) {
      final display = await _loadCommentAuthorDisplay(id);
      if (display != null) {
        result[id] = display;
      }
    }

    return result;
  }

  Future<void> _openUserProfileFromComment(String uid) async {
    if (uid.trim().isEmpty) return;

    final employee = await EmployeeService.getEmployee(uid: uid);
    if (employee != null) {
      if (!mounted) return;
      if (kIsMobile) {
        await Sheet.showSheet(
          context,
          widget: EmployeeDetails(employee: employee),
        );
      } else {
        await GeneralDialog.showRTLSheet(
          context,
          EmployeeDetails(employee: employee),
        );
      }
      return;
    }

    final admin = await AdminService.getAdmin(uid: uid);
    if (admin != null) {
      if (!mounted) return;
      if (kIsMobile) {
        await Sheet.showSheet(context, widget: AdminProfile(admin: admin));
      } else {
        await GeneralDialog.showRTLSheet(context, AdminProfile(admin: admin));
      }
      return;
    }

    if (!mounted) return;
    FlushBar.show(context, 'User profile not found', isSuccess: false);
  }

  Future<void> _openPostPreview({int initialImageIndex = 0}) async {
    final imageCount = widget.feed.mediaImages.length;
    final startIndex = imageCount == 0
        ? 0
        : initialImageIndex.clamp(0, imageCount - 1);

    String postAuthorName = widget.feed.authorName;
    String postAuthorAvatar = widget.feed.authorAvatar;
    Map<String, _CommentAuthorDisplay> commentAuthors = {};

    try {
      final postAuthorDisplay = await _loadCommentAuthorDisplay(
        widget.feed.authorId,
      );
      if (!mounted) return;
      postAuthorName = postAuthorDisplay?.name ?? widget.feed.authorName;
      postAuthorAvatar = postAuthorDisplay?.avatar ?? widget.feed.authorAvatar;
    } catch (_) {}

    final pollModel = widget.feed.poll == null
        ? null
        : PollModel(
            pollId: widget.feed.poll!.pollId,
            question: widget.feed.poll!.question,
            options: widget.feed.poll!.options
                .map(
                  (o) => PollOption(
                    optionId: o.optionId,
                    title: o.title,
                    votes: o.votes,
                  ),
                )
                .toList(),
            votedUserIds: List<String>.from(widget.feed.poll!.votedUserIds),
          );

    String? selectedOptionId;
    bool isVoting = false;
    int dialogImageIndex = startIndex;
    final List<CommentModel> dialogComments = List<CommentModel>.from(
      widget.feed.comments ?? const <CommentModel>[],
    );

    try {
      commentAuthors = await _loadCommentAuthors(dialogComments);
      if (!mounted) return;
    } catch (_) {}

    final TextEditingController dialogCommentController =
        TextEditingController();
    bool isPostingComment = false;
    final PageController dialogPageController = PageController(
      initialPage: startIndex,
    );

    if (!mounted) return;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final totalVotes = pollModel == null
                  ? 0
                  : pollModel.options.fold<int>(
                      0,
                      (sum, option) => sum + option.votes,
                    );
              final hasCurrentUserVoted =
                  widget.currentUserUid != null &&
                  pollModel != null &&
                  pollModel.votedUserIds.contains(widget.currentUserUid);

              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 820,
                    maxHeight: 900,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openUserProfileFromComment(
                                widget.feed.authorId,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: postAuthorAvatar.isNotEmpty
                                    ? postAuthorAvatar
                                    : AppStrings.emptyProfilePhotoUrl,
                                imageBuilder: (context, imageProvider) => CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  backgroundImage: imageProvider,
                                ),
                                errorWidget: (context, url, error) => CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  child: const Icon(Iconsax.danger, size: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => _openUserProfileFromComment(
                                      widget.feed.authorId,
                                    ),
                                    child: Text(
                                      postAuthorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _buildTimeLabel(widget.feed),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Images section
                      if (widget.feed.mediaImages.isNotEmpty)
                        SizedBox(
                          height: 420,
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: dialogPageController,
                                itemCount: widget.feed.mediaImages.length,
                                onPageChanged: (index) {
                                  setDialogState(() {
                                    dialogImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return Container(
                                    color: Colors.black,
                                    alignment: Alignment.center,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Image.network(
                                        widget.feed.mediaImages[index].url,
                                        fit: BoxFit.contain,
                                        height: 360,
                                        width: double.infinity,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (widget.feed.mediaImages.length > 1)
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 10,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Text(
                                          'Swipe to see all images',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            widget.feed.mediaImages.length,
                                            (idx) => Container(
                                              width: 6,
                                              height: 6,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: dialogImageIndex == idx
                                                    ? Colors.white
                                                    : Colors.white54,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (widget.feed.mediaImages.length > 1)
                                Positioned(
                                  left: 6,
                                  top: 0,
                                  bottom: 0,
                                  child: IconButton(
                                    onPressed: dialogImageIndex == 0
                                        ? null
                                        : () {
                                            dialogPageController.previousPage(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              if (widget.feed.mediaImages.length > 1)
                                Positioned(
                                  right: 6,
                                  top: 0,
                                  bottom: 0,
                                  child: IconButton(
                                    onPressed:
                                        dialogImageIndex ==
                                            widget.feed.mediaImages.length - 1
                                        ? null
                                        : () {
                                            dialogPageController.nextPage(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // Text, Poll and Comments section
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.feed.content.trim().isNotEmpty) ...[
                                SelectableText(
                                  widget.feed.content,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              if (pollModel != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pollModel.question,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...pollModel.options.map((option) {
                                        final isSelected =
                                            selectedOptionId == option.optionId;
                                        final pct = totalVotes == 0
                                            ? 0
                                            : ((option.votes / totalVotes) *
                                                      100)
                                                  .round();

                                        return GestureDetector(
                                          onTap: hasCurrentUserVoted
                                              ? null
                                              : () {
                                                  setDialogState(() {
                                                    selectedOptionId =
                                                        option.optionId;
                                                  });
                                                },
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 9,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: 0.1)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(
                                                        context,
                                                      ).dividerColor,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    option.title,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: FeedAppColors
                                                          .textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${option.votes} votes${totalVotes > 0 ? ' ($pct%)' : ''}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: FeedAppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (widget.currentUserUid != null)
                                            ElevatedButton(
                                              onPressed:
                                                  (selectedOptionId == null ||
                                                      hasCurrentUserVoted ||
                                                      isVoting)
                                                  ? null
                                                  : () async {
                                                      final feedId =
                                                          widget.feed.uid;
                                                      if (feedId == null) {
                                                        FlushBar.show(
                                                          context,
                                                          'Feed id is missing',
                                                          isSuccess: false,
                                                        );
                                                        return;
                                                      }

                                                      setDialogState(() {
                                                        isVoting = true;
                                                      });

                                                      try {
                                                        await FeedService.votePoll(
                                                          feedId: feedId,
                                                          optionId:
                                                              selectedOptionId!,
                                                        );

                                                        setDialogState(() {
                                                          final option = pollModel
                                                              .options
                                                              .firstWhere(
                                                                (o) =>
                                                                    o.optionId ==
                                                                    selectedOptionId,
                                                              );
                                                          option.votes += 1;
                                                          if (widget
                                                                  .currentUserUid !=
                                                              null) {
                                                            pollModel
                                                                .votedUserIds
                                                                .add(
                                                                  widget
                                                                      .currentUserUid!,
                                                                );
                                                          }
                                                          isVoting = false;
                                                        });

                                                        if (mounted) {
                                                          widget.onRefresh();
                                                        }
                                                      } catch (e) {
                                                        setDialogState(() {
                                                          isVoting = false;
                                                        });
                                                        if (mounted) {
                                                          FlushBar.show(
                                                            context,
                                                            e.toString(),
                                                            isSuccess: false,
                                                          );
                                                        }
                                                      }
                                                    },
                                              child: Text(
                                                hasCurrentUserVoted
                                                    ? 'Already Participated'
                                                    : isVoting
                                                    ? 'Voting...'
                                                    : 'Participate',
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          if (widget.currentUserUid ==
                                              widget.feed.authorId)
                                            OutlinedButton(
                                              onPressed: () {
                                                Navigator.pop(dialogContext);
                                                _openPostEdit();
                                              },
                                              child: const Text('Manage Poll'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              if (widget.feed.attachments.isNotEmpty) ...[
                                Text(
                                  'Attachments (${widget.feed.attachments.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    primary: false,
                                    padding: const EdgeInsets.all(10),
                                    itemCount: widget.feed.attachments.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 14),
                                    itemBuilder: (context, index) {
                                      final file =
                                          widget.feed.attachments[index];
                                      return Row(
                                        children: [
                                          Icon(
                                            Iconsax.document,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  file.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: FeedAppColors
                                                        .textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  _formatFileSize(file.size),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: FeedAppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              await Download.downloadFromUrl(
                                                context,
                                                file.url,
                                                file.name,
                                              );
                                            },
                                            child: const Text('Open'),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              Text(
                                'Comments (${dialogComments.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 300,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: dialogComments.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No comments yet',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        )
                                      : Scrollbar(
                                          thumbVisibility: true,
                                          child: ListView.separated(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            primary: false,
                                            padding: const EdgeInsets.all(10),
                                            itemCount: dialogComments.length,
                                            separatorBuilder:
                                                (context, index) =>
                                                    const SizedBox(height: 10),
                                            itemBuilder: (context, index) {
                                              final comment =
                                                  dialogComments[index];
                                              final liveAuthor =
                                                  commentAuthors[comment
                                                      .authorId];
                                              final authorName =
                                                  liveAuthor?.name ??
                                                  comment.authorName;
                                              final authorAvatar =
                                                  liveAuthor?.avatar ??
                                                  comment.authorAvatar;
                                              final canDelete =
                                                  widget.currentUserUid ==
                                                  comment.authorId;

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        onTap: () =>
                                                            _openUserProfileFromComment(
                                                              comment.authorId,
                                                            ),
                                                        child: CachedNetworkImage(
                                                          imageUrl: authorAvatar.isNotEmpty
                                                              ? authorAvatar
                                                              : AppStrings.emptyProfilePhotoUrl,
                                                          imageBuilder: (context, imageProvider) => CircleAvatar(
                                                            radius: 12,
                                                            backgroundColor: FeedAppColors.background,
                                                            backgroundImage: imageProvider,
                                                          ),
                                                          errorWidget: (context, url, error) => const CircleAvatar(
                                                            radius: 12,
                                                            backgroundColor: FeedAppColors.background,
                                                            child: Icon(Iconsax.danger, size: 12),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            InkWell(
                                                              onTap: () =>
                                                                  _openUserProfileFromComment(
                                                                    comment
                                                                        .authorId,
                                                                  ),
                                                              child: Text(
                                                                authorName,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 11,
                                                                  color: FeedAppColors
                                                                      .textPrimary,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              timeago.format(
                                                                comment
                                                                    .createdAt,
                                                                locale:
                                                                    'en_short',
                                                              ),
                                                              style: const TextStyle(
                                                                fontSize: 9,
                                                                color: FeedAppColors
                                                                    .textSecondary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (canDelete)
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            size: 18,
                                                            color: Colors.red,
                                                          ),
                                                          onPressed: () async {
                                                            final shouldDelete = await showDialog<bool>(
                                                              context: context,
                                                              builder: (confirmContext) {
                                                                return AlertDialog(
                                                                  title: const Text(
                                                                    'Delete Comment',
                                                                  ),
                                                                  content:
                                                                      const Text(
                                                                        'Are you sure you want to delete this comment?',
                                                                      ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            confirmContext,
                                                                            false,
                                                                          ),
                                                                      child: const Text(
                                                                        'Cancel',
                                                                      ),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            confirmContext,
                                                                            true,
                                                                          ),
                                                                      child: const Text(
                                                                        'Delete',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );

                                                            if (shouldDelete !=
                                                                true) {
                                                              return;
                                                            }

                                                            try {
                                                              await FeedService.deleteComment(
                                                                feedId:
                                                                    widget
                                                                        .feed
                                                                        .uid ??
                                                                    '',
                                                                commentId: comment
                                                                    .commentId,
                                                              );

                                                              setDialogState(() {
                                                                dialogComments
                                                                    .removeWhere(
                                                                      (c) =>
                                                                          c.commentId ==
                                                                          comment
                                                                              .commentId,
                                                                    );
                                                              });

                                                              if (mounted) {
                                                                widget
                                                                    .onRefresh();
                                                              }
                                                            } catch (e) {
                                                              if (mounted) {
                                                                FlushBar.show(
                                                                  context,
                                                                  e.toString(),
                                                                  isSuccess:
                                                                      false,
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    comment.content,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      height: 1.3,
                                                      color: FeedAppColors
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: dialogCommentController,
                                      minLines: 1,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        hintText: 'Add a comment...',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: isPostingComment
                                        ? null
                                        : () async {
                                            final feedId = widget.feed.uid;
                                            final uid = widget.currentUserUid;
                                            final content =
                                                dialogCommentController.text
                                                    .trim();

                                            if (feedId == null ||
                                                feedId.isEmpty) {
                                              FlushBar.show(
                                                context,
                                                'Feed id is missing',
                                                isSuccess: false,
                                              );
                                              return;
                                            }

                                            if (uid == null || uid.isEmpty) {
                                              FlushBar.show(
                                                context,
                                                'User not found',
                                                isSuccess: false,
                                              );
                                              return;
                                            }

                                            if (content.isEmpty) {
                                              return;
                                            }

                                            setDialogState(() {
                                              isPostingComment = true;
                                            });

                                            try {
                                              String authorName = 'Anonymous';
                                              String authorAvatar = '';

                                              final isAdmin =
                                                  await Spdb.isAdminLoggedIn();
                                              if (isAdmin) {
                                                final admin =
                                                    await AdminService.getAdmin(
                                                      uid: uid,
                                                    );
                                                authorName =
                                                    admin?.name ?? 'Anonymous';
                                                authorAvatar =
                                                    admin?.profileImageUrl ??
                                                    '';
                                              } else {
                                                final employee =
                                                    await EmployeeService.getEmployee(
                                                      uid: uid,
                                                    );
                                                authorName =
                                                    employee?.name ??
                                                    'Anonymous';
                                                authorAvatar =
                                                    employee?.profileImageUrl ??
                                                    '';
                                              }

                                              final newComment = CommentModel(
                                                commentId: DateTime.now()
                                                    .millisecondsSinceEpoch
                                                    .toString(),
                                                authorId: uid,
                                                authorName: authorName,
                                                authorAvatar: authorAvatar,
                                                content: content,
                                                createdAt: DateTime.now(),
                                              );

                                              await FeedService.addComment(
                                                feedId: feedId,
                                                comment: newComment,
                                              );

                                              setDialogState(() {
                                                commentAuthors[uid] =
                                                    _CommentAuthorDisplay(
                                                      name: authorName,
                                                      avatar: authorAvatar,
                                                    );
                                                dialogComments.insert(
                                                  0,
                                                  newComment,
                                                );
                                                dialogCommentController.clear();
                                                isPostingComment = false;
                                              });

                                              if (mounted) {
                                                widget.onRefresh();
                                              }
                                            } catch (e) {
                                              setDialogState(() {
                                                isPostingComment = false;
                                              });
                                              if (mounted) {
                                                FlushBar.show(
                                                  context,
                                                  e.toString(),
                                                  isSuccess: false,
                                                );
                                              }
                                            }
                                          },
                                    child: Text(
                                      isPostingComment ? 'Posting...' : 'Post',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      dialogCommentController.dispose();
      dialogPageController.dispose();
    }
  }

  Future<void> _showPostSavedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Post saved successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPostDeletedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Post deleted successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDeletePost() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _openPostEdit() async {
    if (kIsMobile) {
      final result = await Sheet.showSheet(
        context,
        widget: FeedEdit(uid: widget.feed.uid ?? ''),
      );
      if (result == true && mounted) {
        widget.onRefresh();
        await _showPostSavedDialog();
      }
    } else {
      final result = await GeneralDialog.showRTLSheet(
        context,
        FeedEdit(uid: widget.feed.uid ?? ''),
      );
      if (result == true && mounted) {
        widget.onRefresh();
        await _showPostSavedDialog();
      }
    }
  }

  Future<void> _deletePost() async {
    final shouldDelete = await _confirmDeletePost();
    if (!shouldDelete) return;

    try {
      futureLoading(context);
      await FeedService.deleteFeed(uid: widget.feed.uid ?? '');

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      widget.onRefresh();
      await _showPostDeletedDialog();
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _postAuthorName = widget.feed.authorName;
    _postAuthorAvatar = widget.feed.authorAvatar;
    _loadPostAuthorDisplay();
    _isLiked = widget.feed.reactions.any(
      (r) => r.userId == widget.currentUserUid,
    );
    _isSaved =
        widget.currentUserUid != null &&
        widget.feed.savedBy.contains(widget.currentUserUid);
    _likeCount = widget.feed.reactions.length;
  }

  @override
  void didUpdateWidget(covariant FeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed.authorId != widget.feed.authorId ||
        oldWidget.feed.authorName != widget.feed.authorName ||
        oldWidget.feed.authorAvatar != widget.feed.authorAvatar) {
      _postAuthorName = widget.feed.authorName;
      _postAuthorAvatar = widget.feed.authorAvatar;
      _loadPostAuthorDisplay();
    }
  }

  void _handleLike() {
    if (widget.currentUserUid == null) return;
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });
    context.read<FeedBloc>().add(
      ToggleLike(feedId: widget.feed.uid!, userId: widget.currentUserUid!),
    );
  }

  void _handleSave() {
    if (widget.currentUserUid == null) return;
    setState(() {
      _isSaved = !_isSaved;
    });
    context.read<FeedBloc>().add(
      ToggleSaveFeed(feedId: widget.feed.uid!, userId: widget.currentUserUid!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Condensed
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      _openUserProfileFromComment(widget.feed.authorId),
                  child: CachedNetworkImage(
                    imageUrl: _postAuthorAvatar.isNotEmpty
                        ? _postAuthorAvatar
                        : AppStrings.emptyProfilePhotoUrl,
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      backgroundImage: imageProvider,
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      child: const Icon(Iconsax.danger, size: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () =>
                            _openUserProfileFromComment(widget.feed.authorId),
                        child: Text(
                          _postAuthorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _buildTimeLabel(widget.feed),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.currentUserUid == widget.feed.authorId)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Iconsax.more,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _openPostEdit();
                        return;
                      }

                      if (value == 'delete') {
                        await _deletePost();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit Post'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete Post'),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Media Section - Instagram Like
          Expanded(
            child: InkWell(
              onTap: () =>
                  _openPostPreview(initialImageIndex: _currentImageIndex),
              child: Stack(
                children: [
                  if (widget.feed.poll != null)
                    _buildPollPreview()
                  else if (widget.feed.mediaImages.isNotEmpty)
                    CarouselSlider(
                      options: CarouselOptions(
                        height: double.infinity,
                        viewportFraction: 1,
                        enableInfiniteScroll: false,
                        onPageChanged: (index, _) =>
                            setState(() => _currentImageIndex = index),
                      ),
                      items: widget.feed.mediaImages
                          .map(
                            (m) => Image.network(
                              m.url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                          .toList(),
                    )
                  else if (widget.feed.attachments.isNotEmpty)
                    _buildAttachmentsPreview()
                  else if (widget.feed.content.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).scaffoldBackgroundColor,
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.center,
                      child: Text(
                        widget.feed.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Iconsax.document_text,
                        color: Theme.of(context).dividerColor,
                        size: 40,
                      ),
                    ),

                  // Pagination Indicator Overlay
                  if (widget.feed.poll == null && widget.feed.mediaImages.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.feed.mediaImages.length,
                          (index) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Lower Content area
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((widget.feed.mediaImages.isNotEmpty ||
                        widget.feed.poll != null ||
                        widget.feed.attachments.isNotEmpty) &&
                    widget.feed.content.isNotEmpty)
                  Text(
                    widget.feed.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (widget.feed.content.length > 120)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      onTap: _openPostPreview,
                      child: Text(
                        'View full post',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                if (widget.feed.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.attach_circle,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.feed.attachments.length} file${widget.feed.attachments.length == 1 ? '' : 's'} attached',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),

                // Interaction Bar
                Row(
                  children: [
                    _interactionIcon(
                      _isLiked ? Iconsax.heart5 : Iconsax.heart,
                      _isLiked
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      _likeCount > 0 ? _likeCount.toString() : "",
                      _handleLike,
                    ),
                    const SizedBox(width: 12),
                    _interactionIcon(
                      Iconsax.message,
                      Theme.of(context).colorScheme.onSurfaceVariant,
                      _commentCount > 0 ? _commentCount.toString() : "",
                      () => _showCommentSheet(),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _handleSave,
                      child: Icon(
                        _isSaved ? Iconsax.archive_minus5 : Iconsax.archive_add,
                        size: 18,
                        color: _isSaved
                            ? FeedAppColors.primary
                            : FeedAppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildAttachmentsPreview() {
    final attachments = widget.feed.attachments;
    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.folder_open,
                  size: 10,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'FILES',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...attachments.take(4).map((file) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Iconsax.document,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _formatFileSize(file.size),
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          if (attachments.length > 4)
            Text(
              '+${attachments.length - 4} more files',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPollPreview() {
    final poll = widget.feed.poll!;
    final totalVotes = poll.options.fold<int>(0, (sum, o) => sum + o.votes);
    final hasVoted = widget.currentUserUid != null &&
        poll.votedUserIds.contains(widget.currentUserUid);

    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.judge,
                  size: 10,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  "POLL",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            poll.question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...poll.options.take(3).map((option) {
            final pct = totalVotes == 0
                ? 0
                : ((option.votes / totalVotes) * 100).round();
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              width: double.infinity,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Stack(
                children: [
                  if (hasVoted)
                    FractionallySizedBox(
                      widthFactor: totalVotes == 0 ? 0 : option.votes / totalVotes,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  hasVoted ? FontWeight.w600 : FontWeight.normal,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (hasVoted)
                          Text(
                            "$pct%",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (poll.options.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                "+ ${poll.options.length - 3} more options",
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$totalVotes votes",
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                hasVoted ? "Voted" : "Tap to vote",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: hasVoted
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _interactionIcon(
    IconData icon,
    Color color,
    String count,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          if (count.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatShortTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _buildTimeLabel(FeedModel feed) {
    final createdLabel = _formatShortTime(feed.createdAt);
    final updatedAt = feed.updatedAt;

    if (updatedAt == null || updatedAt.isAtSameMomentAs(feed.createdAt)) {
      return 'Posted $createdLabel ago';
    }

    return 'Posted $createdLabel ago · Edited ${_formatShortTime(updatedAt)} ago';
  }

  Future<void> _showCommentSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => CommentSheet(
        feedId: widget.feed.uid!,
        currentUserUid: widget.currentUserUid,
        initialComments: widget.feed.comments ?? [],
      ),
    );

    if (mounted) {
      widget.onRefresh();
    }
  }
}
