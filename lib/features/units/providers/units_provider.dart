import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Provider que busca todas as unidades
final unitsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('units').select('*').order('name');
  return List<Map<String, dynamic>>.from(response);
});

// Provider que busca os barbeiros de uma unidade específica, ordenados por hierarquia
// Barbeiro Líder > Barbeiro Pro Max > Barbeiro Pro > Barbeiro
final unitBarbersProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
    .from('barbers')
    .select('*, users(name)')
    .eq('unit_id', unitId)
    .eq('is_active', true);

  final barbers = List<Map<String, dynamic>>.from(response);

  // Ordenar por hierarquia: Barbeiro Líder > Pro Max > Pro > Barbeiro
  barbers.sort((a, b) {
    final order = {'Barbeiro Líder': 0, 'Barbeiro Pro Max': 1, 'Barbeiro Pro': 2, 'Barbeiro': 3};
    final aOrder = order[a['category']] ?? 99;
    final bOrder = order[b['category']] ?? 99;
    return aOrder.compareTo(bOrder);
  });

  return barbers;
});

// Provider que busca os dados de uma unidade específica
final unitDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('units').select('*').eq('id', unitId).single();
  return Map<String, dynamic>.from(response);
});

// Provider de métricas de uma unidade (para o Barbeiro Líder ver)
final unitMetricsProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  final userProfile = await ref.watch(userProfileProvider.future);
  final isLeader = userProfile['category'] == 'Barbeiro Líder' || userProfile['role'] == 'admin';

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

  var query = supabase
    .from('orders')
    .select('id, start_time, client_name, status, total, barbers(id, commission_rate, users(name))')
    .eq('unit_id', unitId)
    .gte('start_time', startOfToday)
    .lte('start_time', endOfToday)
    .neq('status', 'canceled');

  if (!isLeader && userProfile['barber_id'] != null) {
    query = query.eq('barber_id', userProfile['barber_id'] as String);
  }

  final response = await query.order('start_time', ascending: false);
  final orders = List<Map<String, dynamic>>.from(response);

  double faturamento = 0.0;
  double comissoes = 0.0;
  int fechadas = 0;
  int abertas = 0;

  final Map<String, Map<String, dynamic>> rankingMap = {};

  for (var order in orders) {
    if (order['status'] == 'closed') {
      fechadas++;
      final total = (order['total'] as num?)?.toDouble() ?? 0.0;
      faturamento += total;

      final barberData = order['barbers'];
      if (barberData != null) {
        final rate = (barberData['commission_rate'] as num?)?.toDouble() ?? 40.0;
        final commissionValue = total * (rate / 100);
        comissoes += commissionValue;

        final barberId = barberData['id'];
        final barberName = barberData['users']?['name'] ?? 'Desconhecido';

        if (!rankingMap.containsKey(barberId)) {
          rankingMap[barberId as String] = {'name': barberName, 'revenue': 0.0, 'count': 0};
        }
        rankingMap[barberId]!['revenue'] += total;
        rankingMap[barberId]!['count']++;
      }
    } else if (order['status'] == 'open') {
      abertas++;
    }
  }

  // Buscar Despesas de Hoje
  final todayDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final expensesResponse = await supabase
      .from('expenses')
      .select('amount')
      .eq('unit_id', unitId)
      .eq('expense_date', todayDateStr);
  
  final expensesList = List<Map<String, dynamic>>.from(expensesResponse);
  double despesas = 0.0;
  for (var exp in expensesList) {
    despesas += (exp['amount'] as num?)?.toDouble() ?? 0.0;
  }

  final rankingList = rankingMap.values.toList();
  rankingList.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

  final ticketMedio = fechadas > 0 ? (faturamento / fechadas) : 0.0;

  return {
    'faturamento': faturamento,
    'comissoes': comissoes,
    'despesas': despesas,
    'ticket_medio': ticketMedio,
    'fechadas': fechadas,
    'abertas': abertas,
    'ranking': rankingList,
    'orders': orders,
  };
});

// Provider de agendamentos de uma unidade (filtrado por perfil)
final unitOrdersProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  final userProfile = await ref.watch(userProfileProvider.future);
  final isLeader = userProfile['category'] == 'Barbeiro Líder' || userProfile['role'] == 'admin';

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

  var query = supabase
    .from('orders')
    .select('id, start_time, end_time, client_name, status, total, barbers(id, users(name))')
    .eq('unit_id', unitId)
    .gte('start_time', startOfToday)
    .lte('start_time', endOfToday)
    .neq('status', 'canceled');

  if (!isLeader && userProfile['barber_id'] != null) {
    query = query.eq('barber_id', userProfile['barber_id'] as String);
  }

  final response = await query.order('start_time', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});
