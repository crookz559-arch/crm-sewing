import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/orders/presentation/screens/orders_list_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_form_screen.dart';
import '../../features/clients/presentation/screens/clients_list_screen.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/clients/presentation/screens/client_form_screen.dart';
import '../../features/tasks/presentation/screens/tasks_list_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../features/tasks/presentation/screens/task_form_screen.dart';
import '../../features/diary/presentation/screens/diary_list_screen.dart';
import '../../features/diary/presentation/screens/diary_detail_screen.dart';
import '../../features/diary/presentation/screens/diary_entry_form_screen.dart';
import '../../features/couriers/presentation/screens/couriers_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/direct_message_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/user_role.dart';
import '../shell/main_shell.dart';

// Notifier that wakes GoRouter's redirect whenever the auth stream fires.
// Using this instead of ref.watch means the GoRouter object is created ONCE —
// token refreshes no longer reset the navigation stack.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const orderCreate = '/orders/create';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/:id';
  static const clients = '/clients';
  static const clientDetail = '/clients/:id';
  static const couriers = '/couriers';
  static const diary = '/diary';
  static const notifications = '/notifications';
  static const analytics = '/analytics';
  static const plan = '/plan';
  static const chat = '/chat';
  static const settings = '/settings';
  static const profile = '/profile';
  static const users = '/users';
}

final routerProvider = Provider<GoRouter>((ref) {
  // ref.READ (not watch) — GoRouter is created exactly once per app lifetime.
  final client = ref.read(supabaseClientProvider);

  final refreshNotifier = _GoRouterRefreshNotifier(
    client.auth.onAuthStateChange,
  );
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // client.auth.currentUser is synchronous — no AsyncLoading ambiguity.
      final isLoggedIn = client.auth.currentUser != null;
      final loc = state.matchedLocation;
      final isOnSplash = loc == AppRoutes.splash;
      final isOnLogin = loc == AppRoutes.login;

      // Always redirect away from splash immediately.
      if (isOnSplash) {
        return isLoggedIn ? AppRoutes.dashboard : AppRoutes.login;
      }
      if (!isLoggedIn && !isOnLogin) return AppRoutes.login;
      if (isLoggedIn && isOnLogin) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      // Экраны без нижней навигации
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.users,
        builder: (_, __) => const UsersScreen(),
      ),
      // ── static «/create» must come BEFORE «/:id» ──
      GoRoute(
        path: AppRoutes.orderCreate,
        builder: (_, __) => const OrderFormScreen(),
      ),
      GoRoute(
        path: '/orders/:id/edit',
        builder: (_, state) =>
            OrderFormScreen(orderId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clients/create',
        builder: (_, __) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (_, state) =>
            ClientFormScreen(clientId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (_, state) =>
            ClientDetailScreen(clientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tasks/create',
        builder: (_, __) => const TaskFormScreen(),
      ),
      GoRoute(
        path: '/tasks/:id/edit',
        builder: (_, state) =>
            TaskFormScreen(taskId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (_, state) =>
            TaskDetailScreen(taskId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/diary/create',
        builder: (_, __) => const DiaryEntryFormScreen(),
      ),
      GoRoute(
        path: '/diary/:id/edit',
        builder: (_, state) =>
            DiaryEntryFormScreen(entryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/diary/:id',
        builder: (_, state) =>
            DiaryDetailScreen(entryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/dm/:userId',
        builder: (_, state) =>
            DirectMessageScreen(otherUserId: state.pathParameters['userId']!),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.orders,
            builder: (_, __) => const OrdersListScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (_, __) => const TasksListScreen(),
          ),
          GoRoute(
            path: AppRoutes.clients,
            builder: (_, __) => const ClientsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.couriers,
            builder: (_, __) => const CouriersListScreen(),
          ),
          GoRoute(
            path: AppRoutes.diary,
            builder: (_, __) => const DiaryListScreen(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (_, __) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.plan,
            builder: (_, __) => const PlanScreen(),
          ),
          GoRoute(
            path: AppRoutes.chat,
            builder: (_, __) => const ChatScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// Placeholder-экраны — будут заменены в следующих этапах
class OrdersPlaceholder extends StatelessWidget {
  const OrdersPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Заказы — этап 3'));
}

class TasksPlaceholder extends StatelessWidget {
  const TasksPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Задачи — этап 5'));
}

class ClientsPlaceholder extends StatelessWidget {
  const ClientsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Клиенты — этап 4'));
}

class CouriersPlaceholder extends StatelessWidget {
  const CouriersPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Курьеры — этап 6'));
}

class DiaryPlaceholder extends StatelessWidget {
  const DiaryPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Дневник — этап 5'));
}

class AnalyticsPlaceholder extends StatelessWidget {
  const AnalyticsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Аналитика — этап 7'));
}

class PlanPlaceholder extends StatelessWidget {
  const PlanPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('План — этап 7'));
}

class ChatPlaceholder extends StatelessWidget {
  const ChatPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Чат — этап 6'));
}
