import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/client_history_provider.dart';

class ClientDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientId = client['id'].toString();
    final historyAsync = ref.watch(clientHistoryProvider(clientId));

    final name = client['name'] ?? 'Cliente';
    final phone = client['phone'] ?? 'Sem telefone';
    final notes = client['notes'];
    final birthday = client['birthday'];
    final subscriptionPlan = client['subscription_plan']?.toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isPremium = subscriptionPlan == 'premium';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Cabeçalho do cliente ───────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: isPremium
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isPremium ? Colors.amber : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subscriptionPlan != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? Colors.amber.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPremium
                                  ? Colors.amber.withOpacity(0.5)
                                  : Colors.blue.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            isPremium ? '👑 Premium' : '⭐ Básico',
                            style: TextStyle(
                              color: isPremium ? Colors.amber : Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Informações básicas ────────────────────────────────────
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Telefone',
                  value: phone,
                ),
                if (birthday != null) ...[
                  const Divider(color: Colors.white10, height: 1),
                  _InfoRow(
                    icon: Icons.cake_outlined,
                    label: 'Aniversário',
                    value: _formatDate(birthday.toString()),
                  ),
                ],
                if (notes != null && notes.toString().isNotEmpty) ...[
                  const Divider(color: Colors.white10, height: 1),
                  _InfoRow(
                    icon: Icons.edit_note,
                    label: 'Observações',
                    value: notes.toString(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // ─── Histórico de serviços/produtos ────────────────────────
            const Text(
              'Histórico de Atendimentos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Erro ao carregar histórico: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Nenhum atendimento registrado ainda.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isService = item['type'] == 'service';
                    final itemName = item['name']?.toString() ?? 'Item';
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final date = item['date'] != null
                        ? _formatDate(item['date'].toString())
                        : 'Data desconhecida';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isService
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isService
                                  ? Icons.content_cut
                                  : Icons.inventory_2_outlined,
                              color: isService ? Colors.blue : Colors.purple,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'R\$ ${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}