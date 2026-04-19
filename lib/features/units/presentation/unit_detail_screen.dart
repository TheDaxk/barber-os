import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/units_provider.dart';
import '../providers/business_hours_provider.dart';
import 'business_hours_screen.dart';

class UnitDetailScreen extends ConsumerWidget {
  final String unitId;

  const UnitDetailScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitAsync = ref.watch(unitDetailProvider(unitId));
    final metricsAsync = ref.watch(unitMetricsProvider(unitId));
    final ordersAsync = ref.watch(unitOrdersProvider(unitId));
    final barbersAsync = ref.watch(unitBarbersProvider(unitId));
    final businessHoursAsync = ref.watch(unitBusinessHoursProvider(unitId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: unitAsync.when(
            data: (unit) => Text((unit['name'] as String?) ?? 'Unidade'),
            loading: () => const Text('Carregando...'),
            error: (err, stack) => const Text('Unidade'),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Info'),
              Tab(text: 'Financeiro'),
              Tab(text: 'Agendamentos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab Info
            _InfoTab(
              unitId: unitId,
              barbersAsync: barbersAsync,
              unitAsync: unitAsync,
              businessHoursAsync: businessHoursAsync,
              unitName: unitAsync.maybeWhen(
                data: (unit) => (unit['name'] as String?) ?? 'Unidade',
                orElse: () => 'Unidade',
              ),
            ),

            // Tab Financeiro
            _FinanceTab(metricsAsync: metricsAsync),

            // Tab Agendamentos
            _OrdersTab(ordersAsync: ordersAsync),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final String unitId;
  final String unitName;
  final AsyncValue<List<Map<String, dynamic>>> barbersAsync;
  final AsyncValue<Map<String, dynamic>> unitAsync;
  final AsyncValue<List<BusinessHour>> businessHoursAsync;

  const _InfoTab({
    required this.unitId,
    required this.unitName,
    required this.barbersAsync,
    required this.unitAsync,
    required this.businessHoursAsync,
  });

  @override
  Widget build(BuildContext context) {
    return unitAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
      data: (unit) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.business, color: Colors.green, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((unit['name'] as String?) ?? 'Sem Nome', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  if (unit['location'] != null && unit['location'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(unit['location'] as String, style: TextStyle(color: Colors.grey[400])),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (unit['phone'] != null && unit['phone'].toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.phone, color: Colors.grey, size: 18),
                              const SizedBox(width: 8),
                              Text(unit['phone'] as String, style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Horário de Funcionamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.green, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => BusinessHoursScreen(
                              unitId: unitId,
                              unitName: unitName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildScheduleCard(businessHoursAsync),

                const SizedBox(height: 24),
                const Text('Responsável', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                barbersAsync.when(
                  loading: () => Card(
                    color: Colors.grey[900],
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (err, _) => Card(
                    color: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                  data: (barbers) {
                    if (barbers.isEmpty) {
                      return Card(
                        color: Colors.grey[900],
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Nenhum barbeiro nesta unidade', style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }
                    final responsable = barbers.first;
                    final name = (responsable['users']?['name'] as String?) ?? 'Desconhecido';
                    final category = responsable['category'] ?? '';
                    return Card(
                      color: Colors.grey[900],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                          child: const Icon(Icons.star, color: Colors.amber),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(category as String, style: TextStyle(color: Colors.grey[400])),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Text('Equipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                barbersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (barbers) {
                    if (barbers.isEmpty) return const SizedBox.shrink();

                    final leader = barbers.where((b) => b['category'] == 'Barbeiro Líder').toList();
                    final others = barbers.where((b) => b['category'] != 'Barbeiro Líder').toList();

                    return Column(
                      children: [
                        ...leader.map((b) => _BarberTile(barber: b, isLeader: true)),
                        ...others.map((b) => _BarberTile(barber: b, isLeader: false)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(AsyncValue<List<BusinessHour>> businessHoursAsync) {
    const nomes = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    const dias = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];

    return businessHoursAsync.when(
      loading: () => Card(
        color: Colors.grey[900],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (hours) {
        return Card(
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(7, (i) {
                final dia = dias[i];
                final hour = hours.where((h) => h.day == dia).firstOrNull;
                final isOpen = hour?.isOpen ?? true;
                final openTime = hour?.openTime ?? '--:--';
                final closeTime = hour?.closeTime ?? '--:--';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(nomes[i], style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        isOpen ? '$openTime - $closeTime' : 'Fechado',
                        style: TextStyle(color: isOpen ? Colors.grey[400] : Colors.red),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _BarberTile extends StatelessWidget {
  final Map<String, dynamic> barber;
  final bool isLeader;
  const _BarberTile({required this.barber, required this.isLeader});

  @override
  Widget build(BuildContext context) {
    final String name = barber['users']?['name']?.toString() ?? 'Barbeiro';
    final avatarUrl = barber['users']?['avatar_url'] as String?;
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
          child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blueAccent)) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(barber['category'] as String? ?? 'Barbeiro', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: isLeader
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Text('Responsável', style: TextStyle(fontSize: 11, color: Colors.amber)),
              )
            : null,
      ),
    );
  }
}

class _FinanceTab extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> metricsAsync;

  const _FinanceTab({required this.metricsAsync});

  @override
  Widget build(BuildContext context) {
    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
      data: (data) {
        final faturamento = (data['faturamento'] as num?)?.toDouble() ?? 0.0;
        final comissoes = (data['comissoes'] as num?)?.toDouble() ?? 0.0;
        final despesas = (data['despesas'] as num?)?.toDouble() ?? 0.0;
        final ticketMedio = (data['ticket_medio'] as num?)?.toDouble() ?? 0.0;
        final ranking = data['ranking'] as List<Map<String, dynamic>>? ?? [];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 700;
                    return GridView.count(
                      crossAxisCount: isDesktop ? 3 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isDesktop ? 1.8 : 3.8,
                      children: [
                        _buildKpiCard('Faturamento', faturamento, Icons.trending_up_rounded, Colors.greenAccent),
                        _buildKpiCard('Comissões', comissoes, Icons.handshake_outlined, Colors.orangeAccent),
                        _buildKpiCard('Despesas', despesas, Icons.receipt_long_outlined, Colors.redAccent),
                        _buildKpiCard('Ticket Médio', ticketMedio, Icons.confirmation_number_outlined, Colors.blueAccent),
                        _buildKpiCard('Fechadas', (data['fechadas'] as num?)?.toDouble() ?? 0.0, Icons.check_circle_outline, Colors.cyanAccent, isCurrency: false),
                        _buildKpiCard('Abertas', (data['abertas'] as num?)?.toDouble() ?? 0.0, Icons.timelapse_outlined, Colors.amber, isCurrency: false),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text('Ranking de Barbeiros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (ranking.isEmpty)
                  Card(
                    color: Colors.grey[900],
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Nenhum dado hoje', style: TextStyle(color: Colors.grey))),
                    ),
                  )
                else
                  Card(
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: ranking.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final name = (item['name'] as String?) ?? 'Desconhecido';
                        final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
                        final count = item['count'] ?? 0;

                        Color badgeColor = Colors.white10;
                        Color textColor = Colors.white;
                        if (idx == 0) { badgeColor = Colors.amber.withValues(alpha: 0.3); textColor = Colors.amber; }
                        if (idx == 1) { badgeColor = Colors.grey.withValues(alpha: 0.5); textColor = Colors.grey[400]!; }
                        if (idx == 2) { badgeColor = Colors.brown.withValues(alpha: 0.5); textColor = Colors.orangeAccent; }

                        return ListTile(
                          leading: CircleAvatar(backgroundColor: badgeColor, child: Text('${idx + 1}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('$count atendimento${count != 1 ? 's' : ''}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          trailing: Text('R\$ ${revenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String title, double value, IconData icon, Color accentColor, {bool isCurrency = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isCurrency ? 'R\$ ${value.toStringAsFixed(2)}' : value.toInt().toString(),
                    style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> ordersAsync;

  const _OrdersTab({required this.ordersAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 64, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text('Nenhum agendamento hoje', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final startTime = DateTime.parse(order['start_time'] as String).toLocal();
                final endTime = DateTime.parse(order['end_time'] as String).toLocal();
                final timeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
                final clientName = (order['client_name'] as String?) ?? 'Cliente Avulso';
                final barberName = (order['barbers']?['users']?['name'] as String?) ?? 'Sem Barbeiro';
                final status = (order['status'] as String?) ?? 'open';
                final isClosed = status == 'closed';
                final total = (order['total'] as num?)?.toDouble() ?? 0.0;

                return Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isClosed ? Colors.green : Colors.orange, width: 3),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('até', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                        Text(endTimeStr, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                    title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(barberName, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(isClosed ? 'Fechada' : 'Aberta', style: TextStyle(color: isClosed ? Colors.green : Colors.orange, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
