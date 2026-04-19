import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Provider que recebe o client_id e retorna o histórico daquele cliente
final clientHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('client_history')
      .select('*')
      .eq('client_id', clientId)
      .order('date', ascending: false); // Mais recente primeiro

  return List<Map<String, dynamic>>.from(response);
});