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
            error: (_, __) => const Text('Unidade'),
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
        return ListView(
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
                            color: Colors.green.withOpacity(0.2),
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
                      MaterialPageRoute(
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
                      backgroundColor: Colors.amber.withOpacity(0.2),
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
              error: (_, __) => const SizedBox.shrink(),
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
    final name = barber['users']?['name'] ?? 'Barbeiro';
    final avatarUrl = barber['users']?['avatar_url'] as String?;
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          backgroundColor: Colors.blueAccent.withOpacity(0.15),
          child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blueAccent)) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(barber['category'] as String? ?? 'Barbeiro', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: isLeader
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
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
        final fechadas = data['fechadas'] ?? 0;
        final abertas = data['abertas'] ?? 0;
        final ranking = data['ranking'] as List<Map<String, dynamic>>? ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _buildMetricCard('Faturamento', 'R\$ ${faturamento.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
                _buildMetricCard('Comissões', 'R\$ ${comissoes.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.purple),
                _buildMetricCard('Fechadas', '$fechadas', Icons.check_circle, Colors.blue),
                _buildMetricCard('Abertas', '$abertas', Icons.timelapse, Colors.orange),
              ],
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
                    if (idx == 0) { badgeColor = Colors.amber.withOpacity(0.3); textColor = Colors.amber; }
                    if (idx == 1) { badgeColor = Colors.grey.withOpacity(0.5); textColor = Colors.grey[400]!; }
                    if (idx == 2) { badgeColor = Colors.brown.withOpacity(0.5); textColor = Colors.orangeAccent; }

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
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(title.toUpperCase(), style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          ],
        ),
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

        return ListView.builder(
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
        );
      },
    );
  }
}
