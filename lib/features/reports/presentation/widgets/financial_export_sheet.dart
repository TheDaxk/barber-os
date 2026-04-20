import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../financial_provider.dart';
import '../export_service.dart';

class FinancialExportSheet extends ConsumerStatefulWidget {
  const FinancialExportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FinancialExportSheet(),
    );
  }

  @override
  ConsumerState<FinancialExportSheet> createState() => _FinancialExportSheetState();
}

class _FinancialExportSheetState extends ConsumerState<FinancialExportSheet> {
  String selectedFormat = 'pdf';
  String selectedPeriod = '7days';
  DateTimeRange? customRange;
  bool detailed = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Formato', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _FormatChip(
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    selected: selectedFormat == 'pdf',
                    onTap: () => setState(() => selectedFormat = 'pdf'),
                  ),
                  const SizedBox(width: 12),
                  _FormatChip(
                    label: 'Excel',
                    icon: Icons.table_chart_outlined,
                    selected: selectedFormat == 'excel',
                    onTap: () => setState(() => selectedFormat = 'excel'),
                  ),
                  const SizedBox(width: 12),
                  _FormatChip(
                    label: 'CSV',
                    icon: Icons.grid_on,
                    selected: selectedFormat == 'csv',
                    onTap: () => setState(() => selectedFormat = 'csv'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Período', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PeriodChip(
                    label: 'Últimos 7 dias',
                    selected: selectedPeriod == '7days',
                    onTap: () => setState(() => selectedPeriod = '7days'),
                  ),
                  _PeriodChip(
                    label: 'Últimos 30 dias',
                    selected: selectedPeriod == '30days',
                    onTap: () => setState(() => selectedPeriod = '30days'),
                  ),
                  _PeriodChip(
                    label: 'Mês atual',
                    selected: selectedPeriod == 'current_month',
                    onTap: () => setState(() => selectedPeriod = 'current_month'),
                  ),
                  _PeriodChip(
                    label: 'Personalizado',
                    selected: selectedPeriod == 'custom',
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
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
                        setState(() {
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
              const SizedBox(height: 24),
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
                  onChanged: (v) => setState(() => detailed = v ?? false),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Gerar e Exportar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateExport();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateExport() async {
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
          SnackBar(content: Text('Gerando $selectedFormat...'), backgroundColor: Colors.blue),
        );
      }

      final range = ExportService.resolvePeriod(selectedPeriod, customRange);
      final orders = revenueAsync.value!;
      final expenses = expensesAsync.value!;

      await ExportService.exportTo(
        type: selectedFormat,
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
