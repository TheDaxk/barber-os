import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../../core/providers/units_provider.dart';
import '../providers/dashboard_provider.dart';

class LeaderOverviewScreen extends ConsumerWidget {
  const LeaderOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);
    final selectedUnitId = ref.watch(selectedUnitIdProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Visão Geral', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(_getDateString(), style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
              const Spacer(),
              unitsAsync.when(
                loading: () => const SizedBox(),
                error: (err, stack) => const SizedBox(),
                data: (units) => _UnitDropdown(units: units, selectedId: selectedUnitId, ref: ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: dashboardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
            data: (data) => _buildContent(data),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKPIRow(data),
          const SizedBox(height: 28),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentOrdersCard(data['recentes'] as List<Map<String, dynamic>>)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildRankingCard(data['ranking'] as List<Map<String, dynamic>>)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildOperationalRow(data),
          const SizedBox(height: 28),
          _buildMonthResultCard(data),
        ],
      ),
    );
  }

  Widget _buildKPIRow(Map<String, dynamic> data) {
    final kpis = [
      {'label': 'Faturamento', 'value': 'R\$ ${(data['faturamento'] as double).toStringAsFixed(2)}', 'icon': Icons.attach_money, 'color': const Color(0xFF4CAF50)},
      {'label': 'Comandas Fechadas', 'value': '${data['fechadas']}', 'icon': Icons.check_circle_outline, 'color': Colors.blueAccent},
      {'label': 'Em Atendimento', 'value': '${data['abertas']}', 'icon': Icons.timelapse, 'color': Colors.orange},
      {'label': 'Total Comissões', 'value': 'R\$ ${(data['comissoes'] as double).toStringAsFixed(2)}', 'icon': Icons.account_balance_wallet_outlined, 'color': const Color(0xFFD4AF37)},
    ];

    return Row(
      children: kpis.map((kpi) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kpi['icon'] as IconData, color: kpi['color'] as Color, size: 26),
                const SizedBox(height: 12),
                Text(kpi['value'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(kpi['label'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildRecentOrdersCard(List<Map<String, dynamic>> orders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Últimas Comandas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sem movimentos hoje.', style: TextStyle(color: Colors.grey))))
          else
            ...orders.map((order) {
              final isClosed = order['status'] == 'closed';
              final total = ((order['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
              final barber = (order['barbers']?['users']?['name'] as String?) ?? '-';
              final client = (order['client_name'] as String?) ?? 'Avulso';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isClosed ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                      child: Icon(isClosed ? Icons.check : Icons.access_time, color: isClosed ? Colors.green : Colors.orange, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(barber, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    )),
                    Text('R\$ $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRankingCard(List<Map<String, dynamic>> ranking) {
    const colors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ranking do Dia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (ranking.isEmpty)
            const Center(child: Text('Sem dados ainda.', style: TextStyle(color: Colors.grey)))
          else
            ...ranking.asMap().entries.map((e) {
              final color = e.key < 3 ? colors[e.key] : Colors.grey[600]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text('${e.key + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Text('R\$ ${(e.value['revenue'] as double).toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOperationalRow(Map<String, dynamic> data) {
    final items = [
      {'label': 'Em Espera', 'value': '${data['waiting_count']}', 'color': Colors.orange, 'icon': Icons.hourglass_empty_rounded},
      {'label': 'Barbeiros Ativos', 'value': '${data['active_barbers']}', 'color': Colors.blueAccent, 'icon': Icons.people_outline},
      {'label': 'Próximos Agend.', 'value': '${(data['upcoming'] as List).length}', 'color': Colors.purple, 'icon': Icons.schedule},
    ];
    return Row(
      children: items.map((item) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: item['color'] as Color, width: 3)),
            ),
            child: Row(
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['value'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(item['label'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildMonthResultCard(Map<String, dynamic> data) {
    final revenue = (data['faturamento'] as double? ?? 0);
    final expenses = (data['total_expenses'] as double? ?? 0);
    final result = revenue - expenses;
    final isPositive = result >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPositive ? Colors.green.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ResultItem(label: 'Receitas', value: revenue, color: Colors.green),
          const Icon(Icons.remove, color: Colors.grey),
          _ResultItem(label: 'Despesas', value: expenses, color: Colors.red),
          const Icon(Icons.drag_handle, color: Colors.grey),
          _ResultItem(
            label: 'Resultado',
            value: result,
            color: isPositive ? Colors.green : Colors.red,
            bold: true,
          ),
        ],
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    final days = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    final months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
  }
}

class _UnitDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> units;
  final String? selectedId;
  final WidgetRef ref;

  const _UnitDropdown({required this.units, required this.selectedId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = units.firstWhere(
      (u) => u['id'] == selectedId,
      orElse: () => {'name': 'Todas as Unidades'},
    );

    return PopupMenuButton<String?>(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined, size: 16, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Text(selected['name'] as String? ?? 'Unidade', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
      onSelected: (id) {
        ref.read(selectedUnitIdProvider.notifier).state = id;
        ref.invalidate(dashboardProvider);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('Todas as Unidades')),
        const PopupMenuDivider(),
        ...units.map((u) => PopupMenuItem(
          value: u['id'] as String,
          child: Text(u['name'] as String? ?? 'Unidade'),
        )),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;

  const _ResultItem({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          'R\$ ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: bold ? 18 : 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
