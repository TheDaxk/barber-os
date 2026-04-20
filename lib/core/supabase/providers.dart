import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/selected_unit_provider.dart';
import '../../features/reports/presentation/financial_provider.dart';


import '../rbac/app_permissions.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Este provider busca as informações do usuário logado na tabela "users" e "barbers"
// Usamos autoDispose para que a memória seja limpa assim que a tela for encerrada (Logout)
final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Sessão expirada');

  final userData = await supabase
      .from('users')
      .select()
      .eq('id', user.id)
      .single();

  // Busca na tabela barbers (abrange barbeiros E cabeleireiras — mesma tabela,
  // diferenciados pelo campo category)
  final barberData = await supabase
      .from('barbers')
      .select('id, category')
      .eq('user_id', user.id)
      .maybeSingle();

  return {
    ...userData,
    'barber_id': barberData?['id'],
    'category': barberData?['category'] ?? userData['role'] ?? 'Barbeiro',
  };
});

// Provider de conveniência que retorna AppPermissions já instanciado.
// Uso: final perm = ref.watch(permissionsProvider);
// Nota: retorna null enquanto carrega. Usar com .maybeWhen ou .when.
final permissionsProvider = FutureProvider.autoDispose<AppPermissions>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return AppPermissions(profile);
});

final servicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('services')
      .select('*')
      .eq('is_active', true)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});


/// Provider filtrado por setor — use este ao abrir agendamentos de uma tela específica
/// sector: 'barbearia', 'salao', ou 'premium'. null = retorna todos (comportamento padrão).
final servicesBySectorProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, sector) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase
      .from('services')
      .select('*')
      .eq('is_active', true);

  if (sector != null) {
    query = query.eq('sector', sector);
  }

  final response = await query.order('name');
  return List<Map<String, dynamic>>.from(response);
});


final barbersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnit = ref.watch(selectedUnitIdProvider);

  // Resolve a unidade ativa
  String unitId;
  if (selectedUnit != null) {
    unitId = selectedUnit;
  } else {
    final userProfile = await ref.watch(userProfileProvider.future);
    unitId = userProfile['unit_id'] as String;
  }

  final response = await supabase
      .from('barbers')
      .select('id, category, unit_id, users(name)') 
      .eq('is_active', true)
      .eq('unit_id', unitId);
      
  return List<Map<String, dynamic>>.from(response);
});

/// Busca métricas consolidadas do setor Premium para o mês selecionado
final premiumMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedDate = ref.watch(selectedMonthProvider);
  final selectedUnit = ref.watch(selectedUnitIdProvider);

  final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1).toIso8601String();
  final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59).toIso8601String();

  String unitId;
  if (selectedUnit != null) {
    unitId = selectedUnit;
  } else {
    final userProfile = await ref.watch(userProfileProvider.future);
    unitId = userProfile['unit_id'] as String;
  }

  // Busca orders fechados no mes daquela unidade
  final ordersResponse = await supabase
      .from('orders')
      .select('id')
      .eq('status', 'closed')
      .eq('unit_id', unitId)
      .gte('closed_at', startOfMonth)
      .lte('closed_at', endOfMonth);

  final orderIds = (ordersResponse as List).map((e) => e['id']).toList();

  if (orderIds.isEmpty) {
    return {
      'faturamento': 0.0,
      'atendimentos': 0,
      'ticket_medio': 0.0,
      'meta_mensal': 6000.0,
    };
  }

  // Busca lista de IDs de servicos que sao premium
  final servicesResponse = await supabase
      .from('services')
      .select('id')
      .eq('sector', 'premium');

  final premiumServiceIds = (servicesResponse as List).map((e) => e['id']).toList();

  if (premiumServiceIds.isEmpty) {
    return {
      'faturamento': 0.0,
      'atendimentos': 0,
      'ticket_medio': 0.0,
      'meta_mensal': 6000.0,
    };
  }

  // Busca itens de order_items validando os servicos e orders passados
  final itemsResponse = await supabase
      .from('order_items')
      .select('unit_price, quantity')
      .eq('item_type', 'service')
      .inFilter('order_id', orderIds)
      .inFilter('reference_id', premiumServiceIds);

  final items = List<Map<String, dynamic>>.from(itemsResponse);

  double faturamento = 0;
  int atendimentos = items.length; // Cada item de serviço premium conta como um atendimento premium
  
  for (var item in items) {
    faturamento += ((item['unit_price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1);
  }

  return {
    'faturamento': faturamento,
    'atendimentos': atendimentos,
    'ticket_medio': atendimentos > 0 ? faturamento / atendimentos : 0.0,
    'meta_mensal': 6000.0,
  };
});