import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/user_role.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> data) {
    _nameCtrl.text = data['name'] ?? '';
    _phoneCtrl.text = data['phone'] ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser!.id;
      await client.from('users').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
      }).eq('id', uid);

      ref.invalidate(currentUserProvider);
      setState(() => _editing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.success),
            backgroundColor: AppColors.statusReady,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (file == null) return;

    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser!.id;
      final bytes = await file.readAsBytes();
      final path = '$uid/avatar.jpg';

      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: true),
          );

      final url = client.storage.from('avatars').getPublicUrl(path);
      await client.from('users').update({'avatar_url': url}).eq('id', uid);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'),
              backgroundColor: AppColors.statusRework),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userData = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  userData.whenData((d) => d != null ? _startEdit(d) : null),
            ),
        ],
      ),
      body: userData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data == null) return const SizedBox();
          return _buildBody(context, l10n, data, role);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n,
      Map<String, dynamic> data, UserRole role) {
    final name = data['name'] as String? ?? '';
    final phone = data['phone'] as String?;
    final email = ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
    final avatarUrl = data['avatar_url'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Аватар
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: _roleColor(role),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Роль
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _roleColor(role).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _roleLabel(role, l10n),
              style: TextStyle(
                  color: _roleColor(role),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),

          if (_editing) ...[
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.clientName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.clientPhone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(l10n.save),
                  ),
                ),
              ],
            ),
          ] else ...[
            _InfoTile(
                icon: Icons.person_outline, label: l10n.clientName, value: name),
            _InfoTile(
                icon: Icons.email_outlined, label: l10n.email, value: email),
            if (phone != null && phone.isNotEmpty)
              _InfoTile(
                  icon: Icons.phone_outlined,
                  label: l10n.clientPhone,
                  value: phone),
          ],
        ],
      ),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.grey600, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grey600)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
