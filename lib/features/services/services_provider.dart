import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Provedor que vai buscar os serviços — catálogo global do negócio (todas as unidades)
final unitServicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('services')
      .select('*')
      .eq('is_active', true) 
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});