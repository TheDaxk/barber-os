import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

final unitsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  final response = await supabase
      .from('units')
      .select('*')
      .eq('is_active', true)
      .order('name');
      
  return List<Map<String, dynamic>>.from(response);
});
