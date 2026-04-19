import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_metrics_provider.dart';
import '../../units/providers/units_provider.dart';
import '../../../core/supabase/providers.dart';

class EmployeeDetailsScreen extends ConsumerWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onEdit;

  const EmployeeDetailsScreen({
    super.key,
    required this.employee,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String userName = employee['users']?['name']?.toString() ?? 'Sem Nome';
    final String userEmail = employee['users']?['email']?.toString() ?? 'Sem E-mail';
    final String userPhone = employee['users']?['phone']?.toString() ?? 'Sem Telefone';
    final String unitName = employee['unit_name']?.toString() ?? 'Sem Unidade';
    final String category = employee['category']?.toString() ?? 'Barbeiro';
    final commission = employee['commission_rate'] ?? 40;
    
    // Obter as métricas
    final metricsAsync = ref.watch(barberMetricsProvider(employee['id'] as String));

    // Decorar a categoria
    IconData catIcon = Icons.content_cut;
    if (category == 'Barbeiro Líder') catIcon = Icons.workspace_premium;
    if (category == 'Barbeiro Pro Max') catIcon = Icons.star;
    if (category == 'Barbeiro Pro') catIcon = Icons.star_border;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_outlined, color: Colors.orange),
            onPressed: () => _showTransferDialog(context, ref),
            tooltip: 'Transferir de Unidade',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
            onPressed: onEdit,
            tooltip: 'Editar Profissional',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               // Header de Perfil
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                child: Icon(catIcon, color: Colors.blueAccent, size: 48),
              ),
              const SizedBox(height: 16),
              Text(userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.email_outlined, color: Colors.grey[400], size: 14),
                  const SizedBox(width: 4),
                  Text(userEmail, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_outlined, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text(userPhone, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on_outlined, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(unitName, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                ],
              ),
              
              const SizedBox(height: 24),
              // Tags da Função / Comissão
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(20)),
                    child: Text(category.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text('$commission% COMISSÃO', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Seção de Performance
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Performance (Mês Atual)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              
              metricsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                ),
                error: (err, stack) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('Erro ao carregar métricas: $err', style: const TextStyle(color: Colors.redAccent)),
                ),
                data: (metrics) {
                  final totalAppointments = metrics['totalAppointments'] as int;
                  final totalRevenue = metrics['totalRevenue'] as double;
                  
                  return Column(
                    children: [
                      // Cards de Métricas
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Atendimentos',
                              value: totalAppointments.toString(),
                              icon: Icons.check_circle_outline,
                              color: Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Receita Gerada',
                              value: 'R\$ ${totalRevenue.toStringAsFixed(2)}',
                              icon: Icons.trending_up,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Card Top Serviços
                      _buildTopServicesCard(metrics),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTopServicesCard(Map<String, dynamic> metrics) {
    final topServices = metrics['topServices'] as List<Map<String, dynamic>>;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                topServices.isEmpty ? 'Top Serviços' : 'Top Serviços',
                style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topServices.isEmpty)
            Text(
              'Nenhum serviço registrado ainda.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          else
            ...topServices.asMap().entries.map((entry) {
              final idx = entry.key;
              final service = entry.value;
              final name = service['name'] ?? 'Serviço';
              final count = service['count'] ?? 0;

              Color medalColor = Colors.grey;
              if (idx == 0) medalColor = Colors.amber;
              if (idx == 1) medalColor = Colors.grey[400]!;
              if (idx == 2) medalColor = Colors.orangeAccent;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: medalColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: medalColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$count atend.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showTransferDialog(BuildContext context, WidgetRef ref) async {
    final unitsAsync = await ref.read(unitsProvider.future);
    final units = unitsAsync;

    if (!context.mounted) return;

    String? selectedUnitId = employee['unit_id'] as String?;
    bool isLoading = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Transferir de Unidade', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione a nova unidade:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedUnitId,
                dropdownColor: Colors.grey[800],
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
                items: units.map((unit) {
                  return DropdownMenuItem(
                    value: unit['id'] as String,
                    child: Text(unit['name'] as String? ?? 'Unidade'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedUnitId = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedUnitId == null) return;
                      setState(() => isLoading = true);
                      Navigator.pop(context, selectedUnitId);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: isLoading 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Transferir'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == employee['unit_id']) return;

    final supabase = ref.read(supabaseProvider);

    // Verificar sessão antes de escrever
    final session = supabase.auth.currentSession;
    if (session == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão expirada. Faça login novamente.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      // Atualiza a unidade do barbeiro na tabela barbers
      await supabase
          .from('barbers')
          .update({'unit_id': result})
          .eq('id', employee['id'] as Object);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barbeiro transferido com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volta para a lista
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao transferir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
