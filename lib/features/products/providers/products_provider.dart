import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/providers.dart';

// Provider para buscar todos os produtos
final productsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

  final response = await supabase
      .from('products')
      .select('*')
      .eq('unit_id', userRes['unit_id'] as Object)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

// Função para buscar produtos
Future<List<Map<String, dynamic>>> fetchProducts(SupabaseClient supabase, String unitId) async {
  final response = await supabase
      .from('products')
      .select('*')
      .eq('unit_id', unitId)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
}

// Função para adicionar produto
Future<Map<String, dynamic>> addProduct({
  required SupabaseClient supabase,
  required String unitId,
  required String name,
  required double price,
  int stock = 0,
}) async {
  final response = await supabase.from('products').insert({
    'unit_id': unitId,
    'name': name,
    'price': price,
    'stock': stock,
  }).select().single();

  return response;
}

// Função para atualizar produto
Future<Map<String, dynamic>> updateProduct({
  required SupabaseClient supabase,
  required String id,
  required String name,
  required double price,
  required int stock,
}) async {
  final response = await supabase
      .from('products')
      .update({
        'name': name,
        'price': price,
        'stock': stock,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  return response;
}

// Função para deletar produto
Future<void> deleteProduct(SupabaseClient supabase, String id) async {
  await supabase.from('products').delete().eq('id', id);
}

// Função para decrementar estoque
Future<Map<String, dynamic>> decrementStock(
  SupabaseClient supabase,
  String productId,
  int quantity,
) async {
  // Primeiro buscar o estoque atual
  final product = await supabase
      .from('products')
      .select('stock')
      .eq('id', productId)
      .single();

  final newStock = (product['stock'] as int) - quantity;

  final response = await supabase
      .from('products')
      .update({
        'stock': newStock < 0 ? 0 : newStock,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', productId)
      .select()
      .single();

  return response;
}