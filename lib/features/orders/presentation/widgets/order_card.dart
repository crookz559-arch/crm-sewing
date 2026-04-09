import 'package:flutter/material.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_status.dart';
import '../../domain/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool showPrice;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.showPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final deadlineColor = _deadlineColor(order.deadlineState);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок + статус
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: order.status, l10n: l10n),
                ],
              ),
              const SizedBox(height: 8),

              // Клиент + исполнитель
              Row(
                children: [
                  if (order.clientName != null) ...[
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.grey600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        order.clientName!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.grey600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (order.assigneeName != null) ...[
                    const Icon(Icons.engineering_outlined,
                        size: 14, color: AppColors.grey600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        order.assigneeName!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.grey600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Дедлайн + цена
              Row(
                children: [
                  if (order.deadline != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: deadlineColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule,
                              size: 12, color: deadlineColor),
                          const SizedBox(width: 4),
                          Text(
                            _deadlineLabel(order, l10n),
                            style: TextStyle(
                                fontSize: 12,
                                color: deadlineColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (showPrice && order.price != null)
                    Text(
                      '${_formatPrice(order.price!)} ₽',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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
        return AppColors.grey400;
    }
  }

  String _deadlineLabel(OrderModel order, AppLocalizations l10n) {
    final days = order.daysUntilDeadline;
    if (days == null) return '';
    if (days < 0) return 'Просрочен ${days.abs()}д';
    if (days == 0) return 'Сегодня!';
    if (days == 1) return 'Завтра';
    return 'через ${days}д';
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}к';
    }
    return price.toStringAsFixed(0);
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final AppLocalizations l10n;
  const _StatusBadge({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status, l10n),
            style: TextStyle(
                fontSize: 11,
                color: status.color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

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
