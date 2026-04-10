import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  void _navigate(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (user != null) {
          context.go(AppRoutes.dashboard);
        } else {
          context.go(AppRoutes.login);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigation is driven entirely by GoRouter's refreshListenable in app_router.dart.
    // The redirect function checks client.auth.currentUser synchronously and
    // redirects away from '/' as soon as auth state is known.
    // No manual navigation needed here — just show the loading splash.
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.content_cut, size: 72, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'CRM',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Швейный цех',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
