import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../features/users/presentation/users_screen.dart';
import '../../data/orders_repository.dart';
import '../../domain/order_model.dart';
import '../../../clients/data/clients_repository.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  final String? orderId; // null = создание, non-null = редактирование
  const OrderFormScreen({super.key, this.orderId});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController();

  String? _selectedClientId;
  String? _selectedClientName;
  String? _selectedSource;
  String? _selectedAssigneeId;
  DateTime? _selectedDeadline;
  bool _loading = false;
  bool _initialized = false;
  // Files to attach after creating a new order
  final List<PlatformFile> _pendingFiles = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _paidAmountCtrl.dispose();
    super.dispose();
  }

  void _initFromOrder(OrderModel order) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = order.title;
    _descCtrl.text = order.description ?? '';
    _priceCtrl.text = order.price?.toStringAsFixed(0) ?? '';
    _paidAmountCtrl.text =
        order.paidAmount > 0 ? order.paidAmount.toStringAsFixed(0) : '';
    _selectedClientId = order.clientId;
    _selectedClientName = order.clientName;
    _selectedSource = order.source;
    _selectedAssigneeId = order.assignedTo;
    _selectedDeadline = order.deadline;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final repo = ref.read(ordersRepositoryProvider);
      final price = _priceCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_priceCtrl.text.trim());
      final paidAmount = _paidAmountCtrl.text.trim().isEmpty
          ? 0.0
          : (double.tryParse(_paidAmountCtrl.text.trim()) ?? 0);

      if (widget.orderId == null) {
        final id = await repo.createOrder(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          clientId: _selectedClientId,
          source: _selectedSource,
          deadline: _selectedDeadline,
          price: price,
          paidAmount: paidAmount,
          assignedTo: _selectedAssigneeId,
        );
        // Upload any pending files
        if (_pendingFiles.isNotEmpty) {
          final client = ref.read(supabaseClientProvider);
          for (final f in _pendingFiles) {
            try {
              if (f.bytes == null) continue;
              final ext = f.extension ?? 'bin';
              final isImage = RegExp(r'jpg|jpeg|png|gif|webp|heic', caseSensitive: false).hasMatch(ext);
              final path = 'orders/$id/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
              await client.storage.from('order-files').uploadBinary(path, f.bytes!,
                  fileOptions: FileOptions(contentType: isImage ? 'image/$ext' : 'application/octet-stream'));
              final url = client.storage.from('order-files').getPublicUrl(path);
              await repo.addAttachment(id, url, f.name, isImage ? 'image' : 'file');
            } catch (_) {}
          }
        }
        ref.invalidate(ordersProvider);
        if (mounted) context.pushReplacement('/orders/$id');
      } else {
        await repo.updateOrder(
          id: widget.orderId!,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          clientId: _selectedClientId,
          source: _selectedSource,
          deadline: _selectedDeadline,
          price: price,
          paidAmount: paidAmount,
          assignedTo: _selectedAssigneeId,
        );
        ref.invalidate(ordersProvider);
        ref.invalidate(orderDetailProvider(widget.orderId!));
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: AppColors.statusRework),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final isEdit = widget.orderId != null;

    // Инициализируем при редактировании
    if (isEdit) {
      ref.watch(orderDetailProvider(widget.orderId!)).whenData(_initFromOrder);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактировать заказ' : l10n.orderNew),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Название
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                  labelText: 'Название заказа *',
                  prefixIcon: const Icon(Icons.assignment_outlined)),
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 12),

            // Клиент
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ClientSelector(
                    selectedId: _selectedClientId,
                    selectedName: _selectedClientName,
                    onSelected: (id, name) => setState(() {
                      _selectedClientId = id;
                      _selectedClientName = name;
                    }),
                    l10n: l10n,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                    onPressed: () => _showQuickClientCreate(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                    tooltip: 'Новый клиент',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Источник
            DropdownButtonFormField<String>(
              value: _selectedSource,
              decoration: InputDecoration(
                  labelText: l10n.orderSource,
                  prefixIcon: const Icon(Icons.source_outlined)),
              items: [
                DropdownMenuItem(
                    value: 'whatsapp', child: Text(l10n.sourceWhatsApp)),
                DropdownMenuItem(
                    value: 'instagram', child: Text(l10n.sourceInstagram)),
                DropdownMenuItem(
                    value: 'website', child: Text(l10n.sourceWebsite)),
                DropdownMenuItem(
                    value: 'personal', child: Text(l10n.sourcePersonal)),
                DropdownMenuItem(
                    value: 'wholesale', child: Text(l10n.sourceWholesale)),
              ],
              onChanged: (v) => setState(() => _selectedSource = v),
            ),
            const SizedBox(height: 12),

            // Дедлайн
            GestureDetector(
              onTap: () => _pickDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: l10n.orderDeadline,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: _selectedDeadline != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _selectedDeadline = null),
                          )
                        : null,
                  ),
                  controller: TextEditingController(
                    text: _selectedDeadline != null
                        ? '${_selectedDeadline!.day.toString().padLeft(2, '0')}.${_selectedDeadline!.month.toString().padLeft(2, '0')}.${_selectedDeadline!.year}'
                        : '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Финансы (только для директора и ГМ)
            if (role.canViewPrice) ...[
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Стоимость заказа (₽)',
                  prefixIcon: const Icon(Icons.attach_money),
                  helperText: 'Полная стоимость',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Внесена оплата (₽)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText: 'Сумма предоплаты',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Исполнитель
            if (role.canAssign)
              _AssigneeDropdown(
                selectedId: _selectedAssigneeId,
                onSelected: (id) =>
                    setState(() => _selectedAssigneeId = id),
                l10n: l10n,
              ),

            const SizedBox(height: 12),

            // Описание
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: l10n.orderDescription,
                  prefixIcon: const Icon(Icons.notes),
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),

            // Файлы / фото (только при создании — при редактировании используем детальный экран)
            if (!isEdit) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 18, color: AppColors.grey600),
                  const SizedBox(width: 8),
                  const Text('Файлы и фото', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить'),
                  ),
                ],
              ),
              if (_pendingFiles.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pendingFiles.map((f) {
                    final ext = f.extension ?? '';
                    final isImage = RegExp(r'jpg|jpeg|png|gif|webp|heic', caseSensitive: false).hasMatch(ext);
                    return Chip(
                      avatar: Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 16),
                      label: Text(f.name, overflow: TextOverflow.ellipsis),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _pendingFiles.remove(f)),
                    );
                  }).toList(),
                ),
              const Divider(),
            ],

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? l10n.save : 'Создать заказ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickClientCreate(BuildContext context) async {
    final result = await showModalBottomSheet<(String, String)?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuickClientForm(supabaseRef: ref),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedClientId = result.$1;
        _selectedClientName = result.$2;
      });
      ref.invalidate(_clientsForOrderProvider);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _pendingFiles.addAll(result.files.where((f) => f.bytes != null)));
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDeadline = picked);
  }
}

// ─── Выбор клиента ──────────────────────────────────────────────────────────

final _clientsForOrderProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('clients')
      .select('id, name')
      .order('name');
  return List<Map<String, dynamic>>.from(data as List);
});

class _ClientSelector extends ConsumerWidget {
  final String? selectedId;
  final String? selectedName;
  final void Function(String?, String?) onSelected;
  final AppLocalizations l10n;

  const _ClientSelector({
    required this.selectedId,
    required this.selectedName,
    required this.onSelected,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(_clientsForOrderProvider);

    return clients.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox(),
      data: (list) => DropdownButtonFormField<String?>(
        value: selectedId,
        decoration: InputDecoration(
            labelText: l10n.orderClient,
            prefixIcon: const Icon(Icons.person_outline)),
        items: [
          const DropdownMenuItem(
              value: null,
              child: Text('Без клиента',
                  style: TextStyle(color: AppColors.grey600))),
          ...list.map((c) => DropdownMenuItem(
              value: c['id'] as String, child: Text(c['name'] as String))),
        ],
        onChanged: (id) {
          final name = id == null
              ? null
              : list.firstWhere((c) => c['id'] == id)['name'] as String;
          onSelected(id, name);
        },
      ),
    );
  }
}

// ─── Выбор исполнителя ──────────────────────────────────────────────────────

class _AssigneeDropdown extends ConsumerWidget {
  final String? selectedId;
  final void Function(String?) onSelected;
  final AppLocalizations l10n;

  const _AssigneeDropdown({
    required this.selectedId,
    required this.onSelected,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);

    return users.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox(),
      data: (list) => DropdownButtonFormField<String?>(
        value: selectedId,
        decoration: InputDecoration(
            labelText: l10n.orderAssignee,
            prefixIcon: const Icon(Icons.engineering_outlined)),
        items: [
          const DropdownMenuItem(
              value: null,
              child: Text('Не назначен',
                  style: TextStyle(color: AppColors.grey600))),
          ...list
              .where((u) =>
                  (u['role'] as String) != 'director' &&
                  (u['is_active'] as bool? ?? true))
              .map((u) => DropdownMenuItem(
                  value: u['id'] as String,
                  child: Text(u['name'] as String? ?? ''))),
        ],
        onChanged: onSelected,
      ),
    );
  }
}

// ─── Быстрое создание клиента ─────────────────────────────────────────────────

class _QuickClientForm extends ConsumerStatefulWidget {
  final WidgetRef supabaseRef;
  const _QuickClientForm({required this.supabaseRef});

  @override
  ConsumerState<_QuickClientForm> createState() => _QuickClientFormState();
}

class _QuickClientFormState extends ConsumerState<_QuickClientForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(clientsRepositoryProvider);
      final id = await repo.createClient(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop((id, _nameCtrl.text.trim()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Новый клиент', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Имя клиента *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Создать клиента'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
