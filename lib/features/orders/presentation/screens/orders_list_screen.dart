import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/orders_repository.dart';
import '../../domain/order_model.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';
import '../widgets/order_card.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final showPrice = role.canViewPrice;

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Активные'),
              Tab(icon: Icon(Icons.archive_outlined, size: 16), text: 'Архив'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _ActiveOrdersTab(
                showPrice: showPrice,
                showSearch: _showSearch,
                searchCtrl: _searchCtrl,
                onToggleSearch: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchCtrl.clear();
                    ref.read(orderFilterProvider.notifier).state =
                        ref.read(orderFilterProvider).copyWith(search: '');
                  }
                }),
                onSearchChanged: (val) => ref.read(orderFilterProvider.notifier).state =
                    ref.read(orderFilterProvider).copyWith(search: val),
              ),
              _ArchiveOrdersTab(showPrice: showPrice),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Archive provider ─────────────────────────────────────────────────────────

final _archiveOrdersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('orders')
      .select('*, clients(name), assignee:assigned_to(name)')
      .eq('status', 'closed')
      .order('updated_at', ascending: false);
  return (data as List).map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ─── Archive tab ─────────────────────────────────────────────────────────────

class _ArchiveOrdersTab extends ConsumerStatefulWidget {
  final bool showPrice;
  const _ArchiveOrdersTab({required this.showPrice});

  @override
  ConsumerState<_ArchiveOrdersTab> createState() => _ArchiveOrdersTabState();
}

class _ArchiveOrdersTabState extends ConsumerState<_ArchiveOrdersTab> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final archiveAsync = ref.watch(_archiveOrdersProvider);
    return archiveAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        final visible = list.where((o) => !_dismissed.contains(o.id)).toList();
        if (visible.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.archive_outlined, size: 64, color: AppColors.grey400),
              SizedBox(height: 12),
              Text('Архив пуст', style: TextStyle(color: AppColors.grey600)),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _dismissed.clear());
            await ref.refresh(_archiveOrdersProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: visible.length,
            itemBuilder: (ctx, i) {
              final order = visible[i];
              return Dismissible(
                key: Key('archive_order_${order.id}'),
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
                    content: Text('Заказ "${order.title}" будет удалён безвозвратно.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                onDismissed: (_) {
                  setState(() => _dismissed.add(order.id));
                  ref.read(ordersRepositoryProvider).deleteOrder(order.id).catchError((_) {});
                  ref.invalidate(calendarDataProvider);
                  ref.invalidate(priorityOrdersProvider);
                },
                child: OrderCard(order: order, showPrice: widget.showPrice, onTap: () => context.push('/orders/${order.id}')),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Active tab ───────────────────────────────────────────────────────────────

class _ActiveOrdersTab extends ConsumerStatefulWidget {
  final bool showPrice;
  final bool showSearch;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  const _ActiveOrdersTab({
    required this.showPrice,
    required this.showSearch,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onSearchChanged,
  });

  @override
  ConsumerState<_ActiveOrdersTab> createState() => _ActiveOrdersTabState();
}

class _ActiveOrdersTabState extends ConsumerState<_ActiveOrdersTab> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(orderFilterProvider);
    final orders = ref.watch(ordersProvider);

    return Column(
      children: [
        _FilterBar(
          showSearch: widget.showSearch,
          searchCtrl: widget.searchCtrl,
          filter: filter,
          l10n: l10n,
          onToggleSearch: widget.onToggleSearch,
          onSearchChanged: widget.onSearchChanged,
          onStatusChanged: (status) => ref.read(orderFilterProvider.notifier).state =
              filter.copyWith(status: status, clearStatus: status == null),
          onToggleMine: () => ref.read(orderFilterProvider.notifier).state =
              filter.copyWith(onlyMine: !filter.onlyMine),
        ),
        Expanded(
          child: orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: AppColors.statusRework, size: 48),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(ordersProvider),
                  child: const Text('Повторить'),
                ),
              ]),
            ),
            data: (list) {
              final active = list
                  .where((o) => o.status != OrderStatus.closed && !_dismissed.contains(o.id))
                  .toList();
              if (active.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.assignment_outlined, size: 64, color: AppColors.grey400),
                    const SizedBox(height: 12),
                    Text(l10n.noData, style: const TextStyle(color: AppColors.grey600)),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _dismissed.clear());
                  await ref.refresh(ordersProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: active.length,
                  itemBuilder: (ctx, i) {
                    final order = active[i];
                    return Dismissible(
                      key: Key('order_${order.id}'),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.red.shade600,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.white, size: 26),
                            SizedBox(width: 8),
                            Text('Удалить',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) => showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить заказ?'),
                            content: Text(
                                'Заказ "${order.title}" будет удалён без возможности восстановления.'),
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
                        ),
                      onDismissed: (_) {
                        setState(() => _dismissed.add(order.id));
                        ref.read(ordersRepositoryProvider)
                            .deleteOrder(order.id)
                            .catchError((_) {});
                        ref.invalidate(calendarDataProvider);
                        ref.invalidate(priorityOrdersProvider);
                      },
                      child: OrderCard(
                        order: order,
                        showPrice: widget.showPrice,
                        onTap: () => context.push('/orders/${order.id}'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

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
    required this.showSearch, required this.searchCtrl, required this.filter,
    required this.l10n, required this.onToggleSearch, required this.onSearchChanged,
    required this.onStatusChanged, required this.onToggleMine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: searchCtrl, autofocus: true, onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onToggleSearch),
                isDense: true,
              ),
            ),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _Chip(icon: Icons.search, selected: showSearch, onTap: onToggleSearch),
              const SizedBox(width: 6),
              _Chip(label: 'Мои', icon: Icons.person_outlined, selected: filter.onlyMine, onTap: onToggleMine),
              const SizedBox(width: 6),
              _Chip(label: 'Все', selected: filter.status == null, onTap: () => onStatusChanged(null)),
              const SizedBox(width: 6),
              for (final s in OrderStatus.values.where((s) => s != OrderStatus.closed)) ...[
                _StatusChip(status: s, selected: filter.status == s, l10n: l10n,
                    onTap: () => onStatusChanged(filter.status == s ? null : s)),
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

class _Chip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({this.label, this.icon, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? color : AppColors.grey200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) Icon(icon, size: 14, color: selected ? color : AppColors.grey600),
          if (icon != null && label != null) const SizedBox(width: 4),
          if (label != null) Text(label!, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: selected ? color : AppColors.grey600)),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  final bool selected;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _StatusChip({required this.status, required this.selected, required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? status.color.withValues(alpha: 0.2) : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? status.color : AppColors.grey200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 12, color: selected ? status.color : AppColors.grey600),
          const SizedBox(width: 4),
          Text(_label(status, l10n), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? status.color : AppColors.grey600)),
        ]),
      ),
    );
  }

  String _label(OrderStatus s, AppLocalizations l10n) => switch (s) {
    OrderStatus.newOrder  => l10n.statusNew,
    OrderStatus.accepted  => 'Принят',
    OrderStatus.sewing    => 'Пошив',
    OrderStatus.quality   => 'Проверка',
    OrderStatus.ready     => l10n.statusReady,
    OrderStatus.delivery  => 'Курьер',
    OrderStatus.closed    => l10n.statusClosed,
    OrderStatus.rework    => 'Переделка',
  };
}
