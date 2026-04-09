import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/diary_repository.dart';

class DiaryDetailScreen extends ConsumerWidget {
  final String entryId;
  const DiaryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final entryAsync = ref.watch(diaryDetailProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diaryTitle),
        actions: [
          entryAsync.when(
            data: (entry) {
              final isOwn = entry.seamstressId == currentUser?['id'];
              if (isOwn || role.canViewAnalytics) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/diary/$entryId/edit'),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entry) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          entry.entryDate.day.toString(),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.primary),
                        ),
                        Text(
                          _monthName(entry.entryDate.month),
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.seamstressName != null)
                          Text(entry.seamstressName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        Text('${entry.quantity} шт.',
                            style: const TextStyle(
                                color: AppColors.grey600)),
                      ],
                    ),
                  ),
                  if (entry.salaryAmount != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.salaryAmount!.toStringAsFixed(0)} ₽',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                        ),
                        Row(
                          children: [
                            Icon(
                              entry.isApproved
                                  ? Icons.check_circle
                                  : Icons.pending_outlined,
                              size: 14,
                              color: entry.isApproved
                                  ? AppColors.statusReady
                                  : AppColors.grey400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.isApproved
                                  ? l10n.diaryApproved
                                  : l10n.diaryPending,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: entry.isApproved
                                      ? AppColors.statusReady
                                      : AppColors.grey400),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 16, color: AppColors.grey600),
                          const SizedBox(width: 6),
                          Text(l10n.diaryDescription,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey600,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(entry.description),
                    ],
                  ),
                ),
              ),

              // Photos
              if (entry.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.diaryPhoto,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: entry.photos.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _showPhoto(context, entry.photos, i),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            entry.photos[i],
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Approve salary (director/head_manager only, if not already approved)
              if (role.canSetSalary && !entry.isApproved) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      _showApproveDialog(context, ref, entry),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.diaryApproveSalary),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showApproveDialog(
      BuildContext context, WidgetRef ref, dynamic entry) async {
    final ctrl = TextEditingController(
        text: entry.salaryAmount?.toStringAsFixed(0) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Утвердить ЗП'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Сумма (₽)', suffixText: '₽'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Утвердить')),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(ctrl.text.trim());
    if (amount == null) return;
    try {
      await ref
          .read(diaryRepositoryProvider)
          .approveSalary(id: entry.id, salaryAmount: amount);
      ref.invalidate(diaryDetailProvider(entryId));
      ref.invalidate(diaryProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _showPhoto(
      BuildContext context, List<String> photos, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(photos[index], fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return months[m - 1];
  }
}
