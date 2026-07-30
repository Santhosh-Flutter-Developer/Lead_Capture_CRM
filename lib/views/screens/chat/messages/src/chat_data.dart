part of 'chat_messages.dart';

class ChatData extends InheritedWidget {
  final String uid;
  final String currentUser;
  final bool isGroupChat;
  final ChatModel chat;

  const ChatData({
    required this.uid,
    required this.currentUser,
    required this.isGroupChat,
    required this.chat,
    required super.child,
    super.key,
  });

  static ChatData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatData>()!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;
}
