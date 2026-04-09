import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task_model.dart';

class TasksListScreen extends ConsumerWidget {
  const TasksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(taskFilterProvider);
    final tasks = ref.watch(tasksProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final myId = currentUser?['id'] as String?;

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _FilterChip(
                label: l10n.all,
                selected: filter.status == null && !filter.onlyMine,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    const TaskFilter(),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.taskStatusPending,
                selected: filter.status == TaskStatus.pending,
                color: TaskStatus.pending.color,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    filter.copyWith(status: TaskStatus.pending, clearStatus: false),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.taskStatusInProgress,
                selected: filter.status == TaskStatus.inProgress,
                color: TaskStatus.inProgress.color,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    filter.copyWith(status: TaskStatus.inProgress),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.taskStatusDone,
                selected: filter.status == TaskStatus.done,
                color: TaskStatus.done.color,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    filter.copyWith(status: TaskStatus.done),
              ),
              if (myId != null) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.onlyMine,
                  selected: filter.onlyMine,
                  onTap: () => ref.read(taskFilterProvider.notifier).state =
                      filter.copyWith(onlyMine: !filter.onlyMine),
                ),
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
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.task_alt,
                          size: 64, color: AppColors.grey400),
                      const SizedBox(height: 12),
                      Text(l10n.noData,
                          style:
                              const TextStyle(color: AppColors.grey600)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(tasksProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _TaskTile(
                    task: list[i],
                    onTap: () => context.push('/tasks/${list[i].id}'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
              color: selected ? c : AppColors.grey400, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: selected ? c : AppColors.grey600,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  const _TaskTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final deadlineColor = task.isOverdue ? AppColors.deadlineCritical : null;

    return ListTile(
      onTap: onTap,
      leading: Icon(task.status.icon, color: task.status.color, size: 24),
      title: Text(
        task.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: task.status == TaskStatus.done
              ? TextDecoration.lineThrough
              : null,
          color: task.status == TaskStatus.done ? AppColors.grey600 : null,
        ),
      ),
      subtitle: Row(
        children: [
          if (task.assignedToName != null) ...[
            const Icon(Icons.person_outline,
                size: 12, color: AppColors.grey600),
            const SizedBox(width: 3),
            Text(task.assignedToName!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.grey600)),
            const SizedBox(width: 10),
          ],
          if (task.deadline != null)
            Text(
              _formatDate(task.deadline!),
              style: TextStyle(
                  fontSize: 12,
                  color: deadlineColor ?? AppColors.grey600,
                  fontWeight: task.isOverdue ? FontWeight.w600 : null),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
