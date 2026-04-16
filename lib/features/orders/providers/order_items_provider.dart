import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/providers.dart';

// Provider para buscar itens de uma ordem específica
final orderItemsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, orderId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('order_items')
      .select('*')
      .eq('order_id', orderId)
      .order('created_at');

  return List<Map<String, dynamic>>.from(response);
});

// Função para buscar itens de uma ordem
Future<List<Map<String, dynamic>>> fetchOrderItems(SupabaseClient supabase, String orderId) async {
  final response = await supabase
      .from('order_items')
      .select('*')
      .eq('order_id', orderId)
      .order('created_at');

  return List<Map<String, dynamic>>.from(response);
}

// Função para adicionar item à ordem
Future<Map<String, dynamic>> addOrderItem({
  required SupabaseClient supabase,
  required String orderId,
  String? referenceId,
  required String itemType,   // 'service' | 'product' | 'extra'
  required String name,
  required double unitPrice,
  int quantity = 1,
  double commissionPct = 40.0,
}) async {
  final commissionValue = unitPrice * (commissionPct / 100) * quantity;

  final response = await supabase.from('order_items').insert({
    'order_id': orderId,
    'item_type': itemType,
    'reference_id': referenceId,
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'commission_pct': commissionPct,
    'commission_value': commissionValue,
  }).select().single();

  return response;
}

// Função para remover item da ordem
Future<void> removeOrderItem(SupabaseClient supabase, String itemId) async {
  await supabase.from('order_items').delete().eq('id', itemId);
}

// Função para calcular total da ordem baseado nos itens
Future<double> calculateOrderTotal(SupabaseClient supabase, String orderId) async {
  final items = await fetchOrderItems(supabase, orderId);
  double total = 0.0;
  for (var item in items) {
    total += (item['unit_price'] as num).toDouble() * (item['quantity'] as num).toInt();
  }
  return total;
}

// Função para atualizar quantidade de um item
Future<Map<String, dynamic>> updateOrderItemQuantity(
  SupabaseClient supabase,
  String itemId,
  int quantity,
) async {
  final response = await supabase
      .from('order_items')
      .update({'quantity': quantity})
      .eq('id', itemId)
      .select()
      .single();

  return response;
}