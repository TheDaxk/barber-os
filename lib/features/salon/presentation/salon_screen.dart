import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/presentation/create_appointment_screen.dart';
import '../../../core/supabase/providers.dart';

// ============================================================
// TODO(P-06): Quando a migração do Pedro adicionar a coluna
// `sector` na tabela `services` (enum: barbearia, salao, premium),
// substituir os mockServices abaixo pelo provider real:
//
//   final salonServicesProvider = FutureProvider.autoDispose<...>((ref) async {
//     final supabase = ref.watch(supabaseProvider);
//     return await supabase.from('services').select('*').eq('sector', 'salao');
//   });
//
// E atualizar o build para usar ref.watch(salonServicesProvider).
// Confirmar com Pedro os valores exatos do enum antes de integrar.
// ============================================================

class SalonScreen extends ConsumerWidget {
  const SalonScreen({super.key});

  static const Color _salonPink = Color(0xFFEC407A);
  static const Color _salonBackground = Color(0xFF121212);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(permissionsProvider);
    final servicesAsync = ref.watch(servicesBySectorProvider('salao'));

    return permissionsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: _salonPink))),
      error: (err, stack) => Scaffold(body: Center(child: Text('Erro: $err'))),
      data: (perm) {
        if (!perm.canAccessSalon) {
          return Scaffold(
            backgroundColor: _salonBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 72, color: _salonPink),
                  const SizedBox(height: 16),
                  const Text(
                    'Acesso Restrito',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta tela é exclusiva para o setor Salão.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: _salonPink),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
      backgroundColor: _salonBackground,
      appBar: AppBar(
        title: const Text(
          'Salão de Beleza',
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
                  content: Text('Serviços configurados para o setor Salão.'),
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
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header com identidade visual
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _salonPink.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _salonPink.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _salonPink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.face_retouching_natural,
                                color: _salonPink,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Salão de Beleza',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Serviços exclusivos do setor Salão',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Serviços do Salão',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Grid de serviços (real)
              servicesAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _salonPink)),
                ),
                error: (err, stack) => SliverFillRemaining(
                  child: Center(child: Text('Erro ao carregar serviços: $err', style: const TextStyle(color: Colors.red))),
                ),
                data: (services) {
                  if (services.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.spa_outlined, size: 64, color: Colors.white10),
                            SizedBox(height: 16),
                            Text('Nenhum serviço de salão cadastrado.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final service = services[index];
                          return _SalonServiceCard(service: service);
                        },
                        childCount: services.length as int?,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const CreateAppointmentScreen(sector: 'salao'),
            ),
          );
        },
        backgroundColor: _salonPink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Agendamento', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  },
);
  }
}

class _SalonServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;

  const _SalonServiceCard({required this.service});

  static const Color _salonPink = Color(0xFFEC407A);

  @override
  Widget build(BuildContext context) {
    final price = (service['price'] as double).toStringAsFixed(2);
    final duration = service['duration_minutes'] as int;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _salonPink.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          // Barra de accent lateral rosa
          Positioned(
            left: -14,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: _salonPink,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.spa_outlined, color: _salonPink, size: 22),
              Flexible(
                child: Text(
                  service['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Text(
                    'R\$ $price',
                    style: const TextStyle(
                      color: _salonPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(
                        '${duration}min',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
