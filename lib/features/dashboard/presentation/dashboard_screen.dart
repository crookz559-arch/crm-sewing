import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final dashboardMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// Selected day on calendar (null = no selection)
final _selectedDayProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

class _CalendarData {
  final Map<DateTime, List<Map<String, dynamic>>> ordersByDay;
  final Map<DateTime, List<Map<String, dynamic>>> tasksByDay;
  const _CalendarData(
      {required this.ordersByDay, required this.tasksByDay});

  int orderCount(DateTime day) => ordersByDay[day]?.length ?? 0;
  int taskCount(DateTime day) => tasksByDay[day]?.length ?? 0;
  List<Map<String, dynamic>> ordersOn(DateTime day) =>
      ordersByDay[day] ?? [];
  List<Map<String, dynamic>> tasksOn(DateTime day) =>
      tasksByDay[day] ?? [];
}

final calendarDataProvider =
    FutureProvider.autoDispose<_CalendarData>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    client
        .from('orders')
        .select('id, title, status, deadline, clients(name)')
        .not('deadline', 'is', null)
        .neq('status', 'closed'),
    client
        .from('tasks')
        .select('id, title, status, deadline')
        .not('deadline', 'is', null)
        .neq('status', 'done'),
  ]);

  final ordersByDay = <DateTime, List<Map<String, dynamic>>>{};
  for (final o in results[0] as List) {
    final m = o as Map<String, dynamic>;
    final raw = m['deadline'] as String?;
    if (raw == null) continue;
    final d = DateTime.parse(raw);
    final day = DateTime(d.year, d.month, d.day);
    ordersByDay.putIfAbsent(day, () => []).add(m);
  }

  final tasksByDay = <DateTime, List<Map<String, dynamic>>>{};
  for (final t in results[1] as List) {
    final m = t as Map<String, dynamic>;
    final raw = m['deadline'] as String?;
    if (raw == null) continue;
    final d = DateTime.parse(raw);
    final day = DateTime(d.year, d.month, d.day);
    tasksByDay.putIfAbsent(day, () => []).add(m);
  }

  return _CalendarData(ordersByDay: ordersByDay, tasksByDay: tasksByDay);
});

final priorityOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('orders')
      .select('id, title, status, deadline, clients(name)')
      .neq('status', 'closed');
  return List<Map<String, dynamic>>.from(data as List);
});

final todayTasksProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  // Convert local day boundaries to UTC for TIMESTAMPTZ comparison
  final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
  final data = await client
      .from('tasks')
      .select('id, title, status, deadline, assignee:assigned_to(name)')
      .gte('deadline', todayStart)
      .lte('deadline', todayEnd)
      .neq('status', 'done');
  return List<Map<String, dynamic>>.from(data as List);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final selectedDay = ref.watch(_selectedDayProvider);
    final calAsync = ref.watch(calendarDataProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(calendarDataProvider);
        ref.invalidate(priorityOrdersProvider);
        ref.invalidate(todayTasksProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmtToday(now),
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            const _MiniCalendar(),
            const SizedBox(height: 12),

            // If a day is selected, show its events inline
            if (selectedDay != null)
              calAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (data) => _DayEventsPanel(
                  day: selectedDay,
                  orders: data.ordersOn(selectedDay),
                  tasks: data.tasksOn(selectedDay),
                  onClose: () =>
                      ref.read(_selectedDayProvider.notifier).state = null,
                ),
              ),

            const SizedBox(height: 12),
            const _PriorityOrdersSection(),
            const SizedBox(height: 20),
            const _TodayTasksSection(),
          ],
        ),
      ),
    );
  }

  static String _fmtToday(DateTime d) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    const days = [
      'Понедельник', 'Вторник', 'Среда', 'Четверг',
      'Пятница', 'Суббота', 'Воскресенье'
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Day Events Panel ──────────────────────────────────────────────────────────

class _DayEventsPanel extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> tasks;
  final VoidCallback onClose;
  const _DayEventsPanel(
      {required this.day,
      required this.orders,
      required this.tasks,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final title = '${day.day} ${months[day.month - 1]}';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.grey600),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close,
                      size: 18, color: AppColors.grey600),
                ),
              ],
            ),
            if (orders.isEmpty && tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Нет событий',
                    style: TextStyle(color: AppColors.grey600, fontSize: 13)),
              ),
            if (orders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Заказы (${orders.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              ...orders.map((o) => _EventTile(
                    icon: Icons.assignment_outlined,
                    color: AppColors.primary,
                    title: o['title'] as String? ?? '',
                    subtitle:
                        (o['clients'] as Map?)?['name'] as String?,
                    onTap: () => context.push('/orders/${o['id']}'),
                  )),
            ],
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Задачи (${tasks.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              ...tasks.map((t) => _EventTile(
                    icon: Icons.task_alt,
                    color: Colors.orange,
                    title: t['title'] as String? ?? '',
                    onTap: () => context.push('/tasks/${t['id']}'),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _EventTile(
      {required this.icon,
      required this.color,
      required this.title,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle != null ? '$title · $subtitle' : title,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.grey600),
          ],
        ),
      ),
    );
  }
}

// ── Mini Calendar ─────────────────────────────────────────────────────────────

class _MiniCalendar extends ConsumerWidget {
  const _MiniCalendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardMonthProvider);
    final calAsync = ref.watch(calendarDataProvider);
    final selectedDay = ref.watch(_selectedDayProvider);
    final today = DateTime.now();

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startOffset = firstDay.weekday - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            // Month navigation
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ref.read(dashboardMonthProvider.notifier).state =
                          DateTime(month.year, month.month - 1, 1),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left,
                        size: 22, color: AppColors.grey600),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_monthName(month.month)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      ref.read(dashboardMonthProvider.notifier).state =
                          DateTime(month.year, month.month + 1, 1),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right,
                        size: 22, color: AppColors.grey600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Weekday headers
            Row(
              children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                  .map((d) => Expanded(
                        child: Text(d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grey600,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),

            // Grid
            calAsync.when(
              loading: () => const SizedBox(
                  height: 130,
                  child: Center(
                      child:
                          CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox(height: 8),
              data: (data) {
                final cells = <Widget>[];
                for (var i = 0; i < startOffset; i++) {
                  cells.add(const SizedBox());
                }
                for (var d = 1; d <= lastDay.day; d++) {
                  final date = DateTime(month.year, month.month, d);
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final isSelected = selectedDay != null &&
                      selectedDay.year == date.year &&
                      selectedDay.month == date.month &&
                      selectedDay.day == date.day;
                  final oc = data.orderCount(date);
                  final tc = data.taskCount(date);
                  final hasEvents = oc > 0 || tc > 0;

                  cells.add(_DayCell(
                    day: d,
                    isToday: isToday,
                    isSelected: isSelected,
                    orderCount: oc,
                    taskCount: tc,
                    onTap: hasEvents
                        ? () {
                            final current =
                                ref.read(_selectedDayProvider);
                            ref
                                .read(_selectedDayProvider.notifier)
                                .state = (current?.year == date.year &&
                                    current?.month == date.month &&
                                    current?.day == date.day)
                                ? null
                                : date;
                          }
                        : null,
                  ));
                }

                while (cells.length % 7 != 0) cells.add(const SizedBox());

                final rows = <Widget>[];
                for (var i = 0; i < cells.length; i += 7) {
                  rows.add(Row(
                    children: cells
                        .sublist(i, i + 7)
                        .map((c) => Expanded(child: c))
                        .toList(),
                  ));
                }
                return Column(children: rows);
              },
            ),
            const SizedBox(height: 8),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Заказы',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.grey600)),
                const SizedBox(width: 16),
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Задачи',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.grey600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int m) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[m - 1];
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final int orderCount;
  final int taskCount;
  final VoidCallback? onTap;
  const _DayCell(
      {required this.day,
      required this.isToday,
      required this.isSelected,
      required this.orderCount,
      required this.taskCount,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasEvents = orderCount > 0 || taskCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Day number circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              decoration: isSelected
                  ? BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: primary.withValues(alpha: 0.5), width: 2),
                    )
                  : isToday
                      ? BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        )
                      : hasEvents
                          ? BoxDecoration(
                              color: primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            )
                          : null,
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  color: (isToday || isSelected) ? Colors.white : null,
                  fontWeight: (isToday || isSelected || hasEvents)
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
            // Event dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (orderCount > 0)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2, right: 1),
                    decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                if (taskCount > 0)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Priority Orders ───────────────────────────────────────────────────────────

class _PriorityOrdersSection extends ConsumerWidget {
  const _PriorityOrdersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(priorityOrdersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: AppColors.deadlineWarn),
            const SizedBox(width: 8),
            const Text('Срочные заказы',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/orders'),
              child: const Text('Все →', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ordersAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
          error: (e, _) => Text('$e',
              style: const TextStyle(color: AppColors.statusRework)),
          data: (orders) {
            final now = DateTime.now();
            final sorted = List<Map<String, dynamic>>.from(orders);
            sorted.sort((a, b) {
              final da = a['deadline'] != null
                  ? DateTime.parse(a['deadline'] as String)
                  : null;
              final db = b['deadline'] != null
                  ? DateTime.parse(b['deadline'] as String)
                  : null;
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });
            final top = sorted.take(5).toList();
            if (top.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: Text('Нет активных заказов',
                        style: TextStyle(color: AppColors.grey600))),
              );
            }
            return Column(
                children: top.map((o) => _OrderRow(order: o, now: now)).toList());
          },
        ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final DateTime now;
  const _OrderRow({required this.order, required this.now});

  @override
  Widget build(BuildContext context) {
    final title = order['title'] as String? ?? '';
    final clientName =
        (order['clients'] as Map<String, dynamic>?)?['name'] as String?;
    final deadline = order['deadline'] != null
        ? DateTime.parse(order['deadline'] as String)
        : null;

    final Color urgencyColor;
    final String urgencyLabel;

    if (deadline == null) {
      urgencyColor = AppColors.grey400;
      urgencyLabel = 'Без срока';
    } else {
      final days =
          deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (days < 0) {
        urgencyColor = AppColors.deadlineCritical;
        urgencyLabel = 'Просрочен ${(-days)}д';
      } else if (days == 0) {
        urgencyColor = AppColors.deadlineCritical;
        urgencyLabel = 'Сегодня!';
      } else if (days == 1) {
        urgencyColor = AppColors.deadlineWarn;
        urgencyLabel = 'Завтра';
      } else if (days <= 3) {
        urgencyColor = AppColors.deadlineWarn;
        urgencyLabel = 'через ${days}д';
      } else {
        urgencyColor = AppColors.deadlineOk;
        urgencyLabel = 'через ${days}д';
      }
    }

    return InkWell(
      onTap: () => context.push('/orders/${order['id']}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (clientName != null)
                    Text(clientName,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(urgencyLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: urgencyColor,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today's Tasks ─────────────────────────────────────────────────────────────

class _TodayTasksSection extends ConsumerWidget {
  const _TodayTasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(todayTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.task_alt, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Задачи на сегодня',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/tasks'),
              child: const Text('Все →', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        tasksAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
          error: (e, _) => Text('$e',
              style: const TextStyle(color: AppColors.statusRework)),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.statusReady, size: 20),
                    SizedBox(width: 8),
                    Text('Задач на сегодня нет!',
                        style: TextStyle(color: AppColors.grey600)),
                  ],
                ),
              );
            }
            return Column(
                children: tasks.map((t) => _TaskRow(task: t)).toList());
          },
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final title = task['title'] as String? ?? '';
    final assignee =
        (task['assignee'] as Map<String, dynamic>?)?['name'] as String?;
    final deadline = task['deadline'] != null
        ? DateTime.parse(task['deadline'] as String).toLocal()
        : null;

    return InkWell(
      onTap: () => context.push('/tasks/${task['id']}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.circle, color: Colors.orange, size: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  if (assignee != null)
                    Text(assignee,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey600)),
                ],
              ),
            ),
            if (deadline != null)
              Text(
                '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.deadlineCritical,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
