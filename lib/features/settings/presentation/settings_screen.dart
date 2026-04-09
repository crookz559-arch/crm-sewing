import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/user_role.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final role = ref.watch(currentRoleProvider);
    final userData = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          // Профиль
          userData.when(
            data: (data) => data == null
                ? const SizedBox()
                : _ProfileTile(data: data, role: role),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),

          const Divider(),

          // Язык
          _SectionHeader(title: l10n.language),
          _LanguageTile(
            label: l10n.langRu,
            code: 'ru',
            selected: locale.languageCode == 'ru',
            onTap: () => ref.read(localeProvider.notifier).setLocale('ru'),
          ),
          _LanguageTile(
            label: l10n.langUz,
            code: 'uz',
            selected: locale.languageCode == 'uz',
            onTap: () => ref.read(localeProvider.notifier).setLocale('uz'),
          ),
          _LanguageTile(
            label: l10n.langKy,
            code: 'ky',
            selected: locale.languageCode == 'ky',
            onTap: () => ref.read(localeProvider.notifier).setLocale('ky'),
          ),

          const Divider(),

          // Тема
          _SectionHeader(title: l10n.settingsTheme),
          _ThemeTile(
            label: l10n.settingsThemeLight,
            icon: Icons.light_mode_outlined,
            selected: themeMode == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
          ),
          _ThemeTile(
            label: l10n.settingsThemeDark,
            icon: Icons.dark_mode_outlined,
            selected: themeMode == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
          ),
          _ThemeTile(
            label: l10n.settingsThemeSystem,
            icon: Icons.brightness_auto_outlined,
            selected: themeMode == ThemeMode.system,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setTheme(ThemeMode.system),
          ),

          const Divider(),

          // Выход
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.statusRework),
            title: Text(
              l10n.logout,
              style: const TextStyle(color: AppColors.statusRework),
            ),
            onTap: () => _confirmLogout(context, ref, l10n),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'v1.0.0',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.grey400),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _confirmLogout(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logout),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            child: Text(
              l10n.logout,
              style: const TextStyle(color: AppColors.statusRework),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final UserRole role;
  const _ProfileTile({required this.data, required this.role});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final avatarUrl = data['avatar_url'] as String?;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _roleColor(role),
        backgroundImage:
            avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(_roleLabel(role, AppLocalizations.of(context)!)),
    );
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

  String _roleLabel(UserRole role, AppLocalizations l10n) {
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.grey600,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageTile(
      {required this.label,
      required this.code,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(
        _flag(code),
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }

  String _flag(String code) {
    switch (code) {
      case 'ru':
        return '🇷🇺';
      case 'uz':
        return '🇺🇿';
      case 'ky':
        return '🇰🇬';
      default:
        return '🌐';
    }
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
