import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Provedor que vai buscar os serviços registados na unidade do utilizador logado
final unitServicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

  final response = await supabase
      .from('services')
      .select('*')
      .eq('unit_id', userRes['unit_id'])
      .eq('is_active', true) 
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});