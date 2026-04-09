import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/clients_repository.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  static const _sourceColors = {
    'whatsapp': Color(0xFF25D366),
    'instagram': Color(0xFFE1306C),
    'website': Color(0xFF1976D2),
    'personal': Color(0xFF9C27B0),
    'wholesale': Color(0xFFFF9800),
  };

  static const _sourceLabels = {
    'whatsapp': 'WhatsApp',
    'instagram': 'Instagram',
    'website': 'Сайт',
    'personal': 'Личное знакомство',
    'wholesale': 'Оптовый',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final clientAsync = ref.watch(clientDetailProvider(clientId));
    final ordersAsync = ref.watch(clientOrdersProvider(clientId));

    return Scaffold(
      appBar: AppBar(
        title: clientAsync.when(
          data: (c) => Text(c.name),
          loading: () => const Text(''),
          error: (_, __) => const Text('Клиент'),
        ),
        actions: [
          if (role.canCreateOrders)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/clients/$clientId/edit'),
            ),
        ],
      ),
      body: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (client) {
          final srcColor =
              _sourceColors[client.source] ?? AppColors.grey400;
          final srcLabel =
              _sourceLabels[client.source] ?? client.source ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar + name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        client.initials,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      client.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (client.source != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Chip(
                          label: Text(srcLabel,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white)),
                          backgroundColor: srcColor,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (client.phone != null)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: l10n.clientPhone,
                          value: client.phone!,
                        ),
                      if (client.email != null)
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: l10n.email,
                          value: client.email!,
                        ),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: l10n.createdAt,
                        value: _formatDate(client.createdAt),
                      ),
                    ],
                  ),
                ),
              ),

              if (client.notes != null && client.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notes_outlined,
                                size: 16, color: AppColors.grey600),
                            const SizedBox(width: 6),
                            Text(l10n.notes,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grey600,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(client.notes!),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // Orders section header
              Row(
                children: [
                  Text(l10n.navOrders,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (role.canCreateOrders)
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/orders/create?clientId=$clientId'),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.orderNew,
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Orders list
              ordersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(l10n.noData,
                            style: const TextStyle(
                                color: AppColors.grey600)),
                      ),
                    );
                  }
                  return Column(
                    children: orders
                        .map((o) => _OrderTile(
                              order: o,
                              showPrice: role.canViewPrice,
                              onTap: () =>
                                  context.push('/orders/${o['id']}'),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grey600),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.grey600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool showPrice;
  final VoidCallback onTap;
  const _OrderTile(
      {required this.order,
      required this.showPrice,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = OrderStatus.fromString(order['status'] as String? ?? 'new');
    final deadline = order['deadline'] != null
        ? DateTime.tryParse(order['deadline'] as String)
        : null;
    final price = order['price'] as num?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(order['title'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: deadline != null
            ? Text(
                '${deadline.day.toString().padLeft(2, '0')}.${deadline.month.toString().padLeft(2, '0')}.${deadline.year}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.grey600))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPrice && price != null)
              Text('${price.toStringAsFixed(0)} ₽',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status.toJson(),
                  style: TextStyle(
                      fontSize: 11,
                      color: status.color,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
