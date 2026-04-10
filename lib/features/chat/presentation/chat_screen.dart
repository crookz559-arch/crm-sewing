import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import '../../users/presentation/users_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(icon: Icon(Icons.forum_outlined), text: 'Общий'),
              Tab(icon: Icon(Icons.people_outline), text: 'Персонал'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _GroupChatTab(),
              _PersonnelTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Group Chat Tab ───────────────────────────────────────────────────────────

class _GroupChatTab extends ConsumerStatefulWidget {
  const _GroupChatTab();

  @override
  ConsumerState<_GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends ConsumerState<_GroupChatTab> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  ChatMessage? _replyTo;
  ChatMessage? _editingMsg;
  bool _sending = false;

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
    if (text.isEmpty || _sending) return;
    _inputCtrl.clear();

    if (_editingMsg != null) {
      final msgId = _editingMsg!.id;
      setState(() { _editingMsg = null; _sending = true; });
      try {
        await ref.read(chatProvider.notifier).editMessage(msgId, text);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    } else {
      final reply = _replyTo;
      setState(() { _replyTo = null; _sending = true; });
      try {
        await ref.read(chatProvider.notifier).sendMessage(text, replyTo: reply?.id);
        _scrollToBottom();
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickFile({bool imagesOnly = false}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: imagesOnly ? FileType.image : FileType.any,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;
    setState(() => _sending = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final ext = (picked.extension ?? '').toLowerCase();
      final isImage = RegExp(r'jpg|jpeg|png|gif|webp|heic|bmp').hasMatch(ext);
      final url = await uploadChatFile(
        client: client, bucket: 'chat-files',
        fileName: picked.name, bytes: picked.bytes,
        mimeType: isImage ? 'image/$ext' : 'application/octet-stream',
      );
      await ref.read(chatProvider.notifier).sendMessage(null,
          attachmentUrl: url,
          attachmentType: isImage ? 'image' : 'file',
          attachmentName: picked.name);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingMsg = msg;
      _replyTo = null;
      _inputCtrl.text = msg.content ?? '';
    });
  }

  Future<void> _deleteMsg(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет помечено как удалённое.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(chatProvider.notifier).deleteMessage(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final myId = currentUser?['id'] as String?;

    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('Нет сообщений', style: TextStyle(color: AppColors.grey600)))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.userId == myId;
                    final showName = i == 0 || messages[i - 1].userId != msg.userId;
                    return ChatBubble(
                      key: ValueKey(msg.id),
                      userId: msg.userId,
                      userName: msg.userName,
                      userAvatarUrl: msg.userAvatarUrl,
                      content: msg.content,
                      attachmentUrl: msg.attachmentUrl,
                      attachmentType: msg.attachmentType,
                      attachmentName: msg.attachmentName,
                      isDeleted: msg.isDeleted,
                      editedAt: msg.editedAt,
                      createdAt: msg.createdAt,
                      isMe: isMe,
                      showName: showName,
                      onReply: () => setState(() { _replyTo = msg; _editingMsg = null; }),
                      onEdit: isMe && !msg.isDeleted ? () => _startEdit(msg) : null,
                      onDelete: isMe && !msg.isDeleted ? () => _deleteMsg(msg.id) : null,
                    );
                  },
                ),
        ),
        if (_editingMsg != null)
          EditingBanner(
            text: _editingMsg!.content ?? '',
            onClose: () => setState(() { _editingMsg = null; _inputCtrl.clear(); }),
          ),
        if (_replyTo != null && _editingMsg == null)
          ChatReplyPreview(
            text: _replyTo!.content ?? _replyTo!.attachmentName ?? '',
            onClose: () => setState(() => _replyTo = null),
          ),
        ChatMessageInput(
          controller: _inputCtrl,
          sending: _sending,
          isEditing: _editingMsg != null,
          onSend: _send,
          onPickImage: () => _pickFile(imagesOnly: true),
          onPickFile: () => _pickFile(imagesOnly: false),
        ),
      ],
    );
  }
}

// ─── Personnel Tab ────────────────────────────────────────────────────────────

class _PersonnelTab extends ConsumerWidget {
  const _PersonnelTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final myId = currentUser?['id'] as String?;

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (users) {
        final others = users.where((u) => u['id'] != myId).toList();
        if (others.isEmpty) {
          return const Center(child: Text('Нет сотрудников', style: TextStyle(color: AppColors.grey600)));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: others.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) {
            final u = others[i];
            final uid = u['id'] as String;
            final name = u['name'] as String? ?? '';
            final role = u['role'] as String? ?? '';
            final avatarUrl = u['avatar_url'] as String?;
            return ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))
                    : null,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_roleName(role), style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
              trailing: FilledButton.tonal(
                onPressed: () => context.push('/chat/dm/$uid'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.send, size: 16), SizedBox(width: 6), Text('Написать')],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _roleName(String role) => switch (role) {
    'director' => 'Директор',
    'manager' => 'Менеджер',
    'seamstress' => 'Швея',
    'courier' => 'Курьер',
    _ => role,
  };
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class ChatBubble extends StatelessWidget {
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String? content;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime createdAt;
  final bool isMe;
  final bool showName;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    this.content,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.isDeleted = false,
    this.editedAt,
    required this.createdAt,
    required this.isMe,
    required this.showName,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  void _showContextMenu(BuildContext context) {
    if (isDeleted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppColors.grey400, borderRadius: BorderRadius.circular(2)),
            ),
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Ответить'),
                onTap: () { Navigator.pop(context); onReply!(); },
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Редактировать'),
                onTap: () { Navigator.pop(context); onEdit!(); },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); onDelete!(); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bubbleColor = isDeleted
        ? (isMe ? cs.primary.withValues(alpha: 0.4) : cs.surfaceContainerHighest.withValues(alpha: 0.5))
        : (isMe ? cs.primary : cs.surfaceContainerHighest);
    final textColor = isMe ? cs.onPrimary : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: userAvatarUrl != null ? NetworkImage(userAvatarUrl!) : null,
                child: userAvatarUrl == null
                    ? Text(
                        (userName?.isNotEmpty == true) ? userName![0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          GestureDetector(
            onLongPress: () => _showContextMenu(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && userName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(userName!,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
                      ),
                    if (isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, size: 14, color: textColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text('Сообщение удалено',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: textColor.withValues(alpha: 0.5))),
                        ],
                      )
                    else ...[
                      if (attachmentUrl != null && attachmentType == 'image')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            attachmentUrl!, width: 200, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                          ),
                        ),
                      if (attachmentUrl != null && attachmentType != 'image')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insert_drive_file_outlined, size: 20, color: textColor),
                              const SizedBox(width: 6),
                              Flexible(child: Text(attachmentName ?? 'файл',
                                  style: TextStyle(color: textColor, fontSize: 13))),
                            ],
                          ),
                        ),
                      if (content != null && content!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: attachmentUrl != null ? 4 : 0),
                          child: Text(content!, style: TextStyle(color: textColor)),
                        ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                        ),
                        if (editedAt != null && !isDeleted) ...[
                          const SizedBox(width: 4),
                          Text('изм.',
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic,
                                  color: textColor.withValues(alpha: 0.5))),
                        ],
                      ],
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
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Edit / Reply banners ─────────────────────────────────────────────────────

class EditingBanner extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const EditingBanner({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Редактирование', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose,
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }
}

class ChatReplyPreview extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const ChatReplyPreview({super.key, required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: AppColors.grey600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
          ),
          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose,
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }
}

// ─── Message Input ────────────────────────────────────────────────────────────

class ChatMessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool isEditing;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  const ChatMessageInput({
    super.key,
    required this.controller,
    required this.sending,
    this.isEditing = false,
    required this.onSend,
    required this.onPickImage,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).viewInsets.bottom),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image_outlined,
                color: sending ? AppColors.grey400 : AppColors.grey600),
            onPressed: sending ? null : onPickImage,
            tooltip: 'Фото',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(Icons.attach_file,
                color: sending ? AppColors.grey400 : AppColors.grey600),
            onPressed: sending ? null : onPickFile,
            tooltip: 'Файл',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: isEditing ? 'Редактировать...' : 'Сообщение...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isEditing
                    ? cs.primaryContainer.withValues(alpha: 0.3)
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  onPressed: onSend,
                  icon: Icon(
                    isEditing ? Icons.check : Icons.send,
                    color: cs.primary,
                  ),
                ),
        ],
      ),
    );
  }
}
