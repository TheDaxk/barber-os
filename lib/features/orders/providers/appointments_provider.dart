import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

final appointmentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  // Define o ponto de partida como HOJE à meia-noite
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();

  final userProfile = await ref.watch(userProfileProvider.future);
  final isLeader = userProfile['category'] == 'Barbeiro Líder' || userProfile['role'] == 'admin';

  // Busca agendamentos com informações do barbeiro E do cliente (incluindo is_vip)
  var query = supabase
      .from('orders')
      .select('id, start_time, end_time, client_name, client_id, status, total, barbers(id, users(name)), clients(id, name, is_vip)')
      .gte('start_time', startOfToday); // Busca de hoje para a frente

  if (!isLeader && userProfile['barber_id'] != null) {
    query = query.eq('barber_id', userProfile['barber_id']);
  }

  final response = await query.order('start_time');

  return List<Map<String, dynamic>>.from(response);
});