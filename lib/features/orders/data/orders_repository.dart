import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/order_status.dart';
import '../domain/order_model.dart';

// Фильтр заказов
class OrderFilter {
  final OrderStatus? status;
  final String? search;
  final bool onlyMine;

  const OrderFilter({this.status, this.search, this.onlyMine = false});

  OrderFilter copyWith({
    OrderStatus? status,
    String? search,
    bool? onlyMine,
    bool clearStatus = false,
  }) =>
      OrderFilter(
        status: clearStatus ? null : (status ?? this.status),
        search: search ?? this.search,
        onlyMine: onlyMine ?? this.onlyMine,
      );
}

// Провайдер фильтра
final orderFilterProvider =
    StateProvider<OrderFilter>((ref) => const OrderFilter());

// Провайдер списка заказов
final ordersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final filter = ref.watch(orderFilterProvider);
  final currentUser = ref.watch(currentUserProvider).value;

  var query = client
      .from('orders')
      .select('*, clients(name), assignee:assigned_to(name)');

  if (filter.status != null) {
    query = query.eq('status', filter.status!.toJson());
  }

  if (filter.onlyMine && currentUser != null) {
    query = query.eq('assigned_to', currentUser['id'] as String);
  }

  final data = await query
      .order('deadline', ascending: true, nullsFirst: false)
      .order('created_at', ascending: false);
  var orders =
      (data as List).map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();

  // Поиск по названию или клиенту
  if (filter.search != null && filter.search!.isNotEmpty) {
    final q = filter.search!.toLowerCase();
    orders = orders
        .where((o) =>
            o.title.toLowerCase().contains(q) ||
            (o.clientName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  return orders;
});

// Провайдер одного заказа
final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderModel, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('orders')
      .select('*, clients(name), assignee:assigned_to(name)')
      .eq('id', id)
      .single();
  return OrderModel.fromJson(data as Map<String, dynamic>);
});

// Провайдер истории заказа
final orderHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, orderId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('order_history')
      .select('*, changed_by_user:changed_by(name)')
      .eq('order_id', orderId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
});

// Репозиторий действий
class OrdersRepository {
  final Ref _ref;
  OrdersRepository(this._ref);

  Future<String> createOrder({
    required String title,
    String? description,
    String? clientId,
    String? source,
    DateTime? deadline,
    double? price,
    String? assignedTo,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser!.id;
    final data = await client.from('orders').insert({
      'title': title,
      'description': description,
      'client_id': clientId,
      'source': source,
      'deadline': deadline?.toIso8601String().split('T').first,
      'price': price,
      'assigned_to': assignedTo,
      'created_by': uid,
      'status': 'new',
    }).select().single();
    return (data as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updateOrder({
    required String id,
    String? title,
    String? description,
    String? clientId,
    String? source,
    DateTime? deadline,
    double? price,
    String? assignedTo,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('orders').update({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'client_id': clientId,
      if (source != null) 'source': source,
      'deadline': deadline?.toIso8601String().split('T').first,
      'price': price,
      'assigned_to': assignedTo,
    }).eq('id', id);
  }

  Future<void> changeStatus(String id, OrderStatus status,
      {String? note}) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('orders').update({
      'status': status.toJson(),
    }).eq('id', id);

    if (note != null && note.isNotEmpty) {
      await client.from('order_history').insert({
        'order_id': id,
        'status': status.toJson(),
        'note': note,
        'changed_by': client.auth.currentUser!.id,
      });
    }
  }

  Future<void> assignOrder(String id, String? userId) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('orders')
        .update({'assigned_to': userId}).eq('id', id);
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref),
);
