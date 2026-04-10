import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';

class MonthlyRevenue {
  final int year;
  final int month;
  final double revenue;
  final int ordersCount;
  const MonthlyRevenue(
      {required this.year,
      required this.month,
      required this.revenue,
      required this.ordersCount});
}

class WeeklyRevenue {
  final int weekNumber;
  final DateTime weekStart;
  final double revenue;
  final int ordersCount;
  const WeeklyRevenue(
      {required this.weekNumber,
      required this.weekStart,
      required this.revenue,
      required this.ordersCount});
}

class StatusStat {
  final String status;
  final int count;
  const StatusStat({required this.status, required this.count});
}

class ClientStat {
  final String clientId;
  final String clientName;
  final double revenue;
  final int ordersCount;
  const ClientStat(
      {required this.clientId,
      required this.clientName,
      required this.revenue,
      required this.ordersCount});
}

class AnalyticsData {
  final List<MonthlyRevenue> monthlyRevenue;
  final List<WeeklyRevenue> weeklyRevenue;
  final List<StatusStat> statusStats;
  final List<ClientStat> topClients;
  final double totalRevenue;
  final int totalOrders;
  const AnalyticsData({
    required this.monthlyRevenue,
    required this.weeklyRevenue,
    required this.statusStats,
    required this.topClients,
    required this.totalRevenue,
    required this.totalOrders,
  });
}

// Year filter
final analyticsYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final analyticsProvider =
    FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final year = ref.watch(analyticsYearProvider);

  final from = '$year-01-01';
  // Use end-of-day so orders on Dec 31 (timestamptz) are included.
  final to = '$year-12-31T23:59:59.999';

  // Orders in year
  final ordersData = await client
      .from('orders')
      .select('id, status, price, created_at, client_id, clients(name)')
      .gte('created_at', from)
      .lte('created_at', to);

  final orders = List<Map<String, dynamic>>.from(ordersData as List);

  // Monthly revenue
  final monthMap = <int, MonthlyRevenue>{};
  for (var i = 1; i <= 12; i++) {
    monthMap[i] = MonthlyRevenue(
        year: year, month: i, revenue: 0, ordersCount: 0);
  }
  for (final o in orders) {
    final date = DateTime.parse(o['created_at'] as String);
    final price = (o['price'] as num?)?.toDouble() ?? 0;
    final existing = monthMap[date.month]!;
    monthMap[date.month] = MonthlyRevenue(
      year: year,
      month: date.month,
      revenue: existing.revenue + price,
      ordersCount: existing.ordersCount + 1,
    );
  }

  // Weekly revenue
  final weekMap = <int, WeeklyRevenue>{};
  for (final o in orders) {
    final date = DateTime.parse(o['created_at'] as String);
    final weekNum = _isoWeekNumber(date);
    final wStart = _weekStart(date);
    final price = (o['price'] as num?)?.toDouble() ?? 0;
    final existing = weekMap[weekNum];
    weekMap[weekNum] = WeeklyRevenue(
      weekNumber: weekNum,
      weekStart: existing?.weekStart ?? wStart,
      revenue: (existing?.revenue ?? 0) + price,
      ordersCount: (existing?.ordersCount ?? 0) + 1,
    );
  }

  // Status stats
  final statusCount = <String, int>{};
  for (final o in orders) {
    final s = o['status'] as String? ?? 'new';
    statusCount[s] = (statusCount[s] ?? 0) + 1;
  }
  final statusStats = statusCount.entries
      .map((e) => StatusStat(status: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  // Top clients
  final clientMap = <String, ClientStat>{};
  for (final o in orders) {
    final cid = o['client_id'] as String?;
    if (cid == null) continue;
    final cname =
        (o['clients'] as Map<String, dynamic>?)?['name'] as String? ??
            'Unknown';
    final price = (o['price'] as num?)?.toDouble() ?? 0;
    final existing = clientMap[cid];
    clientMap[cid] = ClientStat(
      clientId: cid,
      clientName: cname,
      revenue: (existing?.revenue ?? 0) + price,
      ordersCount: (existing?.ordersCount ?? 0) + 1,
    );
  }
  final topClients = clientMap.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  final totalRevenue = orders.fold<double>(
      0, (sum, o) => sum + ((o['price'] as num?)?.toDouble() ?? 0));

  return AnalyticsData(
    monthlyRevenue: monthMap.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month)),
    weeklyRevenue: weekMap.values.toList()
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber)),
    statusStats: statusStats,
    topClients: topClients.take(10).toList(),
    totalRevenue: totalRevenue,
    totalOrders: orders.length,
  );
});

/// Returns the correct ISO 8601 week number (1–53).
/// The original formula returned 0 for some early-January dates and 54 for
/// some late-December dates, creating phantom week bars in the analytics chart.
int _isoWeekNumber(DateTime date) {
  // The ISO week is identified by its Thursday.
  // Shift date to the Thursday of the same week (Mon=1 … Sun=7).
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  // Find the first Thursday of the year that thursday belongs to.
  final jan1 = DateTime(thursday.year, 1, 1);
  final daysToFirstThursday = (DateTime.thursday - jan1.weekday) % 7;
  final firstThursday = jan1.add(Duration(days: daysToFirstThursday));
  return (thursday.difference(firstThursday).inDays ~/ 7) + 1;
}

DateTime _weekStart(DateTime date) {
  final offset = date.weekday - 1;
  final d = date.subtract(Duration(days: offset));
  return DateTime(d.year, d.month, d.day);
}
