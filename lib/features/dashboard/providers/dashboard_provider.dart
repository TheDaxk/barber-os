import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/providers/selected_unit_provider.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnit = ref.watch(selectedUnitIdProvider); // observa a seleção

  String unitId;
  if (selectedUnit != null) {
    unitId = selectedUnit; // usa a unidade escolhida pelo líder
  } else {
    final userId = supabase.auth.currentUser!.id;
    final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();
    unitId = userRes['unit_id'] as String;
  }

  // Definir o intervalo de HOJE
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

  // Vai buscar as permissões do utilizador
  final userProfile = await ref.watch(userProfileProvider.future);
  final isLeader = userProfile['category'] == 'Barbeiro Líder' || userProfile['role'] == 'admin';

  // Buscar agendamentos que comecem hoje (ativos e fechados)
  var query = supabase
      .from('orders')
      .select('id, start_time, client_name, status, total, barbers(id, commission_rate, users(name))')
      .eq('unit_id', unitId)
      .gte('start_time', startOfToday)
      .lte('start_time', endOfToday)
      .neq('status', 'canceled'); // Ignora os cancelados

  if (!isLeader && userProfile['barber_id'] != null) {
    // Filtro cirúrgico: mostra APENAS os lucros/comissões/agendamentos DESTE barbeiro
    query = query.eq('barber_id', userProfile['barber_id']);
  }

  final response = await query.order('start_time', ascending: false);
      
  final orders = List<Map<String, dynamic>>.from(response);

  double faturamentoHoje = 0.0;
  double comissoesHoje = 0.0;
  int comandasFechadas = 0;
  int comandasAbertas = 0;

  // Mapa para calcular o ranking (barber_id -> dados)
  final Map<String, Map<String, dynamic>> rankingMap = {};

  for (var order in orders) {
    if (order['status'] == 'closed') {
      comandasFechadas++;
      final total = (order['total'] as num?)?.toDouble() ?? 0.0;
      faturamentoHoje += total;

      // Pegar a comissão do barbeiro (assumindo 40% se não vier definida)
      final barberData = order['barbers'];
      if (barberData != null) {
        final rate = (barberData['commission_rate'] as num?)?.toDouble() ?? 40.0;
        final commissionValue = total * (rate / 100);
        comissoesHoje += commissionValue;

        // Atualizar Ranking
        final barberId = barberData['id'];
        final barberName = barberData['users']?['name'] ?? 'Desconhecido';
        
        if (!rankingMap.containsKey(barberId)) {
          rankingMap[barberId] = {
            'name': barberName,
            'revenue': 0.0,
            'count': 0,
          };
        }
        rankingMap[barberId]!['revenue'] += total;
        rankingMap[barberId]!['count'] += 1;
      }
    } else if (order['status'] == 'open') {
      comandasAbertas++;
    }
  }

  // Transformar map num ranking list, ordenado por receita (descrescente)
  final rankingList = rankingMap.values.toList();
  rankingList.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

  // Últimas Comandas (top 5 ordenados pela data de forma decrescente)
  final recentOrders = orders.take(5).toList();

  // Informações Operacionais Adicionais

  // 1. Próximos agendamentos (agendamentos futuros do dia)
  final upcomingOrders = orders
      .where((order) {
        final startTime = DateTime.parse(order['start_time']).toLocal();
        return order['status'] == 'open' && startTime.isAfter(now);
      })
      .take(3) // Apenas os próximos 3
      .toList();

  // 2. Clientes em espera (comandas abertas que já deveriam ter começado)
  final waitingOrders = orders
      .where((order) {
        final startTime = DateTime.parse(order['start_time']).toLocal();
        return order['status'] == 'open' && startTime.isBefore(now);
      })
      .toList();
  final waitingCount = waitingOrders.length;

  // 3. Barbeiros ativos hoje (que têm comandas hoje)
  final activeBarbersSet = <String>{};
  for (var order in orders) {
    final barberData = order['barbers'];
    if (barberData != null && barberData['id'] != null) {
      activeBarbersSet.add(barberData['id'].toString());
    }
  }
  final activeBarbersCount = activeBarbersSet.length;

  return {
    'faturamento': faturamentoHoje,
    'comissoes': comissoesHoje,
    'fechadas': comandasFechadas,
    'abertas': comandasAbertas,
    'ranking': rankingList,
    'recentes': recentOrders,
    // NOVOS:
    'upcoming': upcomingOrders, // Próximos agendamentos
    'waiting_count': waitingCount, // Clientes em espera
    'active_barbers': activeBarbersCount, // Barbeiros ativos hoje
  };
});
