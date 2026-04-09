import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
        actions: [
          if (role.canCreateOrders)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/orders/$orderId/edit'),
            ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок + статус
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
              _StatusPill(status: order.status, l10n: l10n),
            ],
          ),
          const SizedBox(height: 16),

          // Основные поля
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
            if (role.canViewPrice && order.price != null)
              _InfoRow(
                  icon: Icons.attach_money,
                  label: l10n.orderPrice,
                  value: '${order.price!.toStringAsFixed(0)} ₽'),
          ]),

          if (order.description != null && order.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(children: [
              _InfoRow(
                  icon: Icons.notes,
                  label: l10n.orderDescription,
                  value: order.description!),
            ]),
          ],

          // Смена статуса (не для швей)
          if (role.canCreateOrders && order.status != OrderStatus.closed) ...[
            const SizedBox(height: 16),
            Text('Изменить статус',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _StatusSelector(
                order: order, l10n: l10n, onChanged: onRefresh),
          ],

          // Назначить исполнителя
          if (role.canAssign) ...[
            const SizedBox(height: 16),
            Text('Исполнитель',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _AssigneeSelector(order: order, onChanged: onRefresh),
          ],

          // История
          const SizedBox(height: 20),
          Text('История',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
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

// ─── Смена статуса ──────────────────────────────────────────────────────────

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
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._flow.map((s) => _buildChip(context, ref, s)),
        _buildChip(context, ref, OrderStatus.rework),
      ],
    );
  }

  Widget _buildChip(BuildContext context, WidgetRef ref, OrderStatus s) {
    final isCurrent = order.status == s;
    return GestureDetector(
      onTap: isCurrent
          ? null
          : () => _changeStatus(context, ref, s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? s.color.withValues(alpha: 0.2)
              : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isCurrent ? s.color : AppColors.grey200,
              width: isCurrent ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 12,
                color: isCurrent ? s.color : AppColors.grey600),
            const SizedBox(width: 4),
            Text(_shortLabel(s, l10n),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? s.color : AppColors.grey600)),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, OrderStatus s) async {
    String? note;

    // Для «готов» предлагаем добавить заметку о документах
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
            content: const Text('Заказ готов! Не забудьте оформить документы.'),
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

// ─── Назначение исполнителя ─────────────────────────────────────────────────

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

// ─── История ────────────────────────────────────────────────────────────────

class _HistoryTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final AppLocalizations l10n;
  const _HistoryTimeline({required this.history, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: history.asMap().entries.map((entry) {
        final i = entry.key;
        final h = entry.value;
        final status =
            OrderStatus.fromString(h['status'] as String? ?? 'new');
        final changedBy =
            (h['changed_by_user'] as Map<String, dynamic>?)?['name']
                as String?;
        final createdAt = DateTime.parse(h['created_at'] as String);
        final note = h['note'] as String?;
        final isLast = i == history.length - 1;

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
                        child: Container(width: 2, color: AppColors.grey200),
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
                              color: status.color.withValues(alpha: 0.15),
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

// ─── Вспомогательные виджеты ─────────────────────────────────────────────────

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
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
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
