import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/orders_repository.dart';
import '../widgets/order_card.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(orderFilterProvider);
    final showPrice = role.canViewPrice;

    return Column(
      children: [
        // Поиск + фильтры
        _FilterBar(
          showSearch: _showSearch,
          searchCtrl: _searchCtrl,
          filter: filter,
          l10n: l10n,
          onToggleSearch: () {
            setState(() => _showSearch = !_showSearch);
            if (!_showSearch) {
              _searchCtrl.clear();
              ref
                  .read(orderFilterProvider.notifier)
                  .state = filter.copyWith(search: '');
            }
          },
          onSearchChanged: (val) {
            ref.read(orderFilterProvider.notifier).state =
                filter.copyWith(search: val);
          },
          onStatusChanged: (status) {
            ref.read(orderFilterProvider.notifier).state =
                filter.copyWith(status: status, clearStatus: status == null);
          },
          onToggleMine: () {
            ref.read(orderFilterProvider.notifier).state =
                filter.copyWith(onlyMine: !filter.onlyMine);
          },
        ),

        // Список
        Expanded(
          child: orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.statusRework, size: 48),
                  const SizedBox(height: 8),
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(ordersProvider),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_outlined,
                          size: 64, color: AppColors.grey400),
                      const SizedBox(height: 12),
                      Text(l10n.noData,
                          style: const TextStyle(color: AppColors.grey600)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(ordersProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => OrderCard(
                    order: list[i],
                    showPrice: showPrice,
                    onTap: () =>
                        context.push('/orders/${list[i].id}'),
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

// ─── Панель фильтров ────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool showSearch;
  final TextEditingController searchCtrl;
  final OrderFilter filter;
  final AppLocalizations l10n;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<OrderStatus?> onStatusChanged;
  final VoidCallback onToggleMine;

  const _FilterBar({
    required this.showSearch,
    required this.searchCtrl,
    required this.filter,
    required this.l10n,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onToggleMine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Строка поиска
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: searchCtrl,
              autofocus: true,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onToggleSearch,
                ),
                isDense: true,
              ),
            ),
          ),

        // Горизонтальный скролл статусов
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              // Кнопка поиска
              _ChipButton(
                icon: Icons.search,
                selected: showSearch,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 6),

              // Только мои
              _ChipButton(
                label: 'Мои',
                icon: Icons.person_outlined,
                selected: filter.onlyMine,
                onTap: onToggleMine,
              ),
              const SizedBox(width: 6),

              // Все статусы
              _ChipButton(
                label: 'Все',
                selected: filter.status == null,
                onTap: () => onStatusChanged(null),
              ),
              const SizedBox(width: 6),

              // Статусы
              for (final s in OrderStatus.values) ...[
                _StatusChip(
                  status: s,
                  selected: filter.status == s,
                  l10n: l10n,
                  onTap: () =>
                      onStatusChanged(filter.status == s ? null : s),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.grey200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 14,
                  color: selected ? color : AppColors.grey600),
            if (icon != null && label != null) const SizedBox(width: 4),
            if (label != null)
              Text(label!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : AppColors.grey600)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  final bool selected;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _StatusChip({
    required this.status,
    required this.selected,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? status.color.withValues(alpha: 0.2)
              : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? status.color
                  : AppColors.grey200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon,
                size: 12,
                color: selected ? status.color : AppColors.grey600),
            const SizedBox(width: 4),
            Text(
              _label(status, l10n),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? status.color : AppColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  String _label(OrderStatus s, AppLocalizations l10n) {
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
        return l10n.statusReady;
      case OrderStatus.delivery:
        return 'Курьер';
      case OrderStatus.closed:
        return l10n.statusClosed;
      case OrderStatus.rework:
        return 'Переделка';
    }
  }
}
