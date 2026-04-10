import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../features/users/presentation/users_screen.dart';
import '../../data/orders_repository.dart';
import '../../domain/order_model.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заказ?'),
        content: const Text('Заказ будет удалён безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ordersRepositoryProvider).deleteOrder(orderId);
      if (context.mounted) context.go('/orders');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
        actions: [
          if (role.canCreateOrders) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/orders/$orderId/edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Удалить заказ',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (order) => _OrderDetailBody(
          order: order,
          role: role,
          l10n: l10n,
          onRefresh: () {
            ref.invalidate(orderDetailProvider(orderId));
            ref.invalidate(orderHistoryProvider(orderId));
            ref.invalidate(orderNotesProvider(orderId));
            ref.invalidate(orderAttachmentsProvider(orderId));
          },
        ),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  final OrderModel order;
  final UserRole role;
  final AppLocalizations l10n;
  final VoidCallback onRefresh;

  const _OrderDetailBody({
    required this.order,
    required this.role,
    required this.l10n,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(orderHistoryProvider(order.id));
    final notesAsync = ref.watch(orderNotesProvider(order.id));
    final attachAsync = ref.watch(orderAttachmentsProvider(order.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title + status + doc icon ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (order.needsDocument)
                Tooltip(
                  message: 'Необходим закрывающий документ (АКТ/УПД)',
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.description_outlined,
                        size: 18, color: Colors.amber),
                  ),
                ),
              _StatusPill(status: order.status, l10n: l10n),
            ],
          ),
          if (order.needsDocument)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Требуется закрывающий документ: АКТ или УПД',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Main info ──────────────────────────────────────────────
          _InfoCard(children: [
            if (order.clientName != null)
              _InfoRow(
                  icon: Icons.person_outline,
                  label: l10n.orderClient,
                  value: order.clientName!),
            if (order.source != null)
              _InfoRow(
                  icon: Icons.source_outlined,
                  label: l10n.orderSource,
                  value: _sourceLabel(order.source!, l10n)),
            if (order.assigneeName != null)
              _InfoRow(
                  icon: Icons.engineering_outlined,
                  label: l10n.orderAssignee,
                  value: order.assigneeName!),
            if (order.deadline != null)
              _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.orderDeadline,
                  value: _formatDate(order.deadline!),
                  valueColor: _deadlineColor(order.deadlineState)),
          ]),

          // ── Financial section ──────────────────────────────────────
          if (role.canViewPrice) ...[
            const SizedBox(height: 12),
            _FinancialCard(order: order, onRefresh: onRefresh),
          ],

          if (order.description != null &&
              order.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(children: [
              _InfoRow(
                  icon: Icons.notes,
                  label: l10n.orderDescription,
                  value: order.description!),
            ]),
          ],

          // ── Status change ──────────────────────────────────────────
          if (role.canCreateOrders &&
              order.status != OrderStatus.closed) ...[
            const SizedBox(height: 16),
            _SectionHeader('Изменить статус'),
            const SizedBox(height: 8),
            _StatusSelector(
                order: order, l10n: l10n, onChanged: onRefresh),
          ],

          // ── Assignee ───────────────────────────────────────────────
          if (role.canAssign) ...[
            const SizedBox(height: 16),
            _SectionHeader('Исполнитель'),
            const SizedBox(height: 8),
            _AssigneeSelector(order: order, onChanged: onRefresh),
          ],

          // ── Notes ─────────────────────────────────────────────────
          const SizedBox(height: 20),
          _SectionHeader('Заметки'),
          const SizedBox(height: 8),
          notesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
            data: (notes) => _NotesSection(
              notes: notes,
              orderId: order.id,
              onAdded: () => ref.invalidate(orderNotesProvider(order.id)),
            ),
          ),

          // ── Attachments ────────────────────────────────────────────
          const SizedBox(height: 20),
          _SectionHeader('Файлы и фото'),
          const SizedBox(height: 8),
          attachAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
            data: (attachments) => _AttachmentsSection(
              attachments: attachments,
              orderId: order.id,
              onChanged: () =>
                  ref.invalidate(orderAttachmentsProvider(order.id)),
            ),
          ),

          // ── History ────────────────────────────────────────────────
          const SizedBox(height: 20),
          _SectionHeader('История статусов'),
          const SizedBox(height: 8),
          historyAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
            data: (history) => history.isEmpty
                ? const Text('Нет истории',
                    style: TextStyle(color: AppColors.grey600))
                : _HistoryTimeline(history: history, l10n: l10n),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _deadlineColor(DeadlineState state) {
    switch (state) {
      case DeadlineState.ok:
        return AppColors.deadlineOk;
      case DeadlineState.warning:
        return AppColors.deadlineWarn;
      case DeadlineState.critical:
      case DeadlineState.today:
      case DeadlineState.overdue:
        return AppColors.deadlineCritical;
      case DeadlineState.none:
        return AppColors.grey600;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _sourceLabel(String src, AppLocalizations l10n) {
    switch (src) {
      case 'whatsapp':
        return l10n.sourceWhatsApp;
      case 'instagram':
        return l10n.sourceInstagram;
      case 'website':
        return l10n.sourceWebsite;
      case 'personal':
        return l10n.sourcePersonal;
      case 'wholesale':
        return l10n.sourceWholesale;
      default:
        return src;
    }
  }
}

// ── Financial Card ────────────────────────────────────────────────────────────

class _FinancialCard extends ConsumerWidget {
  final OrderModel order;
  final VoidCallback onRefresh;
  const _FinancialCard({required this.order, required this.onRefresh});

  static const _financialStatuses = [
    ('unpaid', 'Не оплачен', Colors.red),
    ('prepaid', 'Предоплата', Colors.orange),
    ('paid', 'Оплачен', Colors.green),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = order.price ?? 0;
    final paid = order.paidAmount;
    final balance = order.balance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 18, color: AppColors.grey600),
                const SizedBox(width: 8),
                const Text('Финансы',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                // Financial status badge
                _FinancialStatusPicker(
                  current: order.financialStatus,
                  onChanged: (val) async {
                    await ref
                        .read(ordersRepositoryProvider)
                        .updateFinancialStatus(order.id, val);
                    ref.invalidate(ordersProvider);
                    onRefresh();
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            _FinRow(
              label: 'Стоимость заказа',
              value: _fmt(price),
              bold: true,
            ),
            const SizedBox(height: 8),
            _FinRow(
              label: 'Внесена оплата',
              value: _fmt(paid),
              color: paid > 0 ? Colors.green : null,
            ),
            const Divider(height: 16),
            _FinRow(
              label: 'Остаток к оплате',
              value: _fmt(balance),
              color: balance > 0
                  ? AppColors.deadlineCritical
                  : balance < 0
                      ? Colors.red
                      : Colors.green,
              bold: true,
            ),
            if (balance == 0 && price > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.check_circle,
                      size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Полностью оплачен',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₽';
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _FinRow(
      {required this.label,
      required this.value,
      this.color,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.grey600))),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color)),
      ],
    );
  }
}

class _FinancialStatusPicker extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;
  const _FinancialStatusPicker(
      {required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    switch (current) {
      case 'paid':
        color = Colors.green;
        label = 'Оплачен';
        icon = Icons.check_circle_outline;
      case 'prepaid':
        color = Colors.orange;
        label = 'Предоплата';
        icon = Icons.hourglass_bottom_outlined;
      default:
        color = AppColors.grey600;
        label = 'Не оплачен';
        icon = Icons.money_off_outlined;
    }

    return PopupMenuButton<String>(
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'unpaid',
            child: Text('Не оплачен')),
        const PopupMenuItem(
            value: 'prepaid',
            child: Text('Предоплата')),
        const PopupMenuItem(
            value: 'paid',
            child: Text('Оплачен')),
      ],
    );
  }
}

// ── Notes Section ─────────────────────────────────────────────────────────────

class _NotesSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> notes;
  final String orderId;
  final VoidCallback onAdded;
  const _NotesSection(
      {required this.notes,
      required this.orderId,
      required this.onAdded});

  @override
  ConsumerState<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<_NotesSection> {
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
          .read(ordersRepositoryProvider)
          .addNote(widget.orderId, text);
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
        if (widget.notes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Нет заметок',
                style:
                    TextStyle(color: AppColors.grey600, fontSize: 13)),
          )
        else
          ...widget.notes.map((n) {
            final author =
                (n['author'] as Map<String, dynamic>?)?['name']
                    as String?;
            final createdAt =
                DateTime.parse(n['created_at'] as String).toLocal();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (author != null)
                        Text(author,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grey600,
                                fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(_fmtDt(createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.grey600)),
                    ],
                  ),
                ],
              ),
            );
          }),
        // Add note input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Добавить заметку...',
                  isDense: true,
                  prefixIcon: Icon(Icons.edit_note, size: 18),
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

  String _fmtDt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Attachments Section ───────────────────────────────────────────────────────

class _AttachmentsSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> attachments;
  final String orderId;
  final VoidCallback onChanged;
  const _AttachmentsSection(
      {required this.attachments,
      required this.orderId,
      required this.onChanged});

  @override
  ConsumerState<_AttachmentsSection> createState() =>
      _AttachmentsSectionState();
}

class _AttachmentsSectionState
    extends ConsumerState<_AttachmentsSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _uploading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final path =
          'orders/${widget.orderId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await client.storage
          .from('order-files')
          .uploadBinary(path, bytes,
              fileOptions: FileOptions(contentType: 'image/$ext'));
      final url =
          client.storage.from('order-files').getPublicUrl(path);
      await ref
          .read(ordersRepositoryProvider)
          .addAttachment(widget.orderId, url, image.name, 'image');
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
                final fileType = a['file_type'] as String? ?? 'image';
                return GestureDetector(
                  onLongPress: () => _deleteAttachment(a['id'] as String),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: fileType == 'image'
                        ? Image.network(url,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover)
                        : Container(
                            width: 90,
                            height: 90,
                            color: AppColors.grey200,
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.attach_file,
                                    size: 32,
                                    color: AppColors.grey600),
                                const SizedBox(height: 4),
                                Text(
                                  a['file_name'] as String? ?? '',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.grey600),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickAndUpload,
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

  Future<void> _deleteAttachment(String id) async {
    final confirm = await showDialog<bool>(
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
    if (confirm == true) {
      await ref
          .read(ordersRepositoryProvider)
          .deleteAttachment(id);
      widget.onChanged();
    }
  }
}

// ── Status Selector (any direction allowed) ───────────────────────────────────

class _StatusSelector extends ConsumerWidget {
  final OrderModel order;
  final AppLocalizations l10n;
  final VoidCallback onChanged;

  const _StatusSelector(
      {required this.order, required this.l10n, required this.onChanged});

  static const _flow = [
    OrderStatus.newOrder,
    OrderStatus.accepted,
    OrderStatus.sewing,
    OrderStatus.quality,
    OrderStatus.ready,
    OrderStatus.delivery,
    OrderStatus.closed,
    OrderStatus.rework,
  ];

  // Any status is allowed except the current one
  bool _isAllowed(OrderStatus to) => to != order.status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _flow.map((s) => _buildChip(context, ref, s)).toList(),
    );
  }

  Widget _buildChip(BuildContext context, WidgetRef ref, OrderStatus s) {
    final isCurrent = order.status == s;
    final allowed = !isCurrent && _isAllowed(s);

    return GestureDetector(
      onTap: allowed ? () => _changeStatus(context, ref, s) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? s.color.withValues(alpha: 0.2)
              : allowed
                  ? AppColors.grey100
                  : AppColors.grey100.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isCurrent
                  ? s.color
                  : allowed
                      ? AppColors.grey200
                      : AppColors.grey200.withValues(alpha: 0.4),
              width: isCurrent ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon,
                size: 12,
                color: isCurrent
                    ? s.color
                    : allowed
                        ? AppColors.grey600
                        : AppColors.grey400),
            const SizedBox(width: 4),
            Text(_shortLabel(s, l10n),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isCurrent
                        ? s.color
                        : allowed
                            ? AppColors.grey600
                            : AppColors.grey400)),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, OrderStatus s) async {
    String? note;
    if (s == OrderStatus.ready) {
      note = 'Заказ готов. Необходимо оформить документы.';
    }
    try {
      await ref
          .read(ordersRepositoryProvider)
          .changeStatus(order.id, s, note: note);
      ref.invalidate(ordersProvider);
      onChanged();
      if (context.mounted && s == OrderStatus.ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Заказ готов! Не забудьте оформить документы (АКТ/УПД).'),
            backgroundColor: AppColors.statusReady,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: AppColors.statusRework),
        );
      }
    }
  }

  String _shortLabel(OrderStatus s, AppLocalizations l10n) {
    switch (s) {
      case OrderStatus.newOrder:
        return l10n.statusNew;
      case OrderStatus.accepted:
        return 'Принят';
      case OrderStatus.sewing:
        return 'Пошив';
      case OrderStatus.quality:
        return 'Проверка';
      case OrderStatus.ready:
        return 'Готов';
      case OrderStatus.delivery:
        return 'Курьер';
      case OrderStatus.closed:
        return 'Закрыт';
      case OrderStatus.rework:
        return 'Переделка';
    }
  }
}

// ── Assignee Selector ─────────────────────────────────────────────────────────

class _AssigneeSelector extends ConsumerWidget {
  final OrderModel order;
  final VoidCallback onChanged;
  const _AssigneeSelector({required this.order, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);

    return users.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox(),
      data: (list) {
        final current = order.assignedTo;
        return DropdownButtonFormField<String?>(
          value: current,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.engineering_outlined),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Не назначен',
                  style: TextStyle(color: AppColors.grey600)),
            ),
            ...list.map((u) => DropdownMenuItem(
                  value: u['id'] as String,
                  child: Text(u['name'] as String? ?? ''),
                )),
          ],
          onChanged: (val) async {
            await ref
                .read(ordersRepositoryProvider)
                .assignOrder(order.id, val);
            ref.invalidate(ordersProvider);
            onChanged();
          },
        );
      },
    );
  }
}

// ── History Timeline ──────────────────────────────────────────────────────────

class _HistoryTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final AppLocalizations l10n;
  const _HistoryTimeline({required this.history, required this.l10n});

  @override
  Widget build(BuildContext context) {
    // Deduplicate: remove consecutive same-status entries
    final deduped = <Map<String, dynamic>>[];
    for (final h in history) {
      if (deduped.isEmpty ||
          deduped.last['status'] != h['status']) {
        deduped.add(h);
      }
    }

    return Column(
      children: deduped.asMap().entries.map((entry) {
        final i = entry.key;
        final h = entry.value;
        final status =
            OrderStatus.fromString(h['status'] as String? ?? 'new');
        final changedBy =
            (h['changed_by_user'] as Map<String, dynamic>?)?['name']
                as String?;
        final createdAt =
            DateTime.parse(h['created_at'] as String).toLocal();
        final note = h['note'] as String?;
        final isLast = i == deduped.length - 1;

        return IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                            width: 2, color: AppColors.grey200),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  status.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusLabel(status, l10n),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: status.color,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDateTime(createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.grey600),
                          ),
                        ],
                      ),
                      if (changedBy != null) ...[
                        const SizedBox(height: 2),
                        Text(changedBy,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey600)),
                      ],
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(note,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey600,
                                fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _statusLabel(OrderStatus s, AppLocalizations l10n) {
    switch (s) {
      case OrderStatus.newOrder:
        return l10n.statusNew;
      case OrderStatus.accepted:
        return l10n.statusAccepted;
      case OrderStatus.sewing:
        return l10n.statusSewing;
      case OrderStatus.quality:
        return l10n.statusQuality;
      case OrderStatus.ready:
        return l10n.statusReady;
      case OrderStatus.delivery:
        return l10n.statusDelivery;
      case OrderStatus.closed:
        return l10n.statusClosed;
      case OrderStatus.rework:
        return l10n.statusRework;
    }
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

class _StatusPill extends StatelessWidget {
  final OrderStatus status;
  final AppLocalizations l10n;
  const _StatusPill({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Text(
            _label(status, l10n),
            style: TextStyle(
                fontSize: 12,
                color: status.color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _label(OrderStatus s, AppLocalizations l10n) {
    switch (s) {
      case OrderStatus.newOrder:
        return l10n.statusNew;
      case OrderStatus.accepted:
        return l10n.statusAccepted;
      case OrderStatus.sewing:
        return l10n.statusSewing;
      case OrderStatus.quality:
        return l10n.statusQuality;
      case OrderStatus.ready:
        return l10n.statusReady;
      case OrderStatus.delivery:
        return l10n.statusDelivery;
      case OrderStatus.closed:
        return l10n.statusClosed;
      case OrderStatus.rework:
        return l10n.statusRework;
    }
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          return Column(
            children: [
              e.value,
              if (e.key < children.length - 1)
                const Divider(height: 1, indent: 16),
            ],
          );
        }).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grey600),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grey600)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: valueColor)),
            ],
          ),
        ],
      ),
    );
  }
}
