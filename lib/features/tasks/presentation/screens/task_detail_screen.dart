import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
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
        data: (task) => _TaskDetailBody(
          task: task,
          taskId: taskId,
          role: role,
          l10n: l10n,
          onRefresh: () {
            ref.invalidate(taskDetailProvider(taskId));
            ref.invalidate(tasksProvider);
            ref.invalidate(taskNotesProvider(taskId));
            ref.invalidate(taskAttachmentsProvider(taskId));
          },
        ),
      ),
    );
  }
}

class _TaskDetailBody extends ConsumerWidget {
  final TaskModel task;
  final String taskId;
  final dynamic role;
  final AppLocalizations l10n;
  final VoidCallback onRefresh;

  const _TaskDetailBody({
    required this.task,
    required this.taskId,
    required this.role,
    required this.l10n,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(taskNotesProvider(taskId));
    final attachAsync = ref.watch(taskAttachmentsProvider(taskId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status selector ──────────────────────────────────────
        Text(l10n.orderStatus,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.grey600,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TaskStatus.values
              .map((s) => _StatusChip(
                    status: s,
                    selected: task.status == s,
                    onTap: role.canCreateOrders
                        ? () => _changeStatus(context, ref, task, s)
                        : null,
                    l10n: l10n,
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),

        // ── Info card ─────────────────────────────────────────────
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
                    icon: Icons.schedule_outlined,
                    label: l10n.taskDeadline,
                    value: _formatDate(task.deadline!),
                    valueColor: task.isOverdue ? AppColors.deadlineCritical : null,
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

        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.description_outlined,
                        size: 16, color: AppColors.grey600),
                    const SizedBox(width: 6),
                    Text(l10n.orderDescription,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grey600,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 8),
                  Text(task.description!),
                ],
              ),
            ),
          ),
        ],

        // ── Timestamped notes log ─────────────────────────────────
        const SizedBox(height: 20),
        _SectionHeader('Журнал / Заметки'),
        const SizedBox(height: 8),
        notesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
          data: (notes) => _TaskNotesSection(
            notes: notes,
            taskId: taskId,
            onAdded: () => ref.invalidate(taskNotesProvider(taskId)),
          ),
        ),

        // ── Attachments ───────────────────────────────────────────
        const SizedBox(height: 20),
        _SectionHeader('Файлы и фото'),
        const SizedBox(height: 8),
        attachAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
          data: (attachments) => _TaskAttachmentsSection(
            attachments: attachments,
            taskId: taskId,
            onChanged: () =>
                ref.invalidate(taskAttachmentsProvider(taskId)),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref,
      TaskModel task, TaskStatus newStatus) async {
    if (task.status == newStatus) return;
    try {
      await ref
          .read(tasksRepositoryProvider)
          .changeStatus(task.id, newStatus);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'
      '  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Timestamped Notes Log ─────────────────────────────────────────────────────

class _TaskNotesSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> notes;
  final String taskId;
  final VoidCallback onAdded;
  const _TaskNotesSection(
      {required this.notes,
      required this.taskId,
      required this.onAdded});

  @override
  ConsumerState<_TaskNotesSection> createState() =>
      _TaskNotesSectionState();
}

class _TaskNotesSectionState extends ConsumerState<_TaskNotesSection> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryProvider)
          .addNote(widget.taskId, text);
      _ctrl.clear();
      widget.onAdded();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes timeline
        if (widget.notes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Нет записей в журнале',
                style: TextStyle(color: AppColors.grey600, fontSize: 13)),
          )
        else
          ...widget.notes.asMap().entries.map((entry) {
            final i = entry.key;
            final n = entry.value;
            final author =
                (n['author'] as Map<String, dynamic>?)?['name'] as String?;
            final createdAt =
                DateTime.parse(n['created_at'] as String).toLocal();
            final isLast = i == widget.notes.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 2),
                          child: Text(
                            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Center(
                              child: Container(
                                  width: 1.5,
                                  color: AppColors.grey200),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['content'] as String,
                                style: const TextStyle(fontSize: 13)),
                            if (author != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '$author · ${_fmtDate(createdAt)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.grey600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

        // Add note
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Добавить запись (09:00 — сделано то-то...)',
                  isDense: true,
                  prefixIcon:
                      Icon(Icons.add_comment_outlined, size: 18),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            _saving
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton.filled(
                    onPressed: _save,
                    icon: const Icon(Icons.send, size: 16),
                    style: IconButton.styleFrom(
                        minimumSize: const Size(36, 36)),
                  ),
          ],
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

// ── Attachments ───────────────────────────────────────────────────────────────

class _TaskAttachmentsSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> attachments;
  final String taskId;
  final VoidCallback onChanged;
  const _TaskAttachmentsSection(
      {required this.attachments,
      required this.taskId,
      required this.onChanged});

  @override
  ConsumerState<_TaskAttachmentsSection> createState() =>
      _TaskAttachmentsSectionState();
}

class _TaskAttachmentsSectionState
    extends ConsumerState<_TaskAttachmentsSection> {
  bool _uploading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _uploading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final path =
          'tasks/${widget.taskId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await client.storage.from('task-files').uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'));
      final url =
          client.storage.from('task-files').getPublicUrl(path);
      await ref
          .read(tasksRepositoryProvider)
          .addAttachment(widget.taskId, url, image.name, 'image');
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.attachments.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.attachments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = widget.attachments[i];
                final url = a['url'] as String;
                return GestureDetector(
                  onLongPress: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Удалить файл?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Отмена')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Удалить',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(tasksRepositoryProvider)
                          .deleteAttachment(a['id'] as String);
                      widget.onChanged();
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url,
                        width: 90, height: 90, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pick,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('Добавить фото / файл'),
        ),
        const SizedBox(height: 4),
        const Text('Удержите фото для удаления',
            style: TextStyle(fontSize: 11, color: AppColors.grey600)),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600));
  }
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
            Icon(status.icon,
                size: 14, color: selected ? c : AppColors.grey600),
            const SizedBox(width: 4),
            Text(_label(),
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? c : AppColors.grey600,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
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
