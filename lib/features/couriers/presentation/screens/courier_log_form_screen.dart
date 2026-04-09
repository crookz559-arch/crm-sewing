import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../features/clients/data/clients_repository.dart';
import '../../data/couriers_repository.dart';

class CourierLogFormScreen extends ConsumerStatefulWidget {
  const CourierLogFormScreen({super.key});

  @override
  ConsumerState<CourierLogFormScreen> createState() =>
      _CourierLogFormScreenState();
}

class _CourierLogFormScreenState
    extends ConsumerState<CourierLogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  String _direction = 'in';
  String? _clientId;
  DateTime _deliveryDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _deliveryDate = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(couriersRepositoryProvider).createLog(
            direction: _direction,
            clientId: _clientId,
            fromWho: _fromCtrl.text.trim().isEmpty
                ? null
                : _fromCtrl.text.trim(),
            toWho:
                _toCtrl.text.trim().isEmpty ? null : _toCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            deliveryDate: _deliveryDate,
          );
      ref.invalidate(couriersProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clientsAsync = ref.watch(clientsProvider);
    final clients = clientsAsync.value ?? [];

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.courierLog,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Direction toggle
              Row(
                children: [
                  Expanded(
                    child: _DirectionButton(
                      label: l10n.courierDirectionIn,
                      icon: Icons.arrow_downward,
                      selected: _direction == 'in',
                      color: const Color(0xFF4CAF50),
                      onTap: () => setState(() => _direction = 'in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DirectionButton(
                      label: l10n.courierDirectionOut,
                      icon: Icons.arrow_upward,
                      selected: _direction == 'out',
                      color: const Color(0xFF00BCD4),
                      onTap: () => setState(() => _direction = 'out'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: l10n.courierWhat,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 14),

              // Client dropdown
              DropdownButtonFormField<String>(
                value: _clientId,
                decoration: InputDecoration(
                  labelText: l10n.orderClient,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                items: [
                  DropdownMenuItem(
                      value: null,
                      child: Text(l10n.notSpecified,
                          style: const TextStyle(
                              color: Color(0xFF9E9E9E)))),
                  ...clients.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => _clientId = v),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.courierFrom,
                        prefixIcon:
                            const Icon(Icons.person_pin_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _toCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.courierTo,
                        prefixIcon:
                            const Icon(Icons.person_pin_circle_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.courierDate,
                    prefixIcon:
                        const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    '${_deliveryDate.day.toString().padLeft(2, '0')}.${_deliveryDate.month.toString().padLeft(2, '0')}.${_deliveryDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _DirectionButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
              color: selected ? color : const Color(0xFFBDBDBD),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : const Color(0xFF757575)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? color : const Color(0xFF757575),
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
