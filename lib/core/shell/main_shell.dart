import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/user_role.dart';
import '../../shared/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../router/app_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final userData = ref.watch(currentUserProvider);

    final items = _navItems(role, l10n);
    final selectedIndex = _selectedIndex(location, items);

    final name = userData.value?['name'] as String? ?? '';
    final avatarUrl = userData.value?['avatar_url'] as String?;

    final isOrdersTab = location == AppRoutes.orders;
    final isTasksTab = location == AppRoutes.tasks;
    final isDiaryTab = location == AppRoutes.diary;

    VoidCallback? fabAction;
    if (isOrdersTab && role.canCreateOrders) {
      fabAction = () => context.push(AppRoutes.orderCreate);
    } else if (isTasksTab && role.canCreateOrders) {
      fabAction = () => context.push('/tasks/create');
    } else if (isDiaryTab) {
      fabAction = () => context.push('/diary/create');
    }

    return Scaffold(
      floatingActionButton: fabAction != null
          ? FloatingActionButton(
              onPressed: fabAction,
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(_pageTitle(location, l10n)),
        actions: [
          // Сотрудники — только директор и ГМ
          if (role.canViewAnalytics)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Сотрудники',
              onPressed: () => context.push(AppRoutes.users),
            ),
          // Аватар / профиль
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _roleColor(role),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(items[i].route),
        destinations: items
            .map((e) => NavigationDestination(
                  icon: Icon(e.icon),
                  selectedIcon: Icon(e.icon,
                      color: Theme.of(context).colorScheme.primary),
                  label: e.label,
                ))
            .toList(),
      ),
    );
  }

  int _selectedIndex(String location, List<_NavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) return i;
    }
    return 0;
  }

  String _pageTitle(String location, AppLocalizations l10n) {
    if (location.startsWith(AppRoutes.orders)) return l10n.navOrders;
    if (location.startsWith(AppRoutes.tasks)) return l10n.navTasks;
    if (location.startsWith(AppRoutes.clients)) return l10n.navClients;
    if (location.startsWith(AppRoutes.couriers)) return l10n.navCouriers;
    if (location.startsWith(AppRoutes.diary)) return l10n.navDiary;
    if (location.startsWith(AppRoutes.analytics)) return l10n.analyticsTitle;
    if (location.startsWith(AppRoutes.plan)) return l10n.planTitle;
    if (location.startsWith(AppRoutes.chat)) return l10n.navChat;
    if (location.startsWith(AppRoutes.settings)) return l10n.settingsTitle;
    return l10n.appName;
  }

  List<_NavItem> _navItems(UserRole role, AppLocalizations l10n) {
    final items = <_NavItem>[];

    items.add(_NavItem(AppRoutes.orders, Icons.assignment_outlined, l10n.navOrders));
    items.add(_NavItem(AppRoutes.tasks, Icons.task_alt, l10n.navTasks));

    if (role != UserRole.seamstress) {
      items.add(_NavItem(AppRoutes.clients, Icons.people_outline, l10n.navClients));
      items.add(_NavItem(AppRoutes.couriers, Icons.local_shipping_outlined, l10n.navCouriers));
    }

    if (role == UserRole.seamstress) {
      items.add(_NavItem(AppRoutes.diary, Icons.book_outlined, l10n.navDiary));
    }

    if (role.canViewAnalytics) {
      items.add(_NavItem(AppRoutes.analytics, Icons.bar_chart, l10n.navAnalytics));
      items.add(_NavItem(AppRoutes.plan, Icons.track_changes, l10n.navPlan));
    }

    items.add(_NavItem(AppRoutes.chat, Icons.chat_bubble_outline, l10n.navChat));
    items.add(_NavItem(AppRoutes.settings, Icons.settings_outlined, l10n.settingsTitle));

    return items;
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.director:
        return AppColors.roleDirector;
      case UserRole.headManager:
        return AppColors.roleHeadManager;
      case UserRole.manager:
        return AppColors.roleManager;
      case UserRole.seamstress:
        return AppColors.roleSeamstress;
    }
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  const _NavItem(this.route, this.icon, this.label);
}
