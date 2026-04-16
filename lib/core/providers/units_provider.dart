import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/providers.dart';

final unitsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('units')
      .select('*')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});
