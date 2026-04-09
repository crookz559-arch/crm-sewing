import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/diary_repository.dart';
import '../../domain/diary_model.dart';

class DiaryListScreen extends ConsumerWidget {
  const DiaryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final month = ref.watch(diaryMonthProvider);
    final entriesAsync = ref.watch(diaryProvider);

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  ref.read(diaryMonthProvider.notifier).state =
                      DateTime(month.year, month.month - 1);
                },
              ),
              Text(
                _monthName(month),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(diaryMonthProvider.notifier).state =
                      DateTime(month.year, month.month + 1);
                },
              ),
            ],
          ),
        ),

        // Salary summary
        entriesAsync.when(
          data: (entries) {
            final total = entries.fold<double>(
                0, (sum, e) => sum + (e.salaryAmount ?? 0));
            final approved =
                entries.where((e) => e.isApproved).length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _SummaryChip(
                    label: l10n.diarySalary,
                    value: '${total.toStringAsFixed(0)} ₽',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: l10n.diaryApproved,
                    value: '$approved / ${entries.length}',
                    color: AppColors.statusReady,
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(height: 36),
          error: (_, __) => const SizedBox(height: 36),
        ),
        const Divider(height: 1),

        Expanded(
          child: entriesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.book_outlined,
                          size: 64, color: AppColors.grey400),
                      const SizedBox(height: 12),
                      Text(l10n.noData,
                          style: const TextStyle(
                              color: AppColors.grey600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/diary/create'),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.diaryNewEntry),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(diaryProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _DiaryTile(
                    entry: entries[i],
                    showSeamstress: role.canViewAnalytics,
                    onTap: () =>
                        context.push('/diary/${entries[i].id}'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _monthName(DateTime d) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: color)),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

class _DiaryTile extends StatelessWidget {
  final DiaryModel entry;
  final bool showSeamstress;
  final VoidCallback onTap;
  const _DiaryTile(
      {required this.entry,
      required this.showSeamstress,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Date block
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      entry.entryDate.day.toString(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    Text(
                      _shortMonth(entry.entryDate.month),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSeamstress && entry.seamstressName != null)
                      Text(entry.seamstressName!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.grey600)),
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.straighten,
                            size: 12, color: AppColors.grey600),
                        const SizedBox(width: 3),
                        Text('${entry.quantity} шт.',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey600)),
                        if (entry.photos.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.photo_library_outlined,
                              size: 12, color: AppColors.grey600),
                          const SizedBox(width: 3),
                          Text('${entry.photos.length}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.grey600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Salary + approval
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (entry.salaryAmount != null)
                    Text(
                      '${entry.salaryAmount!.toStringAsFixed(0)} ₽',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  const SizedBox(height: 4),
                  Icon(
                    entry.isApproved
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: entry.isApproved
                        ? AppColors.statusReady
                        : AppColors.grey400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortMonth(int m) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return months[m - 1];
  }
}
