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
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/user_role.dart';
import '../shell/main_shell.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const orderCreate = '/orders/create';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/:id';
  static const clients = '/clients';
  static const clientDetail = '/clients/:id';
  static const couriers = '/couriers';
  static const diary = '/diary';
  static const analytics = '/analytics';
  static const plan = '/plan';
  static const chat = '/chat';
  static const settings = '/settings';
  static const profile = '/profile';
  static const users = '/users';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && state.matchedLocation == AppRoutes.login) {
        return AppRoutes.orders;
      }
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
        path: AppRoutes.users,
        builder: (_, __) => const UsersScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:id/edit',
        builder: (_, state) =>
            OrderFormScreen(orderId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.orderCreate,
        builder: (_, __) => const OrderFormScreen(),
      ),
      GoRoute(
        path: '/clients/create',
        builder: (_, __) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (_, state) =>
            ClientDetailScreen(clientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (_, state) =>
            ClientFormScreen(clientId: state.pathParameters['id']),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.orders,
            builder: (_, __) => const OrdersListScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (_, __) => const TasksPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.clients,
            builder: (_, __) => const ClientsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.couriers,
            builder: (_, __) => const CouriersPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.diary,
            builder: (_, __) => const DiaryPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (_, __) => const AnalyticsPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.plan,
            builder: (_, __) => const PlanPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.chat,
            builder: (_, __) => const ChatPlaceholder(),
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
