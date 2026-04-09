import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../data/clients_repository.dart';
import '../../domain/client_model.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final String? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _source;
  bool _loading = false;
  bool _initialized = false;

  static const _sources = [
    ('whatsapp', 'WhatsApp'),
    ('instagram', 'Instagram'),
    ('website', 'Сайт'),
    ('personal', 'Личное знакомство'),
    ('wholesale', 'Оптовый'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(ClientModel client) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = client.name;
    _phoneCtrl.text = client.phone ?? '';
    _emailCtrl.text = client.email ?? '';
    _notesCtrl.text = client.notes ?? '';
    setState(() => _source = client.source);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(clientsRepositoryProvider);
      if (widget.clientId == null) {
        final id = await repo.createClient(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          source: _source,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );
        ref.invalidate(clientsProvider);
        if (mounted) context.pushReplacement('/clients/$id');
      } else {
        await repo.updateClient(
          id: widget.clientId!,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          source: _source,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );
        ref.invalidate(clientsProvider);
        ref.invalidate(clientDetailProvider(widget.clientId!));
        if (mounted) context.pop();
      }
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
    final isEdit = widget.clientId != null;

    if (isEdit) {
      final clientAsync = ref.watch(clientDetailProvider(widget.clientId!));
      clientAsync.whenData(_prefill);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.clientEdit : l10n.clientNew),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.clientName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                labelText: l10n.clientPhone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: l10n.clientEmail,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _source,
              decoration: InputDecoration(
                labelText: l10n.orderSource,
                prefixIcon: const Icon(Icons.connecting_airports_outlined),
              ),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(l10n.notSpecified,
                        style:
                            const TextStyle(color: Color(0xFF9E9E9E)))),
                ..._sources.map((s) =>
                    DropdownMenuItem(value: s.$1, child: Text(s.$2))),
              ],
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.notes,
                prefixIcon: const Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
