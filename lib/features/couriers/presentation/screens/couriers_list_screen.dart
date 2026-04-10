import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/couriers_repository.dart';
import '../../domain/courier_model.dart';
import 'courier_log_form_screen.dart';

class CouriersListScreen extends ConsumerStatefulWidget {
  const CouriersListScreen({super.key});
  @override
  ConsumerState<CouriersListScreen> createState() => _CouriersListScreenState();
}

class _CouriersListScreenState extends ConsumerState<CouriersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);

    return Column(children: [
      Material(
        color: Theme.of(context).colorScheme.surface,
        child: Row(children: [
          Expanded(child: TabBar(controller: _tabCtrl, tabs: const [
            Tab(text: 'Текущие'),
            Tab(icon: Icon(Icons.archive_outlined, size: 16), text: 'Архив'),
          ])),
          if (role.canCreateOrders)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showForm(context),
              ),
            ),
        ]),
      ),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [
        _CouriersTab(isArchive: false),
        _CouriersTab(isArchive: true),
      ])),
    ]);
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const CourierLogFormScreen(),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _couriersArchiveProvider = FutureProvider.autoDispose<List<CourierModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final data = await client
      .from('courier_logs')
      .select('*, client:client_id(name)')
      .lt('delivery_date', cutoff.toIso8601String().split('T').first)
      .order('delivery_date', ascending: false);
  return (data as List).map((e) => CourierModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ─── Tab ──────────────────────────────────────────────────────────────────────

class _CouriersTab extends ConsumerWidget {
  final bool isArchive;
  const _CouriersTab({required this.isArchive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final filter = ref.watch(courierFilterProvider);

    if (isArchive) {
      final archiveAsync = ref.watch(_couriersArchiveProvider);
      return archiveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (logs) => logs.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.archive_outlined, size: 64, color: AppColors.grey400),
                SizedBox(height: 12),
                Text('Архив пуст', style: TextStyle(color: AppColors.grey600)),
              ]))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(_couriersArchiveProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: logs.length,
                  itemBuilder: (_, i) => _CourierTile(log: logs[i], onDelete: null),
                ),
              ),
      );
    }

    // Current tab: last 30 days
    final logsAsync = ref.watch(couriersProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          _DirChip(label: l10n.all, selected: filter == null, color: AppColors.primary,
              onTap: () => ref.read(courierFilterProvider.notifier).state = null),
          const SizedBox(width: 8),
          _DirChip(label: l10n.courierDirectionIn, selected: filter == 'in', color: AppColors.statusReady,
              onTap: () => ref.read(courierFilterProvider.notifier).state = 'in'),
          const SizedBox(width: 8),
          _DirChip(label: l10n.courierDirectionOut, selected: filter == 'out', color: AppColors.statusDelivery,
              onTap: () => ref.read(courierFilterProvider.notifier).state = 'out'),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (logs) {
            if (logs.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.grey400),
                const SizedBox(height: 12),
                Text(l10n.noData, style: const TextStyle(color: AppColors.grey600)),
              ]));
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(couriersProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: logs.length,
                itemBuilder: (_, i) => _CourierTile(
                  log: logs[i],
                  onDelete: role.canCreateOrders ? () => _delete(context, ref, logs[i].id) : null,
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(couriersRepositoryProvider).deleteLog(id);
    ref.invalidate(couriersProvider);
  }
}

class _DirChip extends StatelessWidget {
  final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _DirChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: selected ? color : AppColors.grey400, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: selected ? color : AppColors.grey600,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _CourierTile extends StatelessWidget {
  final CourierModel log; final VoidCallback? onDelete;
  const _CourierTile({required this.log, this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isIn = log.isInbound;
    final color = isIn ? AppColors.statusReady : AppColors.statusDelivery;
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20)),
      title: Text(log.description, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (log.clientName != null)
          Text(log.clientName!, style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
        Text(_fmt(log.deliveryDate), style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
      ]),
      trailing: onDelete != null
          ? IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey400), onPressed: onDelete)
          : null,
      isThreeLine: log.clientName != null,
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
}
