import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Busca a lista de clientes cadastrados na unidade do usuário
final clientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  final response = await supabase
      .from('clients')
      .select('*')
      .order('name'); // Traz em ordem alfabética
      
  return List<Map<String, dynamic>>.from(response);
});