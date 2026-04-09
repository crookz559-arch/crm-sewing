import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/order_status.dart';
import '../data/analytics_repository.dart';
import '../../export/export_service.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final year = ref.watch(analyticsYearProvider);
    final dataAsync = ref.watch(analyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year selector + export
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => ref
                    .read(analyticsYearProvider.notifier)
                    .state = year - 1,
              ),
              Text('$year',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: year < DateTime.now().year
                    ? () => ref
                        .read(analyticsYearProvider.notifier)
                        .state = year + 1
                    : null,
              ),
              const Spacer(),
              dataAsync.when(
                data: (data) => PopupMenuButton<String>(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: l10n.export,
                  onSelected: (v) => _export(context, ref, data, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'pdf',
                        child: Row(children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                              size: 18),
                          const SizedBox(width: 8),
                          Text('PDF')
                        ])),
                    PopupMenuItem(
                        value: 'excel',
                        child: Row(children: [
                          const Icon(Icons.table_chart_outlined,
                              size: 18),
                          const SizedBox(width: 8),
                          Text('Excel')
                        ])),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),

          dataAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: l10n.analyticsRevenue,
                        value:
                            '${_formatNum(data.totalRevenue)} ₽',
                        icon: Icons.monetization_on_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: l10n.analyticsOrders,
                        value: '${data.totalOrders}',
                        icon: Icons.assignment_outlined,
                        color: AppColors.statusAccepted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Monthly revenue bar chart
                Text(l10n.analyticsMonthly,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _BarChart(
                  data: data.monthlyRevenue
                      .map((m) => _BarData(
                            label: _shortMonth(m.month),
                            value: m.revenue,
                          ))
                      .toList(),
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),

                // Status distribution
                Text(l10n.analyticsStatus,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...data.statusStats.map((s) {
                  final status = OrderStatus.fromString(s.status);
                  final pct = data.totalOrders > 0
                      ? s.count / data.totalOrders
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: status.color,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(s.status,
                                    style: const TextStyle(
                                        fontSize: 13))),
                            Text('${s.count}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grey600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: pct,
                          backgroundColor:
                              AppColors.grey200,
                          valueColor: AlwaysStoppedAnimation(
                              status.color),
                          minHeight: 6,
                          borderRadius:
                              BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // Top clients
                if (data.topClients.isNotEmpty) ...[
                  Text(l10n.analyticsTopClients,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...data.topClients.take(5).map((c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary
                              .withValues(alpha: 0.12),
                          radius: 18,
                          child: Text(
                            c.clientName.isNotEmpty
                                ? c.clientName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.clientName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Text('${c.ordersCount} заказов',
                            style: const TextStyle(
                                fontSize: 12)),
                        trailing: Text(
                          '${_formatNum(c.revenue)} ₽',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _export(BuildContext context, WidgetRef ref,
      AnalyticsData data, String format) async {
    final year = ref.read(analyticsYearProvider);
    try {
      if (format == 'pdf') {
        await ExportService.exportAnalyticsPdf(data, year);
      } else {
        await ExportService.exportAnalyticsExcel(data, year);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл сохранён и отправлен')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static String _formatNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  static String _shortMonth(int m) {
    const months = [
      'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
    ];
    return months[m - 1];
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.grey600)),
          ],
        ),
      ),
    );
  }
}

class _BarData {
  final String label;
  final double value;
  const _BarData({required this.label, required this.value});
}

class _BarChart extends StatelessWidget {
  final List<_BarData> data;
  final Color color;
  const _BarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        data.fold<double>(0, (m, d) => d.value > m ? d.value : m);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data
            .map((d) => Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.value > 0)
                          Text(
                            _short(d.value),
                            style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.grey600),
                          ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: maxVal > 0
                              ? (d.value / maxVal * 120)
                                  .clamp(2, 120)
                              : 2,
                          decoration: BoxDecoration(
                            color: d.value > 0
                                ? color
                                : AppColors.grey200,
                            borderRadius:
                                const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(d.label,
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.grey600)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
