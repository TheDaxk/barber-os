import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Este provider busca as informações do usuário logado na tabela "users" e "barbers"
// Usamos autoDispose para que a memória seja limpa assim que a tela for encerrada (Logout)
final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  
  if (user == null) throw Exception('Sessão expirada');
  
  final userData = await supabase.from('users').select().eq('id', user.id).single();
  
  // Tenta puxar a categoria e barber_id caso ele "venda serviços" (seja um barbeiro / líder)
  final barberData = await supabase.from('barbers').select('id, category').eq('user_id', user.id).maybeSingle();
  
  return {
    ...userData,
    'barber_id': barberData?['id'], 
    'category': barberData?['category'] ?? userData['role'] ?? 'Gestor',
  };
});

final servicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  final response = await supabase
      .from('services')
      .select('*')
      .eq('is_active', true)
      .order('name');
      
  return List<Map<String, dynamic>>.from(response);
});

final barbersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  // O RLS foi resolvido na base, então o join volta a funcionar!
  final response = await supabase
      .from('barbers')
      .select('id, category, users(name)') 
      .eq('is_active', true);
      
  return List<Map<String, dynamic>>.from(response);
});