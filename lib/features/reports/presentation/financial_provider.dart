import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// 1. Guarda qual mês o usuário está visualizando (Padrão: Mês atual)
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void set(DateTime date) => state = date;
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

// 2. Busca TODAS as comandas fechadas daquele mês
final monthlyRevenueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedDate = ref.watch(selectedMonthProvider);

  final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1).toIso8601String();
  final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59).toIso8601String();

  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

  final response = await supabase
      .from('orders')
      .select('id, total, closed_at, client_name, payment_method, barbers(users(name))')
      .eq('unit_id', userRes['unit_id'] as Object)
      .eq('status', 'closed')
      .gte('closed_at', startOfMonth)
      .lte('closed_at', endOfMonth);

  return List<Map<String, dynamic>>.from(response);
});

// 3. Busca TODAS as despesas daquele mês
final monthlyExpensesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedDate = ref.watch(selectedMonthProvider);

  final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
  final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
  final firstDayStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-01';
  final lastDayStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

  final response = await supabase
      .from('expenses')
      .select('id, category, description, amount, expense_date')
      .eq('unit_id', userRes['unit_id'] as Object)
      .gte('expense_date', firstDayStr)
      .lte('expense_date', lastDayStr)
      .order('expense_date', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});