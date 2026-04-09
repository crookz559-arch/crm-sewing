import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/auth_provider.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String content;
  final String? replyToId;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.content,
    this.replyToId,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: user?['name'] as String?,
      userAvatarUrl: user?['avatar_url'] as String?,
      content: json['content'] as String,
      replyToId: json['reply_to'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Notifier that holds messages and manages realtime subscription
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
        .select('*, user:user_id(name, avatar_url)')
        .order('created_at', ascending: true)
        .limit(200);
    state = (data as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _subscribe() {
    _channel = _client
        .channel('chat_messages_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) async {
            final row = payload.newRecord;
            // Fetch full row with user join
            try {
              final data = await _client
                  .from('chat_messages')
                  .select('*, user:user_id(name, avatar_url)')
                  .eq('id', row['id'] as String)
                  .single();
              final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
              state = [...state, msg];
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String content, {String? replyTo}) async {
    await _client.from('chat_messages').insert({
      'user_id': _client.auth.currentUser!.id,
      'content': content,
      if (replyTo != null) 'reply_to': replyTo,
    });
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
