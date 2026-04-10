import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task_model.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});
  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Material(
        color: Theme.of(context).colorScheme.surface,
        child: TabBar(controller: _tabCtrl, tabs: const [
          Tab(text: 'Активные'),
          Tab(icon: Icon(Icons.archive_outlined, size: 16), text: 'Архив'),
        ]),
      ),
      Expanded(child: TabBarView(controller: _tabCtrl, children: const [
        _ActiveTasksTab(), _ArchiveTasksTab(),
      ])),
    ]);
  }
}

final _archiveTasksProvider = FutureProvider.autoDispose<List<TaskModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('tasks').select('*, assignee:assigned_to(name)')
      .eq('status', 'done').order('updated_at', ascending: false);
  return (data as List).map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
});

class _ArchiveTasksTab extends ConsumerStatefulWidget {
  const _ArchiveTasksTab();
  @override
  ConsumerState<_ArchiveTasksTab> createState() => _ArchiveTasksTabState();
}

class _ArchiveTasksTabState extends ConsumerState<_ArchiveTasksTab> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    return ref.watch(_archiveTasksProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        final visible = list.where((t) => !_dismissed.contains(t.id)).toList();
        return visible.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.archive_outlined, size: 64, color: AppColors.grey400),
                SizedBox(height: 12),
                Text('Архив пуст', style: TextStyle(color: AppColors.grey600)),
              ]))
            : RefreshIndicator(
                onRefresh: () async {
                  setState(() => _dismissed.clear());
                  await ref.refresh(_archiveTasksProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final task = visible[i];
                    return Dismissible(
                      key: Key('archive_task_${task.id}'),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.red.shade600,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Row(children: [
                          Icon(Icons.delete_outline, color: Colors.white, size: 26),
                          SizedBox(width: 8),
                          Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить из архива?'),
                          content: Text('Задача "${task.title}" будет удалена безвозвратно.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                      onDismissed: (_) {
                        setState(() => _dismissed.add(task.id));
                        ref.read(tasksRepositoryProvider).deleteTask(task.id).catchError((_) {});
                        ref.invalidate(calendarDataProvider);
                        ref.invalidate(todayTasksProvider);
                      },
                      child: _TaskTile(task: task, onTap: () => context.push('/tasks/${task.id}')),
                    );
                  },
                ),
              );
      },
    );
  }
}

class _ActiveTasksTab extends ConsumerStatefulWidget {
  const _ActiveTasksTab();
  @override
  ConsumerState<_ActiveTasksTab> createState() => _ActiveTasksTabState();
}

class _ActiveTasksTabState extends ConsumerState<_ActiveTasksTab> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(taskFilterProvider);
    final tasks = ref.watch(tasksProvider);
    final myId = ref.watch(currentUserProvider).value?['id'] as String?;

    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _FChip(label: l10n.all, selected: filter.status == null && !filter.onlyMine,
                onTap: () => ref.read(taskFilterProvider.notifier).state = const TaskFilter()),
            const SizedBox(width: 8),
            _FChip(label: l10n.taskStatusPending, selected: filter.status == TaskStatus.pending,
                color: TaskStatus.pending.color,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    filter.copyWith(status: TaskStatus.pending, clearStatus: false)),
            const SizedBox(width: 8),
            _FChip(label: l10n.taskStatusInProgress, selected: filter.status == TaskStatus.inProgress,
                color: TaskStatus.inProgress.color,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    filter.copyWith(status: TaskStatus.inProgress)),
            if (myId != null) ...[
              const SizedBox(width: 8),
              _FChip(label: l10n.onlyMine, selected: filter.onlyMine,
                  onTap: () => ref.read(taskFilterProvider.notifier).state =
                      filter.copyWith(onlyMine: !filter.onlyMine)),
            ],
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: tasks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) {
            final active = list
                .where((t) => t.status != TaskStatus.done && !_dismissed.contains(t.id))
                .toList();
            if (active.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.task_alt, size: 64, color: AppColors.grey400),
                const SizedBox(height: 12),
                Text(l10n.noData, style: const TextStyle(color: AppColors.grey600)),
              ]));
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _dismissed.clear());
                await ref.refresh(tasksProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: active.length,
                itemBuilder: (_, i) {
                  final task = active[i];
                  return Dismissible(
                    key: Key('task_${task.id}'),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      color: Colors.red.shade600,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: const Row(children: [
                        Icon(Icons.delete_outline, color: Colors.white, size: 26),
                        SizedBox(width: 8),
                        Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить задачу?'),
                          content: Text('Задача "${task.title}" будет удалена без возможности восстановления.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    onDismissed: (_) {
                      setState(() => _dismissed.add(task.id));
                      ref.read(tasksRepositoryProvider).deleteTask(task.id).catchError((_) {});
                      ref.invalidate(calendarDataProvider);
                      ref.invalidate(todayTasksProvider);
                    },
                    child: _TaskTile(task: task, onTap: () => context.push('/tasks/${task.id}')),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _FChip extends StatelessWidget {
  final String label; final bool selected; final Color? color; final VoidCallback onTap;
  const _FChip({required this.label, required this.selected, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: selected ? c : AppColors.grey400, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: selected ? c : AppColors.grey600,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskModel task; final VoidCallback onTap;
  const _TaskTile({required this.task, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dc = task.isOverdue ? AppColors.deadlineCritical : null;
    return ListTile(
      onTap: onTap,
      leading: Icon(task.status.icon, color: task.status.color, size: 24),
      title: Text(task.title, style: TextStyle(fontWeight: FontWeight.w600,
        decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
        color: task.status == TaskStatus.done ? AppColors.grey600 : null)),
      subtitle: Row(children: [
        if (task.assignedToName != null) ...[
          const Icon(Icons.person_outline, size: 12, color: AppColors.grey600),
          const SizedBox(width: 3),
          Text(task.assignedToName!, style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
          const SizedBox(width: 10),
        ],
        if (task.deadline != null)
          Text(_fmtDt(task.deadline!), style: TextStyle(fontSize: 12,
              color: dc ?? AppColors.grey600, fontWeight: task.isOverdue ? FontWeight.w600 : null)),
      ]),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
    );
  }

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2,'0')}.${l.month.toString().padLeft(2,'0')}.${l.year} ${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
  }
}
