import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';

class MonthPlan {
  final String? id;
  final int year;
  final int month;
  final double targetRevenue;
  final double factRevenue;

  const MonthPlan({
    this.id,
    required this.year,
    required this.month,
    required this.targetRevenue,
    required this.factRevenue,
  });

  double get progress =>
      targetRevenue > 0 ? (factRevenue / targetRevenue).clamp(0.0, 1.5) : 0;
  bool get isAhead => factRevenue >= targetRevenue;
  bool get isOnTrack =>
      factRevenue >= targetRevenue * 0.8 && factRevenue < targetRevenue;
}

final planMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final planProvider =
    FutureProvider.autoDispose<MonthPlan>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final month = ref.watch(planMonthProvider);

  // Get plan target
  final planData = await client
      .from('monthly_plans')
      .select()
      .eq('year', month.year)
      .eq('month', month.month)
      .maybeSingle();

  final target =
      (planData?['target_revenue'] as num?)?.toDouble() ?? 0;
  final planId = planData?['id'] as String?;

  // Get actual revenue for the month.
  // Суффикс Z обязателен: без него Supabase трактует строку как локальное
  // время сервера — заказы последнего дня месяца в вечернее время выпадали.
  final mm = month.month.toString().padLeft(2, '0');
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  final from = '${month.year}-$mm-01T00:00:00.000Z';
  final to   = '${month.year}-$mm-${lastDay}T23:59:59.999Z';

  final ordersData = await client
      .from('orders')
      .select('price')
      .eq('status', 'closed')
      .gte('created_at', from)
      .lte('created_at', to);

  final fact = (ordersData as List).fold<double>(
      0, (sum, o) => sum + ((o['price'] as num?)?.toDouble() ?? 0));

  return MonthPlan(
    id: planId,
    year: month.year,
    month: month.month,
    targetRevenue: target,
    factRevenue: fact,
  );
});

class PlanRepository {
  final Ref _ref;
  PlanRepository(this._ref);

  Future<void> setTarget({
    required int year,
    required int month,
    required double target,
    String? existingId,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw Exception('Сессия истекла. Войдите заново.');
    if (existingId != null) {
      await client
          .from('monthly_plans')
          .update({'target_revenue': target}).eq('id', existingId);
    } else {
      await client.from('monthly_plans').insert({
        'year': year,
        'month': month,
        'target_revenue': target,
        'created_by': uid,
      });
    }
  }
}

final planRepositoryProvider =
    Provider<PlanRepository>((ref) => PlanRepository(ref));
