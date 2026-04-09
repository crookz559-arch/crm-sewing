import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/providers/auth_provider.dart';

// Провайдер списка сотрудников
final usersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('users')
      .select()
      .order('role')
      .order('name');
  return List<Map<String, dynamic>>.from(data as List);
});

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final users = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Сотрудники')),
      floatingActionButton: role.canAssign
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref, l10n),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Добавить'),
            )
          : null,
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline,
                      size: 64, color: AppColors.grey400),
                  const SizedBox(height: 12),
                  Text(l10n.noData,
                      style: const TextStyle(color: AppColors.grey600)),
                ],
              ),
            );
          }

          // Группируем по роли
          final grouped = <UserRole, List<Map<String, dynamic>>>{};
          for (final u in list) {
            final r = UserRole.fromString(u['role'] as String);
            grouped.putIfAbsent(r, () => []).add(u);
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(usersListProvider.future),
            child: ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  _RoleHeader(role: entry.key, l10n: l10n),
                  for (final user in entry.value)
                    _UserTile(
                      user: user,
                      role: entry.key,
                      canEdit: role.canAssign,
                      onToggleActive: () =>
                          _toggleActive(context, ref, user),
                      l10n: l10n,
                    ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref,
      Map<String, dynamic> user) async {
    final isActive = user['is_active'] as bool;
    final client = ref.read(supabaseClientProvider);
    await client
        .from('users')
        .update({'is_active': !isActive}).eq('id', user['id']);
    ref.invalidate(usersListProvider);
  }

  void _showCreateDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CreateUserSheet(
        onCreated: () => ref.invalidate(usersListProvider),
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  final UserRole role;
  final AppLocalizations l10n;
  const _RoleHeader({required this.role, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _roleColor(role),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _roleLabel(role, l10n).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _roleColor(role),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
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

  String _roleLabel(UserRole r, AppLocalizations l10n) {
    switch (r) {
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

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final UserRole role;
  final bool canEdit;
  final VoidCallback onToggleActive;
  final AppLocalizations l10n;
  const _UserTile({
    required this.user,
    required this.role,
    required this.canEdit,
    required this.onToggleActive,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? '';
    final phone = user['phone'] as String?;
    final isActive = user['is_active'] as bool? ?? true;
    final avatarUrl = user['avatar_url'] as String?;

    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor(role),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))
              : null,
        ),
        title: Text(name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isActive ? null : TextDecoration.lineThrough)),
        subtitle: phone != null && phone.isNotEmpty ? Text(phone) : null,
        trailing: canEdit
            ? Switch(
                value: isActive,
                onChanged: (_) => onToggleActive(),
                activeThumbColor: AppColors.statusReady,
              )
            : null,
      ),
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
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

class _CreateUserSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateUserSheet({required this.onCreated});

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.seamstress;
  String _selectedLang = 'ru';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions.invoke('create-user', body: {
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'name': _nameCtrl.text.trim(),
        'role': _selectedRole.toJson(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'language': _selectedLang,
      });

      if (response.status != 200) {
        final err = response.data?['error'] ?? 'Ошибка';
        setState(() => _error = err.toString());
        return;
      }

      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Новый сотрудник',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Имя', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Пароль', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Минимум 6 символов'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Телефон (необязательно)',
                    prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 12),
              // Роль
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                    labelText: 'Роль', prefixIcon: Icon(Icons.badge_outlined)),
                items: [
                  UserRole.director,
                  UserRole.headManager,
                  UserRole.manager,
                  UserRole.seamstress
                ]
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(r, l10n)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 12),
              // Язык
              DropdownButtonFormField<String>(
                value: _selectedLang,
                decoration: const InputDecoration(
                    labelText: 'Язык интерфейса',
                    prefixIcon: Icon(Icons.language)),
                items: [
                  DropdownMenuItem(value: 'ru', child: Text(l10n.langRu)),
                  DropdownMenuItem(value: 'uz', child: Text(l10n.langUz)),
                  DropdownMenuItem(value: 'ky', child: Text(l10n.langKy)),
                ],
                onChanged: (v) => setState(() => _selectedLang = v!),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusRework.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.statusRework)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Создать сотрудника'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole r, AppLocalizations l10n) {
    switch (r) {
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
