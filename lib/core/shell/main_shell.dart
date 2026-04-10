import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/user_role.dart';
import '../../shared/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../router/app_router.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
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
    final name = userData.value?['name'] as String? ?? '';
    final avatarUrl = userData.value?['avatar_url'] as String?;
    final roleName = _roleName(role, l10n);

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
          // Уведомления с бейджем
          Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(unreadCountProvider);
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: _AppDrawer(
        items: items,
        location: location,
        name: name,
        roleName: roleName,
        avatarUrl: avatarUrl,
        roleColor: _roleColor(role),
        canViewAnalytics: role.canViewAnalytics,
      ),
      body: child,
    );
  }

  String _pageTitle(String location, AppLocalizations l10n) {
    if (location.startsWith(AppRoutes.dashboard)) return 'Главная';
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
    items.add(_NavItem(AppRoutes.dashboard, Icons.home_outlined, 'Главная'));
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

  String _roleName(UserRole role, AppLocalizations l10n) {
    switch (role) {
      case UserRole.director:
        return l10n.roleDirector;
      case UserRole.headManager:
        return l10n.roleHeadManager;
      case UserRole.manager:
        return l10n.roleManager;
      case UserRole.seamstress:
        return l10n.roleSeamstress;
    }
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

// ── Drawer ────────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  final List<_NavItem> items;
  final String location;
  final String name;
  final String roleName;
  final String? avatarUrl;
  final Color roleColor;
  final bool canViewAnalytics;

  const _AppDrawer({
    required this.items,
    required this.location,
    required this.name,
    required this.roleName,
    required this.avatarUrl,
    required this.roleColor,
    required this.canViewAnalytics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  roleColor.withValues(alpha: 0.85),
                  roleColor.withValues(alpha: 0.55),
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(roleName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
                // Profile button
                IconButton(
                  icon: const Icon(Icons.manage_accounts_outlined,
                      color: Colors.white70),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.profile);
                  },
                ),
              ],
            ),
          ),

          // ── Navigation items ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...items.map((item) {
                  final isSelected = location.startsWith(item.route);
                  return _DrawerTile(
                    item: item,
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item.route);
                    },
                  );
                }),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────
          const Divider(height: 1),
          if (canViewAnalytics)
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Сотрудники',
                  style: TextStyle(fontSize: 14)),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.users);
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.statusRework),
            title: const Text('Выйти',
                style: TextStyle(fontSize: 14, color: AppColors.statusRework)),
            dense: true,
            onTap: () async {
              Navigator.pop(context);
              await ref.read(supabaseClientProvider).auth.signOut();
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  const _DrawerTile(
      {required this.item,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: isSelected
          ? BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: ListTile(
        leading: Icon(
          item.icon,
          size: 22,
          color: isSelected ? primary : AppColors.grey600,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            color: isSelected ? primary : null,
          ),
        ),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  const _NavItem(this.route, this.icon, this.label);
}
