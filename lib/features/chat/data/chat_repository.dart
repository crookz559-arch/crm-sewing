import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/auth_provider.dart';

// ─── Group Chat ───────────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String? content;
  final String? replyToId;
  final String? attachmentUrl;
  final String? attachmentType; // 'image' | 'file'
  final String? attachmentName;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    this.content,
    this.replyToId,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.isDeleted = false,
    this.editedAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: author?['name'] as String?,
      userAvatarUrl: author?['avatar_url'] as String?,
      content: json['content'] as String?,
      replyToId: json['reply_to'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      attachmentName: json['attachment_name'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  ChatNotifier(this._client) : super([]) {
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    final data = await _client
        .from('chat_messages')
        .select('*, author:user_id(name, avatar_url)')
        .order('created_at', ascending: true)
        .limit(200);
    state = (data as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _subscribe() {
    _channel = _client
        .channel('chat_group_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            final row = payload.newRecord;
            try {
              final data = await _client
                  .from('chat_messages')
                  .select('*, author:user_id(name, avatar_url)')
                  .eq('id', row['id'] as String)
                  .single();
              final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
              state = [...state, msg];
            } catch (_) {}
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            final row = payload.newRecord;
            try {
              final data = await _client
                  .from('chat_messages')
                  .select('*, author:user_id(name, avatar_url)')
                  .eq('id', row['id'] as String)
                  .single();
              final updated = ChatMessage.fromJson(data as Map<String, dynamic>);
              state = state.map((m) => m.id == updated.id ? updated : m).toList();
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String? content, {
    String? replyTo,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return; // Session expired — ignore silently.
    await _client.from('chat_messages').insert({
      'user_id': uid,
      if (content != null && content.isNotEmpty) 'content': content,
      if (replyTo != null) 'reply_to': replyTo,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (attachmentName != null) 'attachment_name': attachmentName,
    });
  }

  Future<void> editMessage(String id, String newContent) async {
    await _client.from('chat_messages').update({
      'content': newContent,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    // Update local state immediately
    state = state.map((m) => m.id == id
        ? ChatMessage(
            id: m.id,
            userId: m.userId,
            userName: m.userName,
            userAvatarUrl: m.userAvatarUrl,
            content: newContent,
            replyToId: m.replyToId,
            attachmentUrl: m.attachmentUrl,
            attachmentType: m.attachmentType,
            attachmentName: m.attachmentName,
            isDeleted: m.isDeleted,
            editedAt: DateTime.now(),
            createdAt: m.createdAt,
          )
        : m).toList();
  }

  Future<void> deleteMessage(String id) async {
    await _client.from('chat_messages').update({
      'is_deleted': true,
      'content': null,
      'attachment_url': null,
      'attachment_name': null,
    }).eq('id', id);
    // Update local state immediately
    state = state.map((m) => m.id == id
        ? ChatMessage(
            id: m.id,
            userId: m.userId,
            userName: m.userName,
            userAvatarUrl: m.userAvatarUrl,
            content: null,
            replyToId: m.replyToId,
            attachmentUrl: null,
            attachmentType: null,
            attachmentName: null,
            isDeleted: true,
            editedAt: m.editedAt,
            createdAt: m.createdAt,
          )
        : m).toList();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatNotifier(client);
});

// ─── Direct Messages ──────────────────────────────────────────────────────────

class DirectMessage {
  final String id;
  final String fromUserId;
  final String? fromUserName;
  final String? fromAvatarUrl;
  final String toUserId;
  final String? content;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final String? replyToId;
  final bool isRead;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime createdAt;

  const DirectMessage({
    required this.id,
    required this.fromUserId,
    this.fromUserName,
    this.fromAvatarUrl,
    required this.toUserId,
    this.content,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.replyToId,
    required this.isRead,
    this.isDeleted = false,
    this.editedAt,
    required this.createdAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final from = json['from_user'] as Map<String, dynamic>?;
    return DirectMessage(
      id: json['id'] as String,
      fromUserId: json['from_user_id'] as String,
      fromUserName: from?['name'] as String?,
      fromAvatarUrl: from?['avatar_url'] as String?,
      toUserId: json['to_user_id'] as String,
      content: json['content'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      attachmentName: json['attachment_name'] as String?,
      replyToId: json['reply_to'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DmNotifier extends StateNotifier<List<DirectMessage>> {
  final SupabaseClient _client;
  final String _otherUserId;
  RealtimeChannel? _channel;

  DmNotifier(this._client, this._otherUserId) : super([]) {
    _load();
    _subscribe();
  }

  String get _myId => _client.auth.currentUser?.id ?? '';

  Future<void> _load() async {
    final data = await _client
        .from('direct_messages')
        .select('*, from_user:from_user_id(name, avatar_url)')
        .or('and(from_user_id.eq.$_myId,to_user_id.eq.$_otherUserId),and(from_user_id.eq.$_otherUserId,to_user_id.eq.$_myId)')
        .order('created_at', ascending: true)
        .limit(300);
    state = (data as List)
        .map((e) => DirectMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    _markRead();
  }

  void _subscribe() {
    _channel = _client
        .channel('dm_${_myId}_$_otherUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) async {
            final row = payload.newRecord;
            final from = row['from_user_id'] as String?;
            final to = row['to_user_id'] as String?;
            if ((from == _myId && to == _otherUserId) ||
                (from == _otherUserId && to == _myId)) {
              try {
                final data = await _client
                    .from('direct_messages')
                    .select('*, from_user:from_user_id(name, avatar_url)')
                    .eq('id', row['id'] as String)
                    .single();
                final msg = DirectMessage.fromJson(data as Map<String, dynamic>);
                state = [...state, msg];
                if (msg.fromUserId == _otherUserId) _markRead();
              } catch (_) {}
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) async {
            final row = payload.newRecord;
            final from = row['from_user_id'] as String?;
            final to = row['to_user_id'] as String?;
            if ((from == _myId && to == _otherUserId) ||
                (from == _otherUserId && to == _myId)) {
              try {
                final data = await _client
                    .from('direct_messages')
                    .select('*, from_user:from_user_id(name, avatar_url)')
                    .eq('id', row['id'] as String)
                    .single();
                final updated = DirectMessage.fromJson(data as Map<String, dynamic>);
                state = state.map((m) => m.id == updated.id ? updated : m).toList();
              } catch (_) {}
            }
          },
        )
        .subscribe();
  }

  Future<void> _markRead() async {
    await _client
        .from('direct_messages')
        .update({'is_read': true})
        .eq('from_user_id', _otherUserId)
        .eq('to_user_id', _myId)
        .eq('is_read', false);
  }

  Future<void> sendMessage(String? content, {
    String? replyTo,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
  }) async {
    if (_myId.isEmpty) return; // Session expired.
    await _client.from('direct_messages').insert({
      'from_user_id': _myId,
      'to_user_id': _otherUserId,
      if (content != null && content.isNotEmpty) 'content': content,
      if (replyTo != null) 'reply_to': replyTo,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (attachmentName != null) 'attachment_name': attachmentName,
    });
  }

  Future<void> editMessage(String id, String newContent) async {
    await _client.from('direct_messages').update({
      'content': newContent,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    state = state.map((m) => m.id == id
        ? DirectMessage(
            id: m.id,
            fromUserId: m.fromUserId,
            fromUserName: m.fromUserName,
            fromAvatarUrl: m.fromAvatarUrl,
            toUserId: m.toUserId,
            content: newContent,
            attachmentUrl: m.attachmentUrl,
            attachmentType: m.attachmentType,
            attachmentName: m.attachmentName,
            replyToId: m.replyToId,
            isRead: m.isRead,
            isDeleted: m.isDeleted,
            editedAt: DateTime.now(),
            createdAt: m.createdAt,
          )
        : m).toList();
  }

  Future<void> deleteMessage(String id) async {
    await _client.from('direct_messages').update({
      'is_deleted': true,
      'content': null,
      'attachment_url': null,
      'attachment_name': null,
    }).eq('id', id);
    state = state.map((m) => m.id == id
        ? DirectMessage(
            id: m.id,
            fromUserId: m.fromUserId,
            fromUserName: m.fromUserName,
            fromAvatarUrl: m.fromAvatarUrl,
            toUserId: m.toUserId,
            content: null,
            attachmentUrl: null,
            attachmentType: null,
            attachmentName: null,
            replyToId: m.replyToId,
            isRead: m.isRead,
            isDeleted: true,
            editedAt: m.editedAt,
            createdAt: m.createdAt,
          )
        : m).toList();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final dmProvider = StateNotifierProvider.family
    .autoDispose<DmNotifier, List<DirectMessage>, String>((ref, otherUserId) {
  final client = ref.watch(supabaseClientProvider);
  return DmNotifier(client, otherUserId);
});

// Unread DM count per user
final dmUnreadProvider = FutureProvider.autoDispose
    .family<int, String>((ref, otherUserId) async {
  final client = ref.watch(supabaseClientProvider);
  final myId = client.auth.currentUser?.id;
  if (myId == null) return 0;
  final data = await client
      .from('direct_messages')
      .select('id')
      .eq('from_user_id', otherUserId)
      .eq('to_user_id', myId)
      .eq('is_read', false);
  return (data as List).length;
});

// ─── File upload helper ───────────────────────────────────────────────────────

Future<String> uploadChatFile({
  required SupabaseClient client,
  required String bucket,
  required String fileName,
  Uint8List? bytes,
  File? file,
  String? mimeType,
}) async {
  final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
  final opts = mimeType != null
      ? FileOptions(contentType: mimeType)
      : const FileOptions();

  if (bytes != null) {
    // Prefer binary upload when bytes are available — works on ALL platforms
    // (web and mobile). Previously this only ran on kIsWeb, which caused
    // silent upload failure on Android/iOS when bytes were passed instead of File.
    await client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: opts);
  } else if (file != null) {
    await client.storage.from(bucket).upload(path, file, fileOptions: opts);
  } else {
    throw Exception('Нет данных файла для загрузки');
  }
  return client.storage.from(bucket).getPublicUrl(path);
}
