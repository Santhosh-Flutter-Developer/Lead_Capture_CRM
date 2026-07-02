import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/views/screens/chat/listing/bloc/chat_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/constants/constants.dart';

class AboutChat extends StatefulWidget {
  final ChatModel chat;
  final String userUid;
  final UserType? userType;
  final String? currentUserUid;

  const AboutChat({
    super.key,
    required this.chat,
    required this.userUid,
    this.userType,
    this.currentUserUid,
  });

  @override
  State<AboutChat> createState() => _AboutChatState();
}

class _AboutChatState extends State<AboutChat> {
  bool canEditGroup = false;
  String currentUserUid = '';
  @override
  void initState() {
    super.initState();
    currentUserUid = widget.currentUserUid ?? '';
    _init();
  }

  Future<void> _init() async {
    if (currentUserUid.isEmpty) {
      currentUserUid = await Spdb.getUid() ?? '';
    }
    _canEditGroup();
    setState(() {});
  }

  Future<void> _canEditGroup() async {
    if (!widget.chat.isGroupChat) return;

    final currentUser = await Spdb.getUser();
    final isAdmin = currentUser.userType == UserType.admin;
    final isCreator = widget.chat.createdBy == currentUserUid;

    setState(() {
      canEditGroup = isAdmin || isCreator;
    });

    debugPrint(
      'isAdmin: $isAdmin, isCreator: $isCreator, isGroup: ${widget.chat.isGroupChat}',
    );
    debugPrint(
      'chat.createdBy: "${widget.chat.createdBy}", userUid: "$currentUserUid"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelfChat =
        widget.userUid == currentUserUid ||
        widget.userUid.isEmpty ||
        widget.chat.participants.every((id) => id == currentUserUid);
    final title = widget.chat.isGroupChat
        ? widget.chat.title ?? 'Group Chat'
        : isSelfChat
        ? 'Saved Messages'
        : CacheService.getUserByUid(widget.userUid)?.name ?? '';
    String opponentUid = isSelfChat
        ? currentUserUid
        : widget.chat.participants.firstWhere(
            (id) => id != currentUserUid,
            orElse: () => '',
          );

    var user = CacheService.getUserByUid(opponentUid);

    final String imageUrl = isSelfChat
        ? ''
        : user is EmployeeModel
        ? (user.profileImageUrl ?? '')
        : user is AdminModel
        ? (user.profileImageUrl ?? '')
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(
                      context,
                      title,
                      imageUrl,
                      isSelfChat: isSelfChat,
                    ),
                    const SizedBox(height: 32),

                    if (widget.chat.isGroupChat) ...[
                      _buildSectionLabel("PARTICIPANTS"),
                      const SizedBox(height: 12),
                      _buildParticipantsCard(context),
                      const SizedBox(height: 32),
                    ],

                    _buildSectionLabel("PREFERENCES & MEDIA"),
                    const SizedBox(height: 12),
                    _buildActionsCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String title,
    String imageUrl, {
    required bool isSelfChat,
  }) {
    final bool avatarValid = imageUrl.isNotEmpty;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: GestureDetector(
              onTap: avatarValid && !isSelfChat
                  ? () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            children: [
                              Center(
                                child: InteractiveViewer(
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              /// ❌ CLOSE BUTTON
                              Positioned(
                                top: 40,
                                right: 20,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  : null,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                child: widget.chat.isGroupChat
                    ? Icon(
                        Iconsax.people,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : isSelfChat
                    ? Icon(
                        Iconsax.save_2,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : avatarValid
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      )
                    : Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          if (widget.chat.isGroupChat)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.chat.participants.length} Active Members',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: widget.chat.participants.length,
          separatorBuilder: (_, _) => Container(
            margin: const EdgeInsets.only(left: 72),
            child: const Divider(height: 1, thickness: 0.5),
          ),
          itemBuilder: (context, index) {
            final uid = widget.chat.participants[index];
            final user = CacheService.getUserByUid(uid);
            String name = '';
            String? image;

            if (user is AdminModel) {
              name = user.name;
              image = user.profileImageUrl;
            } else if (user is EmployeeModel) {
              name = user.name;
              image = user.profileImageUrl;
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: _buildMemberAvatar(name, image),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: uid == widget.chat.createdBy
                  ? Text(
                      "Group Owner",
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Text(
                      "Member",
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
              trailing: Icon(
                Iconsax.message,
                size: 18,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(String name, String? image) {
    bool hasImage = image != null && image.isNotEmpty;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: !hasImage
            ? LetterColors.getColor(name.isNotEmpty ? name[0] : 'U')
            : Theme.of(context).colorScheme.outlineVariant,
        shape: BoxShape.circle,
      ),
      child: hasImage
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (_, _, _) =>
                    const Icon(Iconsax.user, size: 20, color: Colors.white),
              ),
            )
          : Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          if (canEditGroup) ...[
            _buildActionTile(
              context,
              icon: Iconsax.edit,
              iconColor: Theme.of(context).colorScheme.primary,
              title: 'Edit group chat',
              showChevron: true,
              onTap: () {
                Navigator.pop(context);
                Sheet.showSheet(
                  context,
                  widget: EditGroupChat(chat: widget.chat),
                );
              },
            ),
            _buildDivider(),
          ],

          _buildActionTile(
            context,
            icon: widget.chat.isPinnedForUser(widget.userUid) == true
                ? Icons.push_pin
                : Iconsax.percentage_circle,
            iconColor: Colors.orangeAccent,
            title: widget.chat.isPinnedForUser(widget.userUid) == true
                ? 'Unpin this conversation'
                : 'Pin to top',
            onTap: () async {
              await ChatService.toggleChatPin(
                chatId: widget.chat.uid!,
                value: !widget.chat.isPinnedForUser(widget.userUid),
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          _buildDivider(),
          _buildActionTile(
            context,
            icon: widget.chat.isFavoriteForUser(widget.userUid) == true
                ? Iconsax.heart5
                : Iconsax.heart,
            iconColor: Colors.redAccent,
            title: widget.chat.isFavoriteForUser(widget.userUid) == true
                ? 'Remove from favorites'
                : 'Add to favorites',
            onTap: () async {
              await ChatService.toggleChatFavorite(
                chatId: widget.chat.uid!,
                value: !widget.chat.isFavoriteForUser(widget.userUid),
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          _buildDivider(),
          _buildActionTile(
            context,
            icon: Iconsax.folder_open,
            iconColor: Colors.blueAccent,
            title: 'Media, links & documents',
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              if (kIsMobile || width < 1000) {
                Sheet.showSheet(
                  context,
                  widget: ChatAttachment(chatId: widget.chat.uid ?? ''),
                );
              } else {
                GeneralDialog.showRTLSheet(
                  context,
                  ChatAttachment(chatId: widget.chat.uid ?? ''),
                );
              }
            },
          ),
          _buildDivider(),
          _buildActionTile(
            context,
            icon: Iconsax.trash,
            iconColor: Colors.red,
            title: 'Delete chat',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete chat'),
                  content: const Text(
                    'This chat will be deleted. You can undo this action.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final deletedChat = widget.chat; // ✅ backup before delete
                final chatId = widget.chat.uid!;

                // ✅ delete chat
                await ChatService.deleteChat(chatId: chatId);
                if (!context.mounted) return;

                // ✅ show UNDO
                FlushBar.show(
                  context,
                  'Chat deleted',
                  actionLabel: 'UNDO',
                  onActionPressed: () async {
                    await ChatService.restoreChat(deletedChat);
                    if (!context.mounted) return;
                    context.read<ChatBloc>().add(StreamChat());
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool showChevron = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: showChevron
          ? Icon(
              Iconsax.arrow_right_3,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }

  Widget _buildDivider() => Container(
    margin: const EdgeInsets.only(left: 64),
    child: const Divider(height: 1, thickness: 0.5),
  );
}
