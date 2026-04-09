import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crm_sewing/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/diary_repository.dart';
import '../../domain/diary_model.dart';

class DiaryEntryFormScreen extends ConsumerStatefulWidget {
  final String? entryId;
  const DiaryEntryFormScreen({super.key, this.entryId});

  @override
  ConsumerState<DiaryEntryFormScreen> createState() =>
      _DiaryEntryFormScreenState();
}

class _DiaryEntryFormScreenState
    extends ConsumerState<DiaryEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _salaryCtrl = TextEditingController();
  DateTime _entryDate = DateTime.now();
  final List<File> _newPhotos = [];
  List<String> _existingPhotoUrls = [];
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _prefill(DiaryModel entry) {
    if (_initialized) return;
    _initialized = true;
    _descCtrl.text = entry.description;
    _qtyCtrl.text = entry.quantity.toString();
    _salaryCtrl.text = entry.salaryAmount?.toStringAsFixed(0) ?? '';
    setState(() {
      _entryDate = entry.entryDate;
      _existingPhotoUrls = List.from(entry.photos);
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _entryDate = d);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickMultiImage(imageQuality: 80, limit: 5);
    if (picked.isNotEmpty) {
      setState(() {
        _newPhotos.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(diaryRepositoryProvider);
      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
      final salary = double.tryParse(_salaryCtrl.text.trim());

      if (widget.entryId == null) {
        final id = await repo.createEntry(
          description: _descCtrl.text.trim(),
          quantity: qty,
          entryDate: _entryDate,
          salaryAmount: salary,
          photos: _newPhotos,
        );
        ref.invalidate(diaryProvider);
        if (mounted) context.pushReplacement('/diary/$id');
      } else {
        await repo.updateEntry(
          id: widget.entryId!,
          description: _descCtrl.text.trim(),
          quantity: qty,
          entryDate: _entryDate,
          salaryAmount: salary,
          newPhotos: _newPhotos,
          existingPhotoUrls: _existingPhotoUrls,
        );
        ref.invalidate(diaryProvider);
        ref.invalidate(diaryDetailProvider(widget.entryId!));
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
    final role = ref.watch(currentRoleProvider);
    final isEdit = widget.entryId != null;

    if (isEdit) {
      ref.watch(diaryDetailProvider(widget.entryId!)).whenData(_prefill);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.edit : l10n.diaryNewEntry),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date picker
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.courierDate,
                  prefixIcon:
                      const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${_entryDate.day.toString().padLeft(2, '0')}.${_entryDate.month.toString().padLeft(2, '0')}.${_entryDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.diaryDescription,
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _qtyCtrl,
              decoration: InputDecoration(
                labelText: l10n.diaryQuantity,
                prefixIcon: const Icon(Icons.straighten),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.required;
                if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 1) {
                  return l10n.required;
                }
                return null;
              },
            ),
            // Salary — only director/head_manager can set
            if (role.canSetSalary) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _salaryCtrl,
                decoration: InputDecoration(
                  labelText: l10n.diarySalary,
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                  suffixText: '₽',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
            ],
            const SizedBox(height: 20),

            // Photos section
            Row(
              children: [
                Text(l10n.diaryPhoto,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      size: 18),
                  label: Text(l10n.add,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (_existingPhotoUrls.isNotEmpty ||
                _newPhotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingPhotoUrls.map((url) => _PhotoThumb(
                          child: Image.network(url,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80),
                          onRemove: () => setState(
                              () => _existingPhotoUrls.remove(url)),
                        )),
                    ..._newPhotos.map((f) => _PhotoThumb(
                          child: Image.file(f,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80),
                          onRemove: () =>
                              setState(() => _newPhotos.remove(f)),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 80, height: 80, child: child),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
