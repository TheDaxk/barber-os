import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Provider que retorna as métricas de um barbeiro específico no mês atual
final barberMetricsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, barberId) async {
  final supabase = ref.watch(supabaseProvider);

  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month, 1);
  final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final firstDayStr = firstDay.toIso8601String();
  final lastDayStr = lastDay.toIso8601String();

  // Busca comandas fechadas do barbeiro no mês atual
  final response = await supabase
      .from('orders')
      .select('total, status')
      .eq('barber_id', barberId)
      .eq('status', 'closed')
      .gte('start_time', firstDayStr)
      .lte('start_time', lastDayStr);

  final orders = List<Map<String, dynamic>>.from(response);

  int totalAppointments = orders.length;
  double totalRevenue = 0.0;

  for (var order in orders) {
    if (order['total'] != null) {
      totalRevenue += (order['total'] as num).toDouble();
    }
  }

  // Tenta buscar top serviços via order_items
  List<Map<String, dynamic>> topServices = [];
  try {
    // Busca order_items com serviço associated
    final itemsResponse = await supabase
        .from('order_items')
        .select('service_id, services(name)')
        .gte('created_at', firstDayStr)
        .lte('created_at', lastDayStr);

    final items = List<Map<String, dynamic>>.from(itemsResponse);

    // Conta frequência de cada serviço
    final Map<String, int> serviceCount = {};
    final Map<String, String> serviceName = {};

    for (var item in items) {
      final serviceId = item['service_id']?.toString();
      if (serviceId != null) {
        serviceCount[serviceId] = (serviceCount[serviceId] ?? 0) + 1;
        if (item['services'] != null && item['services']['name'] != null) {
          serviceName[serviceId] = item['services']['name'] as String;
        }
      }
    }

    // Ordena e pega top 3
    final sortedEntries = serviceCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    topServices = sortedEntries.take(3).map((entry) {
      return {
        'id': entry.key,
        'name': serviceName[entry.key] ?? 'Serviço',
        'count': entry.value,
      };
    }).toList();
  } catch (e) {
    // order_items não existe ou erro - retorna lista vazia
    topServices = [];
  }

  return {
    'totalAppointments': totalAppointments,
    'totalRevenue': totalRevenue,
    'topServices': topServices,
  };
});
