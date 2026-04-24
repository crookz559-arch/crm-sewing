import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../domain/task_model.dart';

// Фильтр задач
class TaskFilter {
  final TaskStatus? status;
  final bool onlyMine;

  const TaskFilter({this.status, this.onlyMine = false});

  TaskFilter copyWith({TaskStatus? status, bool? onlyMine, bool clearStatus = false}) =>
      TaskFilter(
        status: clearStatus ? null : (status ?? this.status),
        onlyMine: onlyMine ?? this.onlyMine,
      );
}

final taskFilterProvider = StateProvider<TaskFilter>((ref) => const TaskFilter());

final tasksProvider = FutureProvider.autoDispose<List<TaskModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final filter = ref.watch(taskFilterProvider);
  final currentUser = ref.watch(currentUserProvider).value;

  var query = client
      .from('tasks')
      .select('*, assignee:assigned_to(name)');

  if (filter.status != null) {
    query = query.eq('status', filter.status!.toJson());
  }

  if (filter.onlyMine && currentUser != null) {
    query = query.eq('assigned_to', currentUser['id'] as String);
  }

  final data = await query
      .order('deadline', ascending: true, nullsFirst: false)
      .order('created_at', ascending: false);

  return (data as List)
      .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final taskDetailProvider =
    FutureProvider.autoDispose.family<TaskModel, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('tasks')
      .select('*, assignee:assigned_to(name)')
      .eq('id', id)
      .single();
  return TaskModel.fromJson(data as Map<String, dynamic>);
});

class TasksRepository {
  final Ref _ref;
  TasksRepository(this._ref);

  Future<String> createTask({
    required String title,
    String? description,
    String? orderId,
    DateTime? deadline,
    String? assignedTo,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id ?? '';
    final data = await client.from('tasks').insert({
      'title': title,
      'description': description,
      'order_id': orderId,
      'deadline': deadline?.toUtc().toIso8601String(),
      'assigned_to': assignedTo,
      'created_by': uid,
      'status': 'pending',
    }).select().single();
    return (data as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updateTask({
    required String id,
    required String title,
    String? description,
    String? orderId,
    DateTime? deadline,
    String? assignedTo,
    // Явные флаги очистки — не затираем поля, которые пользователь не трогал.
    bool clearDeadline = false,
    bool clearAssignee = false,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('tasks').update({
      'title': title,
      if (description != null) 'description': description,
      if (orderId != null) 'order_id': orderId,
      if (deadline != null || clearDeadline)
        'deadline': deadline?.toUtc().toIso8601String(),
      if (assignedTo != null || clearAssignee) 'assigned_to': assignedTo,
      // updated_at обновляем вручную на случай если триггер в БД не настроен.
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> changeStatus(String id, TaskStatus status) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('tasks').update({
      'status': status.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('tasks').delete().eq('id', id);
  }
}

final tasksRepositoryProvider =
    Provider<TasksRepository>((ref) => TasksRepository(ref));

// Task notes provider
final taskNotesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, taskId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('task_notes')
      .select('*, author:user_id(name)')
      .eq('task_id', taskId)
      .order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(data as List);
});

// Task attachments provider
final taskAttachmentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, taskId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('task_attachments')
      .select('*')
      .eq('task_id', taskId)
      .order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(data as List);
});

extension TasksRepositoryNotes on TasksRepository {
  Future<void> addNote(String taskId, String content) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('task_notes').insert({
      'task_id': taskId,
      'content': content,
      'user_id': client.auth.currentUser?.id ?? '',
    });
  }

  Future<void> addAttachment(
      String taskId, String url, String fileName, String fileType) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('task_attachments').insert({
      'task_id': taskId,
      'url': url,
      'file_name': fileName,
      'file_type': fileType,
      'uploaded_by': client.auth.currentUser?.id ?? '',
    });
  }

  Future<void> deleteAttachment(String attachmentId) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('task_attachments')
        .delete()
        .eq('id', attachmentId);
  }
}
