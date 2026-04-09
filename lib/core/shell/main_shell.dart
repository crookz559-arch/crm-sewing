import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/user_role.dart';
import '../../shared/providers/auth_provider.dart';
import '../router/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;

    final items = _navItems(role, l10n);
    final selectedIndex = _selectedIndex(location, items);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(items[i].route),
        destinations: items
            .map((e) => NavigationDestination(
                  icon: Icon(e.icon),
                  selectedIcon: Icon(e.icon, color: Theme.of(context).colorScheme.primary),
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

  List<_NavItem> _navItems(UserRole role, AppLocalizations l10n) {
    final items = <_NavItem>[];

    items.add(_NavItem(AppRoutes.orders, Icons.assignment_outlined, l10n.navOrders));
    items.add(_NavItem(AppRoutes.tasks, Icons.task_alt, l10n.navTasks));
    items.add(_NavItem(AppRoutes.clients, Icons.people_outline, l10n.navClients));
    items.add(_NavItem(AppRoutes.couriers, Icons.local_shipping_outlined, l10n.navCouriers));

    if (role == UserRole.seamstress) {
      items.add(_NavItem(AppRoutes.diary, Icons.book_outlined, l10n.navDiary));
    }

    if (role.canViewAnalytics) {
      items.add(_NavItem(AppRoutes.analytics, Icons.bar_chart, l10n.navAnalytics));
      items.add(_NavItem(AppRoutes.plan, Icons.track_changes, l10n.navPlan));
    }

    items.add(_NavItem(AppRoutes.chat, Icons.chat_bubble_outline, l10n.navChat));

    return items;
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  const _NavItem(this.route, this.icon, this.label);
}
