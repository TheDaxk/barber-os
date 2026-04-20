import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/providers/selected_unit_provider.dart';

// Busca a lista de clientes cadastrados na unidade ativa
final clientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnit = ref.watch(selectedUnitIdProvider);

  // Resolve a unidade ativa
  String unitId;
  if (selectedUnit != null) {
    unitId = selectedUnit;
  } else {
    final userProfile = await ref.watch(userProfileProvider.future);
    unitId = userProfile['unit_id'] as String;
  }

  final response = await supabase
      .from('clients')
      .select('*, created_by_barber:barbers!created_by_barber_id(id, users(name))')
      .eq('unit_id', unitId)
      .order('name'); // Traz em ordem alfabética

  return List<Map<String, dynamic>>.from(response);
});

// ============================================================
// TODO(P-02, P-03, P-04): Este provider é um mock temporário.
// Quando o Pedro entregar:
//   - P-02: campo created_by_barber_id na tabela clients
//   - P-03: tabela client_history populada ao fechar ordens
//   - P-04: provider real que consulta client_history
// Substituir este provider pelo provider real do Pedro (P-04),
// que retornará os clientes com campo `days_since_last_visit` (int).
// O contrato esperado de P-04 é:
//   List<Map<String, dynamic>> com campo 'days_since_last_visit' (int)
//   keyed por client_id como String.
// ============================================================

/// Retorna um Map de client_id → dias desde a última visita (mock).
/// Simula diferentes faixas de inatividade para fins de UI.
final inactivityMockProvider = Provider<Map<String, int>>((ref) {
  // Mock determinístico: usa os últimos 2 chars do ID para simular dias
  // Isso garante que a mesma lista seja sempre consistente durante a sessão
  // REMOVER quando P-04 estiver disponível.
  return {}; // vazio por padrão; será populado na screen com os IDs reais
});