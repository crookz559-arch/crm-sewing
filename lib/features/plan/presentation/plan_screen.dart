import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/plan_repository.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final month = ref.watch(planMonthProvider);
    final planAsync = ref.watch(planProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(planMonthProvider.notifier).state =
                        DateTime(month.year, month.month - 1),
              ),
              Text(
                _monthName(month),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    ref.read(planMonthProvider.notifier).state =
                        DateTime(month.year, month.month + 1),
              ),
            ],
          ),
          const SizedBox(height: 8),

          planAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (plan) => Column(
              children: [
                // Gauge card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Progress bar
                        _PlanGauge(plan: plan),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _MetricTile(
                              label: l10n.planTarget,
                              value: plan.targetRevenue > 0
                                  ? '${_fmt(plan.targetRevenue)} ₽'
                                  : '—',
                              color: AppColors.grey600,
                            ),
                            _MetricTile(
                              label: l10n.planFact,
                              value: '${_fmt(plan.factRevenue)} ₽',
                              color: AppColors.statusReady,
                            ),
                            _MetricTile(
                              label: l10n.planDiff,
                              value: plan.targetRevenue > 0
                                  ? '${plan.factRevenue >= plan.targetRevenue ? '+' : ''}${_fmt(plan.factRevenue - plan.targetRevenue)} ₽'
                                  : '—',
                              color: plan.isAhead
                                  ? AppColors.planAhead
                                  : AppColors.planBehind,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Status label
                        if (plan.targetRevenue > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(plan)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(plan, l10n),
                              style: TextStyle(
                                  color: _statusColor(plan),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Set target (director/GM only)
                if (role.canViewAnalytics)
                  FilledButton.tonal(
                    onPressed: () => _showSetTargetDialog(
                        context, ref, plan),
                    child: Text(l10n.planSetTarget),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetTargetDialog(
      BuildContext context, WidgetRef ref, MonthPlan plan) async {
    final ctrl = TextEditingController(
        text: plan.targetRevenue > 0
            ? plan.targetRevenue.toStringAsFixed(0)
            : '');
    final month = ref.read(planMonthProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Установить план'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Цель (₽)', suffixText: '₽'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok != true) return;
    final target = double.tryParse(ctrl.text.trim());
    if (target == null || target <= 0) return;
    await ref.read(planRepositoryProvider).setTarget(
          year: month.year,
          month: month.month,
          target: target,
          existingId: plan.id,
        );
    ref.invalidate(planProvider);
  }

  static String _fmt(double v) {
    if (v.abs() >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  Color _statusColor(MonthPlan plan) {
    if (plan.isAhead) return AppColors.planAhead;
    if (plan.isOnTrack) return AppColors.planOnTrack;
    return AppColors.planBehind;
  }

  String _statusLabel(MonthPlan plan, AppLocalizations l10n) {
    if (plan.isAhead) return l10n.planAhead;
    if (plan.isOnTrack) return l10n.planOnTrack;
    return l10n.planBehind;
  }

  static String _monthName(DateTime d) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _PlanGauge extends StatelessWidget {
  final MonthPlan plan;
  const _PlanGauge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final progress =
        plan.targetRevenue > 0 ? plan.progress.clamp(0.0, 1.0) : 0.0;
    final color = plan.isAhead
        ? AppColors.planAhead
        : plan.isOnTrack
            ? AppColors.planOnTrack
            : AppColors.planBehind;

    return Column(
      children: [
        Text(
          plan.targetRevenue > 0
              ? '${(plan.progress * 100).toStringAsFixed(0)}%'
              : '—',
          style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: plan.targetRevenue > 0 ? color : AppColors.grey400),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.grey200,
            valueColor: AlwaysStoppedAnimation(
                plan.targetRevenue > 0 ? color : AppColors.grey400),
            minHeight: 16,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.grey600)),
      ],
    );
  }
}
