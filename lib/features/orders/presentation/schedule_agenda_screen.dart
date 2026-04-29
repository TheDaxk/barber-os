import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../../core/presentation/widgets/page_header.dart';
import '../providers/appointments_provider.dart';
import '../providers/schedule_lock_provider.dart';
import '../../units/providers/business_hours_provider.dart';
import '../../../core/rbac/app_permissions.dart';
import 'create_appointment_screen.dart';
import 'checkout_screen.dart';

class ScheduleAgendaScreen extends ConsumerStatefulWidget {
  const ScheduleAgendaScreen({super.key});

  @override
  ConsumerState<ScheduleAgendaScreen> createState() =>
      _ScheduleAgendaScreenState();
}

class _ScheduleAgendaScreenState extends ConsumerState<ScheduleAgendaScreen> {
  DateTime _selectedDate = DateTime.now();

  static const Color _gold = Color(0xFFD4AF37);

  // Nomes dos dias da semana em pt-BR
  static const List<String> _weekDayNames = [
    'segunda-feira', 'terça-feira', 'quarta-feira',
    'quinta-feira', 'sexta-feira', 'sábado', 'domingo',
  ];

  static const List<String> _monthNames = [
    '', 'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  String _dayOfWeekToName(int weekday) {
    const days = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
    return days[weekday - 1];
  }

  String get _formattedDate {
    final weekDay = _weekDayNames[_selectedDate.weekday - 1];
    final day = _selectedDate.day;
    final month = _monthNames[_selectedDate.month];
    return '$weekDay, $day de $month';
  }

  List<String> _generateTimeSlots({int startHour = 9, int endHour = 19}) {
    final List<String> slots = [];
    for (int h = startHour; h < endHour; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    slots.add('${endHour.toString().padLeft(2, '0')}:00');
    return slots;
  }

  // Retorna o agendamento que ocupa esse slot (se houver)
  Map<String, dynamic> _getSlotData(
    String slot,
    List<Map<String, dynamic>> appointments,
  ) {
    final parts = slot.split(':');
    final slotMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

    List<Map<String, dynamic>> starting = [];
    Set<String> blockedBarberIds = {};

    for (final appt in appointments) {
      if (appt['status'] == 'canceled') continue;
      final start = DateTime.parse(appt['start_time'] as String).toLocal();
      final end = DateTime.parse(appt['end_time'] as String).toLocal();

      if (start.year != _selectedDate.year ||
          start.month != _selectedDate.month ||
          start.day != _selectedDate.day) { continue; }

      final startMins = start.hour * 60 + start.minute;
      final endMins = end.hour * 60 + end.minute;
      
      final barberId = appt['barbers']?['id']?.toString();

      if (slotMinutes == startMins) {
        starting.add(appt);
        if (barberId != null) blockedBarberIds.add(barberId);
      } else if (slotMinutes > startMins && slotMinutes < endMins) {
        if (barberId != null) blockedBarberIds.add(barberId);
      }
    }
    return {
      'starting': starting,
      'blockedBarberIds': blockedBarberIds,
    };
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final selectedUnit = ref.watch(selectedUnitIdProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final lockStatusAsync = ref.watch(allBarbersLockStatusProvider);
    final barbersAsync = ref.watch(barbersProvider);

    final AppPermissions perm = userProfileAsync.maybeWhen(
      data: (user) => AppPermissions(user),
      orElse: () => AppPermissions({}),
    );

    final unitIdForHours = selectedUnit ??
        userProfileAsync.maybeWhen(
          data: (u) => u['unit_id'] as String?,
          orElse: () => null,
        );

    final businessHoursAsync = unitIdForHours != null
        ? ref.watch(unitBusinessHoursProvider(unitIdForHours))
        : null;

    // Resolve horário de funcionamento do dia
    final dayName = _dayOfWeekToName(_selectedDate.weekday);
    int startHour = 9;
    int endHour = 19;
    bool isDayClosed = false;

    if (businessHoursAsync != null) {
      businessHoursAsync.whenData((hours) {
        final dayHour = hours.where((h) => h.day == dayName).firstOrNull;
        if (dayHour != null) {
          if (!dayHour.isOpen) {
            isDayClosed = true;
          } else {
            if (dayHour.openTime != null) {
              startHour = int.tryParse(dayHour.openTime!.split(':')[0]) ?? 9;
            }
            if (dayHour.closeTime != null) {
              endHour = int.tryParse(dayHour.closeTime!.split(':')[0]) ?? 19;
            }
          }
        }
      });
    }

    final allSlots = isDayClosed
        ? <String>[]
        : _generateTimeSlots(startHour: startHour, endHour: endHour);

    final isAgendaLocked = lockStatusAsync.maybeWhen(
      data: (data) => data.values.any((v) => v == true),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Erro: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (appointments) {
          return Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: 'Agendamentos',
                      subtitle: 'Gerencie a agenda da barbearia',
                    ),

                    // ── Seletor de Dia ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          // Botão anterior
                          _NavArrowButton(
                            icon: Icons.chevron_left,
                            onTap: () => setState(() {
                              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                            }),
                          ),
                          // Data
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (ctx, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFFD4AF37),
                                        onPrimary: Colors.black,
                                        surface: Color(0xFF1E1E1E),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) setState(() => _selectedDate = picked);
                              },
                              child: Text(
                                _formattedDate,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Botão próximo
                          _NavArrowButton(
                            icon: Icons.chevron_right,
                            onTap: () => setState(() {
                              _selectedDate = _selectedDate.add(const Duration(days: 1));
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Lista de Slots ──────────────────────────────────────
              Expanded(
                child: isDayClosed
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_outlined, size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Unidade fechada neste dia', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allSlots.length,
                        itemBuilder: (context, index) {
                          final slot = allSlots[index];
                          final slotData = _getSlotData(slot, appointments);
                          final startingAppts = slotData['starting'] as List<Map<String, dynamic>>;
                          final blockedBarberIds = slotData['blockedBarberIds'] as Set<String>;

                          List<Widget> blockWidgets = [];

                          for (final appt in startingAppts) {
                            blockWidgets.add(
                              _SlotTile(
                                time: blockWidgets.isEmpty ? slot : '',
                                appointment: appt,
                                isAgendaLocked: isAgendaLocked,
                                onTapAvailable: () {},
                                onTapAppointment: () => _showActionSheet(context, appt),
                              )
                            );
                          }

                          if (perm.canScheduleForOthers) {
                            if (barbersAsync.hasValue) {
                              final barbers = barbersAsync.value!;
                              final availableBarbers = barbers.where((b) => !blockedBarberIds.contains(b['id'].toString())).toList();
                              
                              if (availableBarbers.isNotEmpty) {
                                blockWidgets.add(
                                  _FastTrackAvailableTile(
                                    time: blockWidgets.isEmpty ? slot : '',
                                    availableBarbers: availableBarbers,
                                    onBarberSelected: (barber) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => CreateAppointmentScreen(
                                            initialBarber: barber,
                                            initialTime: slot,
                                            initialDate: _selectedDate,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                );
                              }
                            }
                          } else {
                            if (startingAppts.isEmpty && blockedBarberIds.isEmpty) {
                              blockWidgets.add(
                                _SlotTile(
                                  time: blockWidgets.isEmpty ? slot : '',
                                  appointment: null,
                                  isAgendaLocked: isAgendaLocked,
                                  onTapAvailable: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => CreateAppointmentScreen(
                                          initialTime: slot,
                                          initialDate: _selectedDate,
                                        ),
                                      ),
                                    );
                                  },
                                  onTapAppointment: () {},
                                )
                              );
                            }
                          }

                          if (blockWidgets.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: blockWidgets,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const CreateAppointmentScreen()),
        ),
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Action Sheet (igual ao original) ─────────────────────────────────
  void _showActionSheet(BuildContext context, Map<String, dynamic> appt) {
    if (appt['status'] == 'closed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este atendimento já foi finalizado.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gerenciar Agendamento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: const Text('Finalizar Atendimento (Checkout)'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CheckoutScreen(appointment: appt),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                  title: const Text(
                    'Cancelar Agendamento',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCancelDialog(context, appt['id'] as String);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, String orderId) {
    String selectedReason = 'Cliente não compareceu';
    const List<String> reasons = [
      'Cliente não compareceu',
      'Cancelado pelo cliente',
      'Atraso excessivo',
      'Imprevisto do Profissional',
      'Outro',
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Cancelar Agendamento',
                style: TextStyle(color: Colors.red),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Por favor, informe o motivo do cancelamento:'),
                  const SizedBox(height: 16),
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setStateDialog(() => selectedReason = value!);
                    },
                    child: Column(
                      children: reasons.map((reason) {
                        return RadioListTile<String>(
                          title: Text(reason, style: const TextStyle(fontSize: 14)),
                          value: reason,
                          activeColor: Colors.red,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final supabase = ref.read(supabaseProvider);
                    try {
                      await supabase.from('orders').update({
                        'status': 'canceled',
                        'cancelation_reason': selectedReason,
                      }).eq('id', orderId);
                      ref.invalidate(appointmentsProvider);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Agendamento cancelado com sucesso!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Confirmar Cancelamento'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _NavArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String time;
  final Map<String, dynamic>? appointment;
  final bool isAgendaLocked;
  final VoidCallback onTapAvailable;
  final VoidCallback onTapAppointment;

  const _SlotTile({
    required this.time,
    required this.appointment,
    required this.isAgendaLocked,
    required this.onTapAvailable,
    required this.onTapAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final hasAppointment = appointment != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: hasAppointment ? onTapAppointment : onTapAvailable,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: hasAppointment
                ? const Color(0xFF1E1E1E)
                : const Color(0xFF181818),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasAppointment ? Colors.white12 : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Horário
              SizedBox(
                width: 48,
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: hasAppointment ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Linha divisória
              Container(
                width: 1,
                height: 40,
                color: hasAppointment ? Colors.white12 : Colors.white.withValues(alpha: 0.06),
              ),
              const SizedBox(width: 12),

              // Conteúdo
              Expanded(
                child: hasAppointment
                    ? _AppointmentContent(appt: appointment!)
                    : _AvailableSlotContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentContent extends StatelessWidget {
  final Map<String, dynamic> appt;

  const _AppointmentContent({required this.appt});

  @override
  Widget build(BuildContext context) {
    final clientName = appt['client_name']?.toString() ?? 'Cliente Avulso';
    final barberName = appt['barbers']?['users']?['name']?.toString() ?? '-';
    final status = appt['status']?.toString() ?? 'open';
    final isVip = appt['clients']?['is_vip'] == true;

    // Badge de status
    Color statusBg;
    Color statusFg;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'closed':
        statusBg = Colors.green.withValues(alpha: 0.15);
        statusFg = Colors.greenAccent;
        statusLabel = 'Concluído';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'canceled':
        statusBg = Colors.red.withValues(alpha: 0.15);
        statusFg = Colors.redAccent;
        statusLabel = 'Cancelado';
        statusIcon = Icons.cancel_outlined;
        break;
      default: // open
        statusBg = Colors.orange.withValues(alpha: 0.15);
        statusFg = Colors.orangeAccent;
        statusLabel = 'Pendente';
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVip) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                barberName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusFg.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 12, color: statusFg),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusFg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailableSlotContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Horário disponível',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _FastTrackAvailableTile extends StatelessWidget {
  final String time;
  final List<Map<String, dynamic>> availableBarbers;
  final void Function(Map<String, dynamic>) onBarberSelected;

  const _FastTrackAvailableTile({
    required this.time,
    required this.availableBarbers,
    required this.onBarberSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Horário
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Linha divisória
            Container(
              width: 1,
              // Altura não declarada - deixa crescer com o conteúdo do Row
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(width: 12),

            // Botões dos Barbeiros Disponíveis
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Horário disponível',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableBarbers.map((barber) {
                      final name = barber['users']?['name']?.toString() ?? 'Barbeiro';
                      return InkWell(
                        onTap: () => onBarberSelected(barber),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}