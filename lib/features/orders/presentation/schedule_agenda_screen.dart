import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart'; // Import do Supabase
import '../providers/appointments_provider.dart';
import 'create_appointment_screen.dart';
import 'checkout_screen.dart';

class ScheduleAgendaScreen extends ConsumerWidget {
  const ScheduleAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF1E1E1E), elevation: 0),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar agenda: $err', style: const TextStyle(color: Colors.red))),
        data: (appointments) {
          // Filtra os cancelados para não poluir a visualização principal
          final activeAppointments = appointments.where((a) => a['status'] != 'canceled').toList();

          if (activeAppointments.isEmpty) {
             return ListView(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    title: const Text('Hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('0 agendamentos', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    children: const [Padding(padding: EdgeInsets.all(32.0), child: Text('Agenda livre neste dia.'))],
                  ),
                ),
              ],
            );
          }

          final now = DateTime.now();
          final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

          // Agrupar os agendamentos pela data (DD/MM/YYYY)
          // Usamos LinkedHashMap (padrão do Dart) para manter a ordem de inserção.
          final Map<String, List<Map<String, dynamic>>> groupedAppointments = {};
          
          // FORÇAMOS O HOJE A SER O PRIMEIRO ELEMENTO SEMPRE
          groupedAppointments[todayStr] = [];
          
          for (var appt in activeAppointments) {
            final startTime = DateTime.parse(appt['start_time']).toLocal();
            // Formatar de forma simples sem pacotes extra: DD/MM/YYYY
            final dateStr = '${startTime.day.toString().padLeft(2, '0')}/${startTime.month.toString().padLeft(2, '0')}/${startTime.year}';
            
            if (!groupedAppointments.containsKey(dateStr)) {
              groupedAppointments[dateStr] = [];
            }
            groupedAppointments[dateStr]!.add(appt);
          }

          // Extraí e ordena todas as chaves (datas) explicitamente
          final keys = groupedAppointments.keys.toList();
          keys.remove(todayStr); // Retiramos para garantir que fica no topo

          // Ordenar as restantes datas cronologicamente ascendente (mais perto ao mais longe)
          keys.sort((a, b) {
            final partsA = a.split('/'); // DD/MM/YYYY
            final partsB = b.split('/');
            if (partsA.length != 3 || partsB.length != 3) return 0;
            
            final strA = '${partsA[2]}-${partsA[1]}-${partsA[0]}';
            final strB = '${partsB[2]}-${partsB[1]}-${partsB[0]}';
            return strA.compareTo(strB); 
          });

          // Constrói a lista final (Hoje sempre em 1º)
          final sortedKeys = [todayStr, ...keys];

          return ListView(
            children: sortedKeys.map((dateKey) {
              final bool isToday = dateKey == todayStr;
              final String displayTitle = isToday ? 'Hoje' : dateKey;
              final dayAppointments = groupedAppointments[dateKey]!;

              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isToday,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  title: Text(displayTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('${dayAppointments.length} agendamento(s)', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  children: dayAppointments.isEmpty 
                    ? [const Padding(padding: EdgeInsets.all(32.0), child: Text('Agenda livre neste dia.'))]
                    : dayAppointments.map((appt) => _buildAppointmentCard(context, ref, appt)).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAppointmentScreen()));
        },
        backgroundColor: Colors.white, foregroundColor: Colors.black, child: const Icon(Icons.add),
      ),
    );
  }

  // 1. O CARD AGORA É CLICÁVEL
  Widget _buildAppointmentCard(BuildContext context, WidgetRef ref, Map<String, dynamic> appt) {
    final startTime = DateTime.parse(appt['start_time']).toLocal();
    final endTime = DateTime.parse(appt['end_time']).toLocal();
    final timeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    final barberName = appt['barbers']['users']['name'];
    final clientName = appt['client_name'] ?? 'Cliente Avulso';

    // Verificar se o cliente é VIP
    final isVip = appt['clients']?['is_vip'] == true;

    // Status visual
    Color statusColor = appt['status'] == 'closed' ? Colors.green : Colors.orangeAccent;
    IconData statusIcon = appt['status'] == 'closed' ? Icons.check_circle : Icons.access_time;

    return InkWell(
      onTap: () => _showActionSheet(context, ref, appt), // ABRE AS OPÇÕES
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: statusColor, width: 4))),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4), Text('até', style: TextStyle(color: Colors.grey[500], fontSize: 12)), const SizedBox(height: 4),
                  Text(endTimeStr, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                ],
              ),
              const SizedBox(width: 16), Container(width: 1, height: 60, color: Colors.grey[800]), const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(
                        children: [
                          Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (isVip) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                          ],
                        ],
                      ),
                      Icon(statusIcon, color: statusColor, size: 18)
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [Icon(Icons.face, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Text('Barbeiro: $barberName', style: TextStyle(color: Colors.grey[500], fontSize: 12))]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. MENU INFERIOR DE OPÇÕES
  void _showActionSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> appt) {
    if (appt['status'] == 'closed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este atendimento já foi finalizado.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Gerenciar Agendamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                  title: const Text('Finalizar Atendimento (Checkout)'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckoutScreen(appointment: appt),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.red.withOpacity(0.2), child: const Icon(Icons.close, color: Colors.red)),
                  title: const Text('Cancelar Agendamento', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCancelDialog(context, ref, appt['id']); // ABRE O POP-UP DE MOTIVO
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. POP-UP DE CANCELAMENTO COM MOTIVO
  void _showCancelDialog(BuildContext context, WidgetRef ref, String orderId) {
    String selectedReason = 'Cliente não compareceu'; // Valor padrão
    final List<String> reasons = [
      'Cliente não compareceu',
      'Cancelado pelo cliente',
      'Atraso excessivo',
      'Imprevisto do Profissional',
      'Outro'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder permite atualizar o Radio button dentro do Dialog
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Cancelar Agendamento', style: TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Por favor, informe o motivo do cancelamento:'),
                  const SizedBox(height: 16),
                  ...reasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: Colors.red,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedReason = value!;
                        });
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    // Executa a atualização no Supabase
                    final supabase = ref.read(supabaseProvider);
                    try {
                      await supabase.from('orders').update({
                        'status': 'canceled',
                        'cancelation_reason': selectedReason,
                      }).eq('id', orderId);
                      
                      ref.invalidate(appointmentsProvider); // Atualiza a tela
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agendamento cancelado com sucesso!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: const Text('Confirmar Cancelamento'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}