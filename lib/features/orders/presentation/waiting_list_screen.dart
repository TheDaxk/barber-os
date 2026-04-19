import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appointments_provider.dart';

class WaitingListScreen extends ConsumerWidget {
  const WaitingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Lista de Espera', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro ao carregar lista de espera: $err',
              style: const TextStyle(color: Colors.red)),
        ),
        data: (appointments) {
          // Filtra apenas clientes em espera
          final waitingOrders = appointments
              .where((a) => a['status'] == 'waiting')
              .toList();

          if (waitingOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum cliente em espera',
                    style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A lista de espera está vazia',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: waitingOrders.length,
            itemBuilder: (context, index) {
              final order = waitingOrders[index];
              final clientName = (order['client_name'] ?? 'Cliente Avulso').toString();
              final barberName = (order['barbers']?['users']?['name'] ?? 'Não definido').toString();
              final startTime = DateTime.parse(order['start_time'] as String).toLocal();
              final horaStr =
                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

              return Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    clientName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Barbeiro: $barberName',
                          style: TextStyle(color: Colors.grey[400])),
                      Text('Hora: $horaStr',
                          style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Colors.orange, size: 20),
                    onPressed: () {
                      // TODO: Navegar para detalhes da comanda
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
