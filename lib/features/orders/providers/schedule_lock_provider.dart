import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

/// Retorna true se a agenda do barbeiro logado está travada
final scheduleLockProvider = FutureProvider.autoDispose<bool>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userProfile = await ref.watch(userProfileProvider.future);

  final barberId = userProfile['barber_id'] as String?;

  // Admins e líderes não possuem barber_id próprio para travar
  if (barberId == null) return false;

  final response = await supabase
      .from('barbers')
      .select('is_schedule_locked')
      .eq('id', barberId)
      .single();

  return response['is_schedule_locked'] as bool? ?? false;
});

/// Retorna um Map de {barberId: isLocked} para todos os barbeiros ativos da unidade
final allBarbersLockStatusProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('barbers')
      .select('id, is_schedule_locked')
      .eq('is_active', true);

  final result = <String, bool>{};
  for (final row in response as List) {
    result[row['id'] as String] = row['is_schedule_locked'] as bool? ?? false;
  }
  return result;
});

/// Função utilitária para alternar o estado (não é um provider, é uma função)
Future<void> toggleScheduleLock({
  required String barberId,
  required bool currentValue,
  required dynamic supabase, // SupabaseClient
}) async {
  await supabase
      .from('barbers')
      .update({'is_schedule_locked': !currentValue})
      .eq('id', barberId);
}
