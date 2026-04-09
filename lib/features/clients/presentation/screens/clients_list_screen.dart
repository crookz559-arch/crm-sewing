import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/clients_repository.dart';
import '../../domain/client_model.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final clients = ref.watch(clientsProvider);

    return Column(
      children: [
        // Поиск
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) =>
                  ref.read(clientSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() => _showSearch = false);
                    _searchCtrl.clear();
                    ref.read(clientSearchProvider.notifier).state = '';
                  },
                ),
                isDense: true,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    clients.when(
                      data: (l) => '${l.length} клиентов',
                      loading: () => '',
                      error: (_, __) => '',
                    ),
                    style: const TextStyle(
                        color: AppColors.grey600, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () => setState(() => _showSearch = true),
                ),
                if (role.canCreateOrders)
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined, size: 20),
                    onPressed: () => context.push('/clients/create'),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),

        Expanded(
          child: clients.when(
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
                          style:
                              const TextStyle(color: AppColors.grey600)),
                      if (role.canCreateOrders) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/clients/create'),
                          icon: const Icon(Icons.person_add_outlined),
                          label: Text(l10n.clientNew),
                        ),
                      ]
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.refresh(clientsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _ClientTile(
                    client: list[i],
                    onTap: () => context.push('/clients/${list[i].id}'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onTap;
  const _ClientTile({required this.client, required this.onTap});

  static const _sourceColors = {
    'whatsapp': Color(0xFF25D366),
    'instagram': Color(0xFFE1306C),
    'website': Color(0xFF1976D2),
    'personal': Color(0xFF9C27B0),
    'wholesale': Color(0xFFFF9800),
  };

  static const _sourceIcons = {
    'whatsapp': Icons.chat,
    'instagram': Icons.camera_alt_outlined,
    'website': Icons.language,
    'personal': Icons.handshake_outlined,
    'wholesale': Icons.inventory_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final srcColor = _sourceColors[client.source] ?? AppColors.grey400;
    final srcIcon = _sourceIcons[client.source] ?? Icons.person_outline;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          client.initials,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(client.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          if (client.phone != null) ...[
            const Icon(Icons.phone_outlined,
                size: 12, color: AppColors.grey600),
            const SizedBox(width: 3),
            Text(client.phone!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.grey600)),
            const SizedBox(width: 10),
          ],
          if (client.source != null)
            Icon(srcIcon, size: 12, color: srcColor),
        ],
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.grey400),
    );
  }
}
