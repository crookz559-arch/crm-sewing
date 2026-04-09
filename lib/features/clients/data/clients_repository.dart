import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../domain/client_model.dart';

final clientSearchProvider = StateProvider<String>((ref) => '');

final clientsProvider =
    FutureProvider.autoDispose<List<ClientModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final search = ref.watch(clientSearchProvider);

  final data = await client
      .from('clients')
      .select('*, orders(count)')
      .order('name');

  var clients = (data as List)
      .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
      .toList();

  if (search.isNotEmpty) {
    final q = search.toLowerCase();
    clients = clients
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.phone?.contains(q) ?? false) ||
            (c.email?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  return clients;
});

final clientDetailProvider =
    FutureProvider.autoDispose.family<ClientModel, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('clients')
      .select()
      .eq('id', id)
      .single();
  return ClientModel.fromJson(data as Map<String, dynamic>);
});

// Заказы конкретного клиента
final clientOrdersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('orders')
      .select('id, title, status, deadline, price, created_at')
      .eq('client_id', clientId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
});

class ClientsRepository {
  final Ref _ref;
  ClientsRepository(this._ref);

  Future<String> createClient({
    required String name,
    String? phone,
    String? email,
    String? source,
    String? notes,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser!.id;
    final data = await client.from('clients').insert({
      'name': name,
      'phone': phone,
      'email': email,
      'source': source,
      'notes': notes,
      'created_by': uid,
    }).select().single();
    return (data as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updateClient({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? source,
    String? notes,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('clients').update({
      'name': name,
      'phone': phone,
      'email': email,
      'source': source,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

final clientsRepositoryProvider =
    Provider<ClientsRepository>((ref) => ClientsRepository(ref));
