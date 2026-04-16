import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import 'financial_provider.dart';
import 'export_service.dart';

class FinancialScreen extends ConsumerStatefulWidget {
  const FinancialScreen({super.key});

  @override
  ConsumerState<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends ConsumerState<FinancialScreen> {
  final List<String> _monthNames = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  static const List<Map<String, dynamic>> _expenseCategories = [
    {'id': 'Aluguel', 'label': 'Aluguel', 'icon': Icons.home_outlined, 'color': 0xFFFF7043},
    {'id': 'Produtos', 'label': 'Produtos', 'icon': Icons.shopping_bag_outlined, 'color': 0xFF42A5F5},
    {'id': 'Energia', 'label': 'Energia', 'icon': Icons.bolt_outlined, 'color': 0xFFFFCA28},
    {'id': 'Água', 'label': 'Água', 'icon': Icons.water_drop_outlined, 'color': 0xFF26C6DA},
    {'id': 'Internet', 'label': 'Internet', 'icon': Icons.wifi, 'color': 0xFF7E57C2},
    {'id': 'Manutenção', 'label': 'Manutenção', 'icon': Icons.build_outlined, 'color': 0xFF8D6E63},
    {'id': 'Salários', 'label': 'Salários', 'icon': Icons.people_outline, 'color': 0xFF66BB6A},
    {'id': 'Marketing', 'label': 'Marketing', 'icon': Icons.campaign_outlined, 'color': 0xFFEC407A},
    {'id': 'Outros', 'label': 'Outros', 'icon': Icons.more_horiz, 'color': 0xFF78909C},
  ];

  void _showExpenseBottomSheet({Map<String, dynamic>? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final isEditing = expense != null;
        
        final descController = TextEditingController(text: isEditing ? (expense['description']?.toString() ?? '') : '');
        final amountController = TextEditingController(
          text: isEditing ? (expense['amount'] as num).toStringAsFixed(2).replaceAll('.', ',') : ''
        );
        
        String selectedCategory = isEditing ? (expense['category']?.toString() ?? 'Outros') : 'Outros';
        bool isSaving = false;
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Editar Despesa' : 'Nova Despesa', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: descController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Descrição (ex: Conta de Luz)', 
                        prefixIcon: const Icon(Icons.description_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        labelStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Valor (R\$)', 
                        prefixIcon: const Icon(Icons.money_off_outlined, color: Colors.grey),
                        hintText: '0,00',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        labelStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Categoria', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _expenseCategories.map((cat) {
                        final isSelected = selectedCategory == cat['id'];
                        final catColor = Color(cat['color'] as int);
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : catColor),
                              const SizedBox(width: 4),
                              Text(cat['label'] as String, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey[300])),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: catColor.withOpacity(0.8),
                          backgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? catColor : Colors.transparent)),
                          showCheckmark: false,
                          onSelected: (_) => setStateDialog(() => selectedCategory = cat['id'] as String),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              onPressed: (isSaving || isDeleting) ? null : () async {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.grey[900],
                                    title: const Text('Tem certeza?'),
                                    content: const Text('Esta despesa será apagada permanentemente.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  )
                                );
                                if (confirm != true) return;

                                setStateDialog(() => isDeleting = true);
                                try {
                                  await ref.read(supabaseProvider).from('expenses').delete().eq('id', expense['id'] as Object);
                                  ref.invalidate(monthlyExpensesProvider);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                                  setStateDialog(() => isDeleting = false);
                                }
                              },
                              icon: isDeleting 
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                  : const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              label: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent, width: 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, 
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: (isSaving || isDeleting) ? null : () async {
                              if (descController.text.trim().isEmpty || amountController.text.trim().isEmpty) return;

                              setStateDialog(() => isSaving = true);
                              final supabase = ref.read(supabaseProvider);

                              try {
                                final textAmount = amountController.text.replaceAll(',', '.');
                                final amount = double.tryParse(textAmount) ?? 0.0;

                                if (isEditing) {
                                  await supabase.from('expenses').update({
                                    'category': selectedCategory,
                                    'description': descController.text.trim(),
                                    'amount': amount,
                                  }).eq('id', expense['id'] as Object);
                                } else {
                                  final userId = supabase.auth.currentUser!.id;
                                  final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();
                                  await supabase.from('expenses').insert({
                                    'unit_id': userRes['unit_id'] as Object,
                                    'category': selectedCategory,
                                    'description': descController.text.trim(),
                                    'amount': amount,
                                    'expense_date': DateTime.now().toIso8601String().split('T')[0],
                                  });
                                }

                                ref.invalidate(monthlyExpensesProvider);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(isEditing ? 'Despesa atualizada!' : 'Despesa salva!'), backgroundColor: Colors.green
                                  ));
                                }
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                              } finally {
                                if (context.mounted) setStateDialog(() => isSaving = false);
                              }
                            },
                            child: isSaving 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text(isEditing ? 'Atualizar' : 'Salvar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _refreshData() async {
    ref.invalidate(monthlyRevenueProvider);
    ref.invalidate(monthlyExpensesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedMonthProvider);
    final revenueAsync = ref.watch(monthlyRevenueProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider);

    double faturamento = 0.0;
    double despesas = 0.0;
    int totalAtendimentos = 0;

    if (revenueAsync.hasValue) {
      final orders = revenueAsync.value!;
      totalAtendimentos = orders.length;
      for (var order in orders) {
        faturamento += (order['total'] as num).toDouble();
      }
    }

    if (expensesAsync.hasValue) {
      for (var exp in expensesAsync.value!) {
        despesas += (exp['amount'] as num).toDouble();
      }
    }

    double comissoes = faturamento * 0.40; 
    double lucroEstimado = faturamento - comissoes - despesas;
    double ticketMedio = totalAtendimentos > 0 ? (faturamento / totalAtendimentos) : 0.0;

    final monthLabel = '${_monthNames[selectedDate.month]} ${selectedDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar relatório',
            onPressed: () => _showExportBottomSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.grey[900],
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Financeiro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white70),
                      onPressed: () {
                        final current = ref.read(selectedMonthProvider);
                        ref.read(selectedMonthProvider.notifier).set(DateTime(current.year, current.month - 1, 1));
                      },
                    ),
                    Text(monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white70),
                      onPressed: () {
                        final current = ref.read(selectedMonthProvider);
                        ref.read(selectedMonthProvider.notifier).set(DateTime(current.year, current.month + 1, 1));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              revenueAsync.isLoading || expensesAsync.isLoading 
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : _buildMainCard(lucroEstimado),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _buildSmallCard('Faturamento', faturamento, Colors.greenAccent),
                  _buildSmallCard('Comissões (40%)', comissoes, Colors.orangeAccent),
                  _buildSmallCard('Despesas', despesas, Colors.redAccent),
                  _buildSmallCard('Ticket Médio', ticketMedio, Colors.blueAccent),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Despesas do Mês', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Erro: $err', style: const TextStyle(color: Colors.red)),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[900], 
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text('Nenhuma despesa lançada neste mês.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final exp = expenses[index];
                        final amountStr = (exp['amount'] as num).toStringAsFixed(2);
                        final dateParts = exp['expense_date'].toString().split('-');
                        final dateStr = '${dateParts[2]}/${dateParts[1]}';
                        final catId = exp['category']?.toString() ?? 'Outros';
                        final catInfo = _expenseCategories.firstWhere((c) => c['id'] == catId, orElse: () => _expenseCategories.last);
                        final catColor = Color(catInfo['color'] as int);

                        return ListTile(
                          onTap: () => _showExpenseBottomSheet(expense: exp),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(catInfo['icon'] as IconData, color: catColor, size: 20),
                          ),
                          title: Text(exp['description']?.toString() ?? catId, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('$catId • $dateStr', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('- R\$ $amountStr', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseBottomSheet(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Despesa', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMainCard(double lucro) {
    final isPositive = lucro >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPositive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3), 
          width: 1.5
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up : Icons.trending_down, 
                   color: isPositive ? Colors.greenAccent : Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text('Lucro Estimado do Mês', style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'R\$ ${lucro.toStringAsFixed(2)}',
            style: TextStyle(color: isPositive ? Colors.white : Colors.redAccent, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, double amount, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900], 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(
            'R\$ ${amount.toStringAsFixed(2)}',
            style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis
          ),
        ],
      ),
    );
  }

  void _showExportBottomSheet(BuildContext context) {
    String selectedFormat = 'pdf'; 
    String selectedPeriod = 'current_month'; 
    bool detailed = false;
    DateTimeRange? customRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Exportar Relatório',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Formato', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _FormatChip(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      selected: selectedFormat == 'pdf',
                      onTap: () => setSheet(() => selectedFormat = 'pdf'),
                    ),
                    const SizedBox(width: 8),
                    _FormatChip(
                      label: 'Excel',
                      icon: Icons.table_chart_outlined,
                      selected: selectedFormat == 'excel',
                      onTap: () => setSheet(() => selectedFormat = 'excel'),
                    ),
                    const SizedBox(width: 8),
                    _FormatChip(
                      label: 'CSV',
                      icon: Icons.grid_on,
                      selected: selectedFormat == 'csv',
                      onTap: () => setSheet(() => selectedFormat = 'csv'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Período', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PeriodChip(
                      label: 'Últimos 7 dias',
                      selected: selectedPeriod == '7days',
                      onTap: () => setSheet(() => selectedPeriod = '7days'),
                    ),
                    _PeriodChip(
                      label: 'Últimos 30 dias',
                      selected: selectedPeriod == '30days',
                      onTap: () => setSheet(() => selectedPeriod = '30days'),
                    ),
                    _PeriodChip(
                      label: 'Mês atual',
                      selected: selectedPeriod == 'current_month',
                      onTap: () => setSheet(() => selectedPeriod = 'current_month'),
                    ),
                    _PeriodChip(
                      label: 'Personalizado',
                      selected: selectedPeriod == 'custom',
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                          helpText: 'Selecione o período',
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.white,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E1E1E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (range != null) {
                          setSheet(() {
                            selectedPeriod = 'custom';
                            customRange = range;
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (selectedPeriod == 'custom' && customRange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${customRange!.start.day}/${customRange!.start.month}/${customRange!.start.year} → ${customRange!.end.day}/${customRange!.end.month}/${customRange!.end.year}',
                      style: const TextStyle(color: Colors.amber, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 20),
                if (selectedFormat == 'pdf') ...[
                  CheckboxListTile(
                    value: detailed,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gerar relatório detalhado',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: Text(
                      'Inclui cada atendimento com cliente e serviço realizado.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    activeColor: Colors.white,
                    checkColor: Colors.black,
                    onChanged: (v) => setSheet(() => detailed = v ?? false),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Gerar e Exportar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _generateExport(
                        format: selectedFormat,
                        period: selectedPeriod,
                        customRange: customRange,
                        detailed: detailed,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateExport({
    required String format,
    required String period,
    required bool detailed,
    DateTimeRange? customRange,
  }) async {
    final revenueAsync = ref.read(monthlyRevenueProvider);
    final expensesAsync = ref.read(monthlyExpensesProvider);

    if (!revenueAsync.hasValue || !expensesAsync.hasValue) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carregue os dados primeiro'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gerando $format...'), backgroundColor: Colors.blue),
        );
      }

      final range = ExportService.resolvePeriod(period, customRange);
      final orders = revenueAsync.value!;
      final expenses = expensesAsync.value!;

      await ExportService.exportTo(
        type: format,
        unitName: 'BarberOS',
        monthLabel: '',
        revenue: 0,
        expenses: expenses,
        orders: orders,
        range: range,
        detailed: detailed,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exportação concluída!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.white : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.black : Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? Colors.white : Colors.grey[800],
      labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? Colors.white : Colors.white12),
      ),
    );
  }
}