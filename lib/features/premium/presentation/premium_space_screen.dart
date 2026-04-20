import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/presentation/create_appointment_screen.dart';
import '../../../core/supabase/providers.dart';

// ============================================================
// TODO(P-06 + P-07): Esta tela usa APENAS dados mockados.
//
// P-06 (Pedro): adicionar coluna `sector` (enum: barbearia, salao, premium)
//   nas tabelas `services` e `barbers` via migração Supabase.
//
// P-07 (Pedro): descrição TRUNCADA no plano — solicitar urgente.
//   Responsável por definir:
//   - Quais dados de faturamento serão exclusivos do setor premium
//   - Se há tabela/view separada ou filtro no existing schema
//   - O provider exato que o Ian deve consumir
//
// Quando P-07 estiver definido e P-06 entregue:
//   1. Criar premiumServicesProvider filtrando services por sector='premium'
//   2. Criar premiumRevenueProvider filtrando faturamento por sector='premium'
//   3. Substituir _mockPremiumServices e _mockKpis pelos providers reais
//   4. Remover os banners de aviso desta tela
// ============================================================

class PremiumSpaceScreen extends ConsumerWidget {
  const PremiumSpaceScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(permissionsProvider);
    final servicesAsync = ref.watch(servicesBySectorProvider('premium'));
    final metricsAsync = ref.watch(premiumMetricsProvider);

    return permissionsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: _gold))),
      error: (err, stack) => Scaffold(body: Center(child: Text('Erro: $err'))),
      data: (perm) {
        if (!perm.canAccessPremium) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_person_outlined, size: 72, color: _gold),
                  const SizedBox(height: 16),
                  const Text(
                    'Espaço Premium',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _gold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Acesso exclusivo ao Barbeiro Líder.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Espaço Premium',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.grey[600]),
            tooltip: 'Configurações de Setor',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Setor exclusivo com serviços e métricas premium.'),
                  backgroundColor: Color(0xFF2A2A2A),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dourado
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: _gold,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Espaço Premium',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Serviços e faturamento exclusivos',
                              style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // KPIs (reais)
                const Text(
                  'Desempenho do Mês',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                metricsAsync.when(
                  loading: () => Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(child: CircularProgressIndicator(color: _gold)),
                  ),
                  error: (err, stack) => Text('Erro: $err', style: const TextStyle(color: Colors.red)),
                  data: (metrics) {
                    final faturamento = (metrics['faturamento'] as num).toDouble();
                    final meta = (metrics['meta_mensal'] as num).toDouble();
                    final progressoPct = meta > 0 ? faturamento / meta : 0.0;
                    final atendimentos = metrics['atendimentos'].toString();
                    final ticketMedio = (metrics['ticket_medio'] as num).toDouble();

                    return Column(
                      children: [
                        // Card principal: faturamento + meta
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _gold.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.trending_up, color: _gold, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Faturamento Premium',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'R\$ ${faturamento.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Barra de progresso da meta
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressoPct.clamp(0.0, 1.0),
                                  backgroundColor: Colors.white10,
                                  color: _gold,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(progressoPct * 100).toStringAsFixed(0)}% da meta mensal '
                                '(R\$ ${meta.toStringAsFixed(0)})',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Grid de KPIs secundários
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiMini(
                                label: 'Atendimentos',
                                value: atendimentos,
                                icon: Icons.content_cut,
                                color: _gold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildKpiMini(
                                label: 'Ticket Médio',
                                value: 'R\$ ${ticketMedio.toStringAsFixed(0)}',
                                icon: Icons.confirmation_number_outlined,
                                color: _goldLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Lista de serviços
                const Text(
                  'Serviços Premium',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                servicesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
                  error: (err, stack) => Text('Erro: $err'),
                  data: (services) {
                    if (services.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: Text('Nenhum serviço premium cadastrado.', style: TextStyle(color: Colors.grey))),
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
                        itemCount: services.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final service = services[index];
                          final price = (service['price'] as num).toDouble().toStringAsFixed(2);
                          final duration = (service['duration_minutes'] ?? 30) as int;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                color: _gold,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              service['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(Icons.schedule, size: 11, color: Colors.grey[500]),
                                const SizedBox(width: 3),
                                Text(
                                  '${duration}min',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            trailing: Text(
                              'R\$ $price',
                              style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const CreateAppointmentScreen(sector: 'premium'),
            ),
          );
        },
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Novo Atendimento', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
      },
    );
  }

  Widget _buildKpiMini({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -16,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
