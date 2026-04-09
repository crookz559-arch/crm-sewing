import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Модель уведомления
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        relatedId: json['related_id'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// Notifier для уведомлений с Realtime
class NotificationsNotifier
    extends StateNotifier<List<AppNotification>> {
  final SupabaseClient _client;
  final String _userId;
  RealtimeChannel? _channel;

  NotificationsNotifier(this._client, this._userId) : super([]) {
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(50);
    state = (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _subscribe() {
    _channel = _client
        .channel('notifications_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (payload) {
            final n = AppNotification.fromJson(
                payload.newRecord as Map<String, dynamic>);
            state = [n, ...state];
          },
        )
        .subscribe();
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true}).eq('id', id);
    state = state
        .map((n) => n.id == id
            ? AppNotification(
                id: n.id,
                type: n.type,
                title: n.title,
                body: n.body,
                relatedId: n.relatedId,
                isRead: true,
                createdAt: n.createdAt,
              )
            : n)
        .toList();
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId)
        .eq('is_read', false);
    state = state
        .map((n) => AppNotification(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              relatedId: n.relatedId,
              isRead: true,
              createdAt: n.createdAt,
            ))
        .toList();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier,
    List<AppNotification>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId =
      client.auth.currentUser?.id ?? '';
  return NotificationsNotifier(client, userId);
});

final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.where((n) => !n.isRead).length;
});

// Screen
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifs = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifTitle),
        actions: [
          if (notifs.any((n) => !n.isRead))
            TextButton(
              onPressed: notifier.markAllRead,
              child: Text(l10n.notifMarkAllRead,
                  style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Text(l10n.noData,
                  style: const TextStyle(color: AppColors.grey600)))
          : ListView.builder(
              itemCount: notifs.length,
              itemBuilder: (_, i) {
                final n = notifs[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (n.isRead
                            ? AppColors.grey400
                            : AppColors.primary)
                        .withValues(alpha: 0.15),
                    child: Icon(
                      _iconFor(n.type),
                      size: 20,
                      color: n.isRead
                          ? AppColors.grey400
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(n.title,
                      style: TextStyle(
                          fontWeight: n.isRead
                              ? FontWeight.normal
                              : FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n.body != null)
                        Text(n.body!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey600)),
                      Text(_formatDate(n.createdAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.grey400)),
                    ],
                  ),
                  isThreeLine: n.body != null,
                  onTap: () {
                    notifier.markRead(n.id);
                    if (n.relatedId != null &&
                        n.type.contains('order')) {
                      context.push('/orders/${n.relatedId}');
                    } else if (n.relatedId != null &&
                        n.type.contains('task')) {
                      context.push('/tasks/${n.relatedId}');
                    }
                  },
                );
              },
            ),
    );
  }

  IconData _iconFor(String type) {
    if (type.contains('ready')) return Icons.check_circle_outline;
    if (type.contains('deadline')) return Icons.alarm;
    if (type.contains('assigned')) return Icons.assignment_ind_outlined;
    return Icons.notifications_outlined;
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
