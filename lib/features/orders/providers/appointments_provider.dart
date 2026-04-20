import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/rbac/app_permissions.dart';
import '../../../core/providers/selected_unit_provider.dart';

final appointmentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnit = ref.watch(selectedUnitIdProvider);

  // Define o ponto de partida como HOJE à meia-noite
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();

  final userProfile = await ref.watch(userProfileProvider.future);
  final perm = AppPermissions(userProfile);

  // Resolve a unidade ativa
  String unitId;
  if (selectedUnit != null) {
    unitId = selectedUnit;
  } else {
    unitId = userProfile['unit_id'] as String;
  }

  // Busca agendamentos com informações do barbeiro E do cliente (incluindo is_vip)
  var query = supabase
      .from('orders')
      .select('id, start_time, end_time, client_name, client_id, status, total, barbers(id, users(name)), clients(id, name, is_vip)')
      .eq('unit_id', unitId)
      .gte('start_time', startOfToday); // Busca de hoje para a frente

  if (!perm.isGlobalAdmin && userProfile['barber_id'] != null) {
    query = query.eq('barber_id', userProfile['barber_id'] as Object);
  }

  final response = await query.order('start_time');

  return List<Map<String, dynamic>>.from(response);
});