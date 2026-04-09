import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('users')
      .select()
      .eq('id', user.id)
      .single();
  return data;
});

final currentRoleProvider = Provider<UserRole>((ref) {
  final userData = ref.watch(currentUserProvider);
  return userData.when(
    data: (data) {
      if (data == null) return UserRole.seamstress;
      return UserRole.fromString(data['role'] as String? ?? 'seamstress');
    },
    loading: () => UserRole.seamstress,
    error: (_, __) => UserRole.seamstress,
  );
});
