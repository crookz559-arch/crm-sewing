import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import 'chat_screen.dart' show ChatBubble, ChatReplyPreview, ChatMessageInput, EditingBanner;

// Provider to get user info by id
final _userInfoProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('users').select().eq('id', userId).maybeSingle();
  return data as Map<String, dynamic>?;
});

class DirectMessageScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  const DirectMessageScreen({super.key, required this.otherUserId});

  @override
  ConsumerState<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends ConsumerState<DirectMessageScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  DirectMessage? _replyTo;
  DirectMessage? _editingMsg;
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
        await ref.read(dmProvider(widget.otherUserId).notifier).editMessage(msgId, text);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    } else {
      final reply = _replyTo;
      setState(() { _replyTo = null; _sending = true; });
      try {
        await ref.read(dmProvider(widget.otherUserId).notifier)
            .sendMessage(text, replyTo: reply?.id);
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
        client: client, bucket: 'dm-files',
        fileName: picked.name, bytes: picked.bytes,
        mimeType: isImage ? 'image/$ext' : 'application/octet-stream',
      );
      await ref.read(dmProvider(widget.otherUserId).notifier).sendMessage(null,
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

  void _startEdit(DirectMessage msg) {
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
    if (ok == true && mounted) {
      await ref.read(dmProvider(widget.otherUserId).notifier).deleteMessage(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(dmProvider(widget.otherUserId));
    final currentUser = ref.watch(currentUserProvider).value;
    final myId = currentUser?['id'] as String?;
    final otherUser = ref.watch(_userInfoProvider(widget.otherUserId));

    ref.listen(dmProvider(widget.otherUserId), (_, __) => _scrollToBottom());

    final otherName = otherUser.value?['name'] as String? ?? '...';
    final otherAvatar = otherUser.value?['avatar_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
              child: otherAvatar == null
                  ? Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  _roleName(otherUser.value?['role'] as String? ?? ''),
                  style: const TextStyle(fontSize: 12, color: AppColors.grey600, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.grey600),
                        SizedBox(height: 12),
                        Text('Начните диалог', style: TextStyle(color: AppColors.grey600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.fromUserId == myId;
                      final showName = i == 0 || messages[i - 1].fromUserId != msg.fromUserId;
                      return ChatBubble(
                        key: ValueKey(msg.id),
                        userId: msg.fromUserId,
                        userName: msg.fromUserName,
                        userAvatarUrl: msg.fromAvatarUrl,
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
      ),
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
