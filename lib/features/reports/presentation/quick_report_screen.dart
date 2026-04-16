import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

class QuickReportScreen extends ConsumerStatefulWidget {
  const QuickReportScreen({super.key});

  @override
  ConsumerState<QuickReportScreen> createState() => _QuickReportScreenState();
}

class _QuickReportScreenState extends ConsumerState<QuickReportScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      // Buscar comandas do dia
      final ordersResponse = await supabase
          .from('orders')
          .select('total, status, barbers(users(name))')
          .gte('start_time', startOfToday)
          .lte('start_time', endOfToday);

      final orders = List<Map<String, dynamic>>.from(ordersResponse);

      // Calcular KPIs
      double faturamento = 0;
      int comandasFechadas = 0;
      int comandasAbertas = 0;
      Map<String, double> comissoesPorBarbeiro = {};

      for (var order in orders) {
        final total = (order['total'] as num?)?.toDouble() ?? 0;
        final status = order['status'] as String;
        final barberName = (order['barbers']?['users']?['name'] ?? 'Não definido').toString();

        if (status == 'closed') {
          comandasFechadas++;
          faturamento += total;
          // Calcula comissão (40% padrão)
          comissoesPorBarbeiro[barberName] =
              (comissoesPorBarbeiro[barberName] ?? 0) + (total * 0.40);
        } else if (status == 'open') {
          comandasAbertas++;
        }
      }

      final totalComissoes = comissoesPorBarbeiro.values.fold(0.0, (a, b) => a + b);

      // Top barbeiros por faturamento
      final topBarbeiros = comissoesPorBarbeiro.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _reportData = {
          'faturamento': faturamento,
          'comandasFechadas': comandasFechadas,
          'comandasAbertas': comandasAbertas,
          'totalComissoes': totalComissoes,
          'topBarbeiros': topBarbeiros.take(5).toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatório: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    if (_reportData == null) return;

    final buffer = StringBuffer();
    buffer.writeln('=== RELATÓRIO RÁPIDO ===');
    buffer.writeln('Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');
    buffer.writeln('');
    buffer.writeln('FATURAMENTO: R\$ ${(_reportData!['faturamento'] as double).toStringAsFixed(2)}');
    buffer.writeln('COMANDAS FECHADAS: ${_reportData!['comandasFechadas']}');
    buffer.writeln('COMANDAS ABERTAS: ${_reportData!['comandasAbertas']}');
    buffer.writeln('TOTAL COMISSÕES: R\$ ${(_reportData!['totalComissoes'] as double).toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('TOP BARBEIROS:');

    final topBarbeiros = _reportData!['topBarbeiros'] as List;
    for (var i = 0; i < topBarbeiros.length; i++) {
      final entry = topBarbeiros[i] as MapEntry<String, double>;
      buffer.writeln('${i + 1}. ${entry.key}: R\$ ${entry.value.toStringAsFixed(2)}');
    }

    // Compartilhar usando ScaffoldMessenger (simplificado)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Relatório preparado! Copie os dados manualmente.'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Relatório Rápido',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Compartilhar Relatório',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData == null
              ? const Center(child: Text('Erro ao carregar dados'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Data do relatório
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.purple),
                            const SizedBox(width: 12),
                            Text(
                              'Relatório do Dia ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // KPIs principais
                      const Text('Visão Geral',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKPICard(
                              'Faturamento',
                              'R\$ ${(_reportData!['faturamento'] as double).toStringAsFixed(2)}',
                              Icons.attach_money,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKPICard(
                              'Comissões',
                              'R\$ ${(_reportData!['totalComissoes'] as double).toStringAsFixed(2)}',
                              Icons.account_balance_wallet,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKPICard(
                              'Fechadas',
                              '${_reportData!['comandasFechadas']}',
                              Icons.check_circle,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKPICard(
                              'Abertas',
                              '${_reportData!['comandasAbertas']}',
                              Icons.access_time,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Ranking de barbeiros
                      const Text('Ranking de Barbeiros',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildRankingCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKPICard(
      String title, String value, IconData icon, Color color) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard() {
    final topBarbeiros = _reportData!['topBarbeiros'] as List;

    if (topBarbeiros.isEmpty) {
      return Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('Sem dados de barbeiros ainda',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Column(
        children: topBarbeiros.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value as MapEntry<String, double>;
          final name = item.key;
          final revenue = item.value;

          Color circleColor = Colors.white10;
          Color textColor = Colors.white;
          if (idx == 0) {
            circleColor = Colors.amber.withOpacity(0.3);
            textColor = Colors.amber;
          } else if (idx == 1) {
            circleColor = Colors.grey.withOpacity(0.5);
            textColor = Colors.grey[400]!;
          } else if (idx == 2) {
            circleColor = Colors.brown.withOpacity(0.5);
            textColor = Colors.orangeAccent;
          }

          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(backgroundColor: circleColor, child: Text(
                    '${idx + 1}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text('R\$ ${revenue.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (idx < topBarbeiros.length - 1)
                const Divider(height: 1, color: Colors.white10),
            ],
          );
        }).toList(),
      ),
    );
  }
}
