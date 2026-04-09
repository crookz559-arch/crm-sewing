import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/auth_provider.dart';
import '../domain/diary_model.dart';

// Провайдер фильтра по месяцу
final diaryMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Провайдер записей дневника
final diaryProvider =
    FutureProvider.autoDispose<List<DiaryModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final month = ref.watch(diaryMonthProvider);
  final currentUser = ref.watch(currentUserProvider).value;
  final role = ref.watch(currentRoleProvider);

  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0);

  var query = client
      .from('diary_entries')
      .select('*, seamstress:seamstress_id(name)')
      .gte('entry_date', from.toIso8601String().split('T').first)
      .lte('entry_date', to.toIso8601String().split('T').first);

  // Швея видит только свои записи
  if (!role.canViewAnalytics && currentUser != null) {
    query = query.eq('seamstress_id', currentUser['id'] as String);
  }

  final data = await query.order('entry_date', ascending: false);
  return (data as List)
      .map((e) => DiaryModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final diaryDetailProvider =
    FutureProvider.autoDispose.family<DiaryModel, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('diary_entries')
      .select('*, seamstress:seamstress_id(name)')
      .eq('id', id)
      .single();
  return DiaryModel.fromJson(data as Map<String, dynamic>);
});

class DiaryRepository {
  final Ref _ref;
  DiaryRepository(this._ref);

  Future<String> createEntry({
    required String description,
    required int quantity,
    DateTime? entryDate,
    double? salaryAmount,
    List<File> photos = const [],
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser!.id;

    final photoUrls = await _uploadPhotos(client, uid, photos);

    final data = await client.from('diary_entries').insert({
      'seamstress_id': uid,
      'description': description,
      'quantity': quantity,
      'photos': photoUrls,
      'salary_amount': salaryAmount,
      'entry_date': (entryDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
    }).select().single();
    return (data as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updateEntry({
    required String id,
    required String description,
    required int quantity,
    DateTime? entryDate,
    double? salaryAmount,
    List<File> newPhotos = const [],
    List<String> existingPhotoUrls = const [],
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser!.id;

    final newUrls = await _uploadPhotos(client, uid, newPhotos);
    final allPhotos = [...existingPhotoUrls, ...newUrls];

    await client.from('diary_entries').update({
      'description': description,
      'quantity': quantity,
      'photos': allPhotos,
      'salary_amount': salaryAmount,
      'entry_date': (entryDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
    }).eq('id', id);
  }

  Future<void> approveSalary({
    required String id,
    required double salaryAmount,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser!.id;
    await client.from('diary_entries').update({
      'salary_amount': salaryAmount,
      'approved_by': uid,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<String>> _uploadPhotos(
      SupabaseClient client, String uid, List<File> files) async {
    if (files.isEmpty) return [];
    final urls = <String>[];
    for (final file in files) {
      final ext = file.path.split('.').last;
      final path =
          'diary/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await client.storage.from('diary-photos').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      final url =
          client.storage.from('diary-photos').getPublicUrl(path);
      urls.add(url);
    }
    return urls;
  }
}

final diaryRepositoryProvider =
    Provider<DiaryRepository>((ref) => DiaryRepository(ref));
