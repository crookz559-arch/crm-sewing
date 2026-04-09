import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/chat_repository.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  ChatMessage? _replyTo;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    await ref.read(chatProvider.notifier).sendMessage(
          text,
          replyTo: reply?.id,
        );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messages = ref.watch(chatProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final myId = currentUser?['id'] as String?;

    // Scroll when messages change
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(l10n.noData,
                      style:
                          const TextStyle(color: AppColors.grey600)))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.userId == myId;
                    final showName = i == 0 ||
                        messages[i - 1].userId != msg.userId;
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showName: showName,
                      onReply: () =>
                          setState(() => _replyTo = msg),
                    );
                  },
                ),
        ),

        // Reply preview
        if (_replyTo != null)
          Container(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _replyTo!.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grey600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _replyTo = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, -2)),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
              12, 8, 8, 8 + MediaQuery.of(context).viewInsets.bottom),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.chatInputHint,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _send,
                icon: Icon(Icons.send,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showName;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showName,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor =
        isMe ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final textColor =
        isMe ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: message.userAvatarUrl != null
                    ? NetworkImage(message.userAvatarUrl!)
                    : null,
                child: message.userAvatarUrl == null
                    ? Text(
                        (message.userName?.isNotEmpty == true)
                            ? message.userName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          GestureDetector(
            onLongPress: onReply,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                        Radius.circular(isMe ? 16 : 4),
                    bottomRight:
                        Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && showName && message.userName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          message.userName!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary),
                        ),
                      ),
                    Text(message.content,
                        style: TextStyle(color: textColor)),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
