import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../orders/presentation/create_appointment_screen.dart';
import '../../orders/presentation/waiting_list_screen.dart';
import '../../reports/presentation/quick_report_screen.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../../core/providers/units_provider.dart';
import '../../../core/supabase/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _refreshData() async {
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    final userProfileAsync = ref.watch(userProfileProvider);
    final isLeader = userProfileAsync.maybeWhen(
      data: (u) => u['category'] == 'Barbeiro Líder' || u['role'] == 'admin',
      orElse: () => false,
    );
    final selectedUnitId = ref.watch(selectedUnitIdProvider);

    // Obter data em português
    final now = DateTime.now();
    final diasSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    final meses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    final hojeStr = '${diasSemana[now.weekday - 1]}-feira, ${now.day} de ${meses[now.month - 1]} de ${now.year}';

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.grey[900],
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho dinâmico
            if (isLeader)
              _buildUnitSelectorHeader(selectedUnitId)
            else
              const Text(
                'Minha Unidade',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 4),
            Text(
              hojeStr,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),

            // Seção: Ações Rápidas
            _buildQuickActions(),
            const SizedBox(height: 24),

            dashboardAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (err, stack) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
              data: (data) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seção 1: KPIs do Dia
                    const Text('Visão Geral de Hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _buildKPIGrid(data),
                    const SizedBox(height: 32),

                    // Seção: Informações Operacionais
                    _buildOperationalInfo(data),
                    const SizedBox(height: 32),

                    // Seção 2: Últimas Comandas
                    const Text('Últimas Comandas (Hoje)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildRecentOrders(data['recentes'] as List<Map<String, dynamic>>),
                    const SizedBox(height: 32),

                    // Seção 3: Ranking de Barbeiros
                    const Text('Ranking (Hoje)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _buildRanking(data['ranking'] as List<Map<String, dynamic>>),
                  ],
                );
              },
            ),
            const SizedBox(height: 80), // Margem inferior extra
          ],
        ),
      ),
    );
  }

  // COMPONENTE: Grid de KPIs
  Widget _buildKPIGrid(Map<String, dynamic> data) {
    final faturamentoStr = (data['faturamento'] as double).toStringAsFixed(2);
    final comissoesStr = (data['comissoes'] as double).toStringAsFixed(2);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildKPICard('Faturamento', 'R\$ $faturamentoStr', Icons.attach_money, Colors.green),
        _buildKPICard('Comandas Fechadas', '${data['fechadas']}', Icons.check_circle_outline, Colors.blue),
        _buildKPICard('Comandas Abertas', '${data['abertas']}', Icons.timelapse, Colors.orange),
        _buildKPICard('Total Comissões', 'R\$ $comissoesStr', Icons.account_balance_wallet_outlined, Colors.purple),
      ],
    );
  }

  // COMPONENTE: Card Individual de KPI
  Widget _buildKPICard(String title, String value, IconData icon, Color iconColor) {
    return Card(
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[400]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // COMPONENTE: Lista de Últimas Comandas
  Widget _buildRecentOrders(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
        child: const Text('Sem movimentos hoje ainda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isClosed = order['status'] == 'closed';
        final barberName = order['barbers']?['users']?['name'] ?? 'Sem Barbeiro';
        final clientName = order['client_name'] ?? 'Cliente Avulso';
        final priceStr = ((order['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
        
        DateTime startTime = DateTime.parse(order['start_time'] as String).toLocal();
        final horaMesa = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isClosed ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            child: Icon(
              isClosed ? Icons.check : Icons.access_time,
              color: isClosed ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          title: Text(clientName?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('$barberName • $horaMesa', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('R\$ $priceStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                isClosed ? 'Fechada' : 'Aberta',
                style: TextStyle(
                  fontSize: 12,
                  color: isClosed ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // COMPONENTE: Ranking de Barbeiros
  Widget _buildRanking(List<Map<String, dynamic>> ranking) {
    if (ranking.isEmpty) {
      return const SizedBox.shrink(); // Hide if no data yet
    }

    return Card(
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Column(
        children: ranking.asMap().entries.map((entry) {
          int idx = entry.key;
          var data = entry.value;
          
          final row = _buildRankingRow(
            (idx + 1).toString(),
            data['name']?.toString() ?? '',
            'R\$ ${(data['revenue'] as double).toStringAsFixed(2)}',
            '${data['count']} atend.'
          );
          
          if (idx == ranking.length - 1) return row; // Último item, sem divider
          
          return Column(
            children: [
              row, 
              const Divider(height: 1, color: Colors.white10)
            ]
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingRow(String position, String name, String revenue, String count) {
    // Top 3 Ganha cores
    Color circleColor = Colors.white10;
    Color textColor = Colors.white;
    if (position == '1') { circleColor = Colors.amber.withOpacity(0.3); textColor = Colors.amber; }
    if (position == '2') { circleColor = Colors.grey.withOpacity(0.5); textColor = Colors.grey[400]!; }
    if (position == '3') { circleColor = Colors.brown.withOpacity(0.5); textColor = Colors.orangeAccent; }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: circleColor,
        child: Text(position, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(count, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: Text(revenue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }

  // COMPONENTE: Ações Rápidas
  Widget _buildQuickActions() {
    final actions = [
      {
        'icon': Icons.add_circle_outline,
        'label': 'Nova Comanda',
        'color': Colors.green,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateAppointmentScreen()),
          );
        },
      },
      {
        'icon': Icons.people_outline,
        'label': 'Ver Agenda',
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WaitingListScreen()),
          );
        },
      },
      {
        'icon': Icons.bar_chart_outlined,
        'label': 'Relatório Rápido',
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuickReportScreen()),
          );
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: actions.map((action) {
            return GestureDetector(
              onTap: action['onTap'] as void Function()?,
              child: Card(
                elevation: 2,
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        color: action['color'] as Color,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[300],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // COMPONENTE: Informações Operacionais
  Widget _buildOperationalInfo(Map<String, dynamic> data) {
    final upcomingOrders = data['upcoming'] as List<Map<String, dynamic>>;
    final waitingCount = data['waiting_count'] as int;
    final activeBarbersCount = data['active_barbers'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Operacional',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Linha 1: Clientes em Espera
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: waitingCount > 0
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    child: Icon(
                      waitingCount > 0 ? Icons.access_time : Icons.check,
                      color: waitingCount > 0 ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Clientes em Espera',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    waitingCount > 0
                        ? '$waitingCount cliente${waitingCount > 1 ? 's' : ''} aguardando'
                        : 'Nenhum cliente aguardando',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  trailing: Text(
                    waitingCount.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: waitingCount > 0 ? Colors.orange : Colors.green,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),

                // Linha 2: Barbeiros Ativos
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    child: Icon(
                      Icons.people_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Barbeiros Ativos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    activeBarbersCount > 0
                        ? '$activeBarbersCount barbeiro${activeBarbersCount > 1 ? 's' : ''} trabalhando hoje'
                        : 'Sem barbeiros ativos hoje',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  trailing: Text(
                    activeBarbersCount.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),

                // Linha 3: Próximos Agendamentos
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    child: Icon(
                      Icons.schedule_outlined,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Próximos Agendamentos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    upcomingOrders.isNotEmpty
                        ? '${upcomingOrders.length} agendamento${upcomingOrders.length > 1 ? 's' : ''} futuro${upcomingOrders.length > 1 ? 's' : ''}'
                        : 'Sem agendamentos futuros hoje',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  trailing: Text(
                    upcomingOrders.length.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelectorHeader(String? selectedUnitId) {
    final unitsAsync = ref.watch(unitsProvider);

    return unitsAsync.when(
      loading: () => const Text('Carregando...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      error: (_, __) => const Text('Erro ao carregar unidades'),
      data: (units) {
        final selectedUnit = units.firstWhere(
          (u) => u['id'] == selectedUnitId,
          orElse: () => {'name': 'Todas as Unidades'},
        );

        return InkWell(
          onTap: () => _showUnitPicker(units),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedUnit['name'] as String? ?? 'Unidade',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 22),
            ],
          ),
        );
      },
    );
  }

  void _showUnitPicker(List<Map<String, dynamic>> units) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Selecionar Unidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.home_outlined, color: Colors.grey),
                title: const Text('Minha Unidade (Padrão)'),
                trailing: ref.read(selectedUnitIdProvider) == null
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  ref.read(selectedUnitIdProvider.notifier).state = null;
                  ref.invalidate(dashboardProvider);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              ...units.map((unit) {
                final isSelected = ref.read(selectedUnitIdProvider) == unit['id'];
                return ListTile(
                  leading: const Icon(Icons.store_outlined, color: Colors.blueAccent),
                  title: Text(unit['name'] as String? ?? 'Unidade'),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    ref.read(selectedUnitIdProvider.notifier).state = unit['id'] as String;
                    ref.invalidate(dashboardProvider);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}