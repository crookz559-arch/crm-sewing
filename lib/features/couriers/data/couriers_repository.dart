import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../domain/courier_model.dart';

final courierFilterProvider = StateProvider<String?>((ref) => null); // 'in'|'out'|null

final couriersProvider =
    FutureProvider.autoDispose<List<CourierModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final direction = ref.watch(courierFilterProvider);

  var query = client
      .from('courier_logs')
      .select('*, client:client_id(name)');

  if (direction != null) {
    query = query.eq('direction', direction);
  }

  final data = await query.order('delivery_date', ascending: false);
  return (data as List)
      .map((e) => CourierModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class CouriersRepository {
  final Ref _ref;
  CouriersRepository(this._ref);

  Future<void> createLog({
    required String direction,
    String? clientId,
    String? fromWho,
    String? toWho,
    required String description,
    required DateTime deliveryDate,
    String? orderId,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser!.id;
    await client.from('courier_logs').insert({
      'direction': direction,
      'client_id': clientId,
      'from_who': fromWho,
      'to_who': toWho,
      'description': description,
      'delivery_date': deliveryDate.toIso8601String().split('T').first,
      'order_id': orderId,
      'created_by': uid,
    });
  }

  Future<void> deleteLog(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('courier_logs').delete().eq('id', id);
  }
}

final couriersRepositoryProvider =
    Provider<CouriersRepository>((ref) => CouriersRepository(ref));
