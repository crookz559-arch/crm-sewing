import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../features/users/presentation/users_screen.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task_model.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId;
  const TaskFormScreen({super.key, this.taskId});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _deadline;
  String? _assignedToId;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _prefill(TaskModel task) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = task.title;
    _descCtrl.text = task.description ?? '';
    setState(() {
      _deadline = task.deadline;
      _assignedToId = task.assignedToId;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: _deadline != null
          ? TimeOfDay(hour: _deadline!.hour, minute: _deadline!.minute)
          : TimeOfDay.now(),
    );
    setState(() {
      _deadline = DateTime(
        d.year, d.month, d.day,
        t?.hour ?? 0, t?.minute ?? 0,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      if (widget.taskId == null) {
        final id = await repo.createTask(
          title: _titleCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          deadline: _deadline,
          assignedTo: _assignedToId,
        );
        ref.invalidate(tasksProvider);
        if (mounted) context.pushReplacement('/tasks/$id');
      } else {
        await repo.updateTask(
          id: widget.taskId!,
          title: _titleCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          deadline: _deadline,
          assignedTo: _assignedToId,
        );
        ref.invalidate(tasksProvider);
        ref.invalidate(taskDetailProvider(widget.taskId!));
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.taskId != null;
    final usersAsync = ref.watch(usersListProvider);

    if (isEdit) {
      ref.watch(taskDetailProvider(widget.taskId!)).whenData(_prefill);
    }

    final users = usersAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.edit : l10n.taskNew),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.taskTitle,
                prefixIcon: const Icon(Icons.task_alt),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.orderDescription,
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            // Deadline picker
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.taskDeadline,
                  prefixIcon:
                      const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _deadline != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _deadline = null),
                        )
                      : null,
                ),
                child: Text(
                  _deadline != null
                      ? '${_deadline!.day.toString().padLeft(2, '0')}.${_deadline!.month.toString().padLeft(2, '0')}.${_deadline!.year}  ${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}'
                      : l10n.notSpecified,
                  style: TextStyle(
                    color: _deadline != null ? null : const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Assignee dropdown
            DropdownButtonFormField<String>(
              value: _assignedToId,
              decoration: InputDecoration(
                labelText: l10n.orderAssignee,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(l10n.notSpecified,
                        style: const TextStyle(
                            color: Color(0xFF9E9E9E)))),
                ...users.map((u) => DropdownMenuItem(
                      value: u['id'] as String,
                      child: Text(u['name'] as String? ?? ''),
                    )),
              ],
              onChanged: (v) => setState(() => _assignedToId = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
