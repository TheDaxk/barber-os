import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../../core/rbac/app_permissions.dart';

final employeesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnitId = ref.watch(selectedUnitIdProvider);
  final userProfile = await ref.watch(userProfileProvider.future);
  final perm = AppPermissions(userProfile);

  // TODO(P-06): quando a migração do Pedro adicionar a coluna `sector` na tabela
  // barbers, atualizar o select abaixo adicionando ', sector' ao final da string.
  // Exemplo futuro:
  // .select('id, user_id, unit_name, category, commission_rate, is_active, unit_id, sector, users(id, name, email, phone)')
  var query = supabase
      .from('barbers')
      .select('id, user_id, unit_name, category, commission_rate, is_active, unit_id, sector, users(id, name, email, phone)')
      .eq('is_active', true);

  // Líderes veem todos quando nenhuma unidade específica está selecionada
  // Barbeiros comuns sempre veem só sua unidade
  if (!perm.isGlobalAdmin || selectedUnitId != null) {
    final unitId = selectedUnitId ?? (userProfile['unit_id'] as String?);
    if (unitId != null) {
      query = query.eq('unit_id', unitId);
    }
  }

  final response = await query.order('category');
  return List<Map<String, dynamic>>.from(response);
});
