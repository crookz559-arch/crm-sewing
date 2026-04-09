import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task_model.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: taskAsync.when(
          data: (t) => Text(t.title),
          loading: () => const Text(''),
          error: (_, __) => const Text('Задача'),
        ),
        actions: [
          if (role.canCreateOrders)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/tasks/$taskId/edit'),
            ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (task) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status chips
            Text(l10n.orderStatus,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey600,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: TaskStatus.values
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _StatusChip(
                          status: s,
                          selected: task.status == s,
                          onTap: role.canCreateOrders
                              ? () => _changeStatus(context, ref, task, s)
                              : null,
                          l10n: l10n,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (task.assignedToName != null)
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: l10n.orderAssignee,
                        value: task.assignedToName!,
                      ),
                    if (task.deadline != null)
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: l10n.taskDeadline,
                        value: _formatDate(task.deadline!),
                        valueColor: task.isOverdue
                            ? AppColors.deadlineCritical
                            : null,
                      ),
                    _InfoRow(
                      icon: Icons.calendar_month_outlined,
                      label: l10n.createdAt,
                      value: _formatDate(task.createdAt),
                    ),
                  ],
                ),
              ),
            ),

            if (task.description != null &&
                task.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 16, color: AppColors.grey600),
                          const SizedBox(width: 6),
                          Text(l10n.orderDescription,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey600,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(task.description!),
                    ],
                  ),
                ),
              ),
            ],

            if (role.canCreateOrders) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () =>
                    _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(l10n.delete,
                    style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref,
      TaskModel task, TaskStatus newStatus) async {
    if (task.status == newStatus) return;
    try {
      await ref.read(tasksRepositoryProvider).changeStatus(task.id, newStatus);
      ref.invalidate(taskDetailProvider(taskId));
      ref.invalidate(tasksProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(tasksRepositoryProvider).deleteTask(taskId);
      ref.invalidate(tasksProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  final bool selected;
  final VoidCallback? onTap;
  final AppLocalizations l10n;
  const _StatusChip(
      {required this.status,
      required this.selected,
      required this.onTap,
      required this.l10n});

  String _label() {
    switch (status) {
      case TaskStatus.pending:
        return l10n.taskStatusPending;
      case TaskStatus.inProgress:
        return l10n.taskStatusInProgress;
      case TaskStatus.done:
        return l10n.taskStatusDone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
              color: selected ? c : AppColors.grey400, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 14, color: selected ? c : AppColors.grey600),
            const SizedBox(width: 4),
            Text(_label(),
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? c : AppColors.grey600,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grey600),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.grey600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: valueColor),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
