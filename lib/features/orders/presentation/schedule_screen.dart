import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../providers/appointments_provider.dart';
import '../../clients/providers/clients_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final _clientController = TextEditingController();
  Map<String, dynamic>? _selectedClient;

  DateTime _selectedDate = DateTime.now();
  String? _selectedBarberId;
  String? _selectedTime;
  final Set<String> _selectedServiceIds = {};

  double _totalPrice = 0.0;
  int _totalDuration = 0;
  bool _isLoading = false;

  List<Map<String, dynamic>> _loadedServices = [];

  void _calculateTotals(List<Map<String, dynamic>> allServices) {
    double price = 0;
    int duration = 0;
    for (var service in allServices) {
      if (_selectedServiceIds.contains(service['id'])) {
        price += (service['price'] as num).toDouble();
        duration += (service['duration_minutes'] ?? 30) as int;
      }
    }
    setState(() {
      _totalPrice = price;
      _totalDuration = duration;
    });
  }

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int h = 9; h <= 19; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  String get _calculatedEndTime {
    if (_selectedTime == null || _totalDuration == 0) return '--:--';
    final parts = _selectedTime!.split(':');
    int totalMinutes = (int.parse(parts[0]) * 60) + int.parse(parts[1]) + _totalDuration;
    return '${(totalMinutes ~/ 60 % 24).toString().padLeft(2, '0')}:${(totalMinutes % 60).toString().padLeft(2, '0')}';
  }

  List<String> _getBookedSlots(List<Map<String, dynamic>> allAppts, String barberId) {
    List<String> blocked = [];

    final barberAppts = allAppts.where((a) {
      if (a['barbers']?['id'] != barberId) return false;
      if (a['status'] == 'canceled') return false;

      final start = DateTime.parse(a['start_time'] as String).toLocal();
      return start.year == _selectedDate.year &&
             start.month == _selectedDate.month &&
             start.day == _selectedDate.day;
    });

    for (var appt in barberAppts) {
      final start = DateTime.parse(appt['start_time'] as String).toLocal();
      final end = DateTime.parse(appt['end_time'] as String).toLocal();

      int startMins = start.hour * 60 + start.minute;
      int endMins = end.hour * 60 + end.minute;

      for (int m = startMins; m < endMins; m += 30) {
        blocked.add('${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
      }
    }
    return blocked;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.green, onPrimary: Colors.white, surface: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

  Future<void> _saveAppointment(List<Map<String, dynamic>> servicesData) async {
    if (_selectedBarberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um profissional'), backgroundColor: Colors.orange)
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um horário'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final userId = supabase.auth.currentUser!.id;
      final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

      final startParts = _selectedTime!.split(':');
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(startParts[0]),
        int.parse(startParts[1])
      );
      final endDateTime = startDateTime.add(Duration(minutes: _totalDuration));

      final finalClientName = _selectedClient != null
          ? _selectedClient!['name']
          : (_clientController.text.isNotEmpty ? _clientController.text : 'Cliente Avulso');

      // Inserir a ordem
      final orderResponse = await supabase.from('orders').insert({
        'unit_id': userRes['unit_id'],
        'barber_id': _selectedBarberId,
        'client_id': _selectedClient?['id'],
        'opened_by': userId,
        'client_name': finalClientName,
        'start_time': startDateTime.toUtc().toIso8601String(),
        'end_time': endDateTime.toUtc().toIso8601String(),
        'total': _totalPrice,
        'status': 'open',
      }).select().single();

      final orderId = orderResponse['id'];

      // Criar order_items para cada serviço selecionado
      if (_selectedServiceIds.isNotEmpty) {
        final orderItemsToInsert = <Map<String, dynamic>>[];

        for (final serviceId in _selectedServiceIds) {
          final service = servicesData.firstWhere(
            (s) => s['id'] == serviceId,
            orElse: () => {'name': 'Serviço', 'price': 0.0},
          );
          orderItemsToInsert.add({
            'order_id': orderId,
            'service_id': serviceId,
            'service_name': service['name'],
            'price': (service['price'] as num).toDouble(),
            'quantity': 1,
          });
        }

        if (orderItemsToInsert.isNotEmpty) {
          await supabase.from('order_items').insert(orderItemsToInsert);
        }
      }

      ref.invalidate(appointmentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento criado com sucesso!'), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barbersAsync = ref.watch(barbersProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final clientsAsync = ref.watch(clientsProvider);

    final bookedSlots = (_selectedBarberId != null && appointmentsAsync.hasValue)
        ? _getBookedSlots(appointmentsAsync.value!, _selectedBarberId!)
        : <String>[];

    final allSlots = _generateTimeSlots();
    final dateString = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Agendamento'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cliente com pesquisa e ícone VIP
            const Text('Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            clientsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => const Text('Erro ao carregar clientes'),
              data: (clients) {
                return Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['name'] as String,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    return clients.where((client) {
                      return client['name']
                          .toString()
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (Map<String, dynamic> selection) {
                    setState(() {
                      _selectedClient = selection;
                      _clientController.text = selection['name']?.toString() ?? '';
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    if (controller.text != _clientController.text) {
                      controller.text = _clientController.text;
                    }
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      onChanged: (val) {
                        _clientController.text = val;
                        if (_selectedClient != null && _selectedClient!['name'] != val) {
                          setState(() => _selectedClient = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Pesquise ou digite o nome...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _selectedClient != null
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[900],
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 32,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final isVip = option['is_vip'] == true;
                              final clientName = option['name']?.toString() ?? '';
                              final clientPhone = option['phone']?.toString();
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isVip ? Colors.amber.withAlpha(51) : Colors.green.withAlpha(51),
                                  child: Text(clientName.isNotEmpty ? clientName[0].toUpperCase() : '?', style: TextStyle(color: isVip ? Colors.amber : Colors.green, fontSize: 14)),
                                ),
                                title: Row(
                                  children: [
                                    Text(clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                    if (isVip) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                                    ]
                                  ],
                                ),
                                subtitle: Text(clientPhone ?? 'Sem telefone', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // 2. Data
            const Text('Data do Agendamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[800]!)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(dateString, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Horários
            if (_selectedBarberId != null) ...[
              const Text('Horário', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text('Início: $_selectedTime', style: const TextStyle(fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('Fim: $_calculatedEndTime', style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allSlots.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final slot = allSlots[index];
                          final isBooked = bookedSlots.contains(slot);
                          final isSelected = _selectedTime == slot;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: isBooked ? null : () => setState(() => _selectedTime = slot),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.green
                                      : isBooked
                                          ? Colors.grey[800]
                                          : Colors.grey[700],
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected ? Border.all(color: Colors.greenAccent, width: 2) : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      slot,
                                      style: TextStyle(
                                        color: isBooked ? Colors.grey[600] : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isBooked) ...[
                                      const SizedBox(height: 4),
                                      Icon(Icons.block, size: 12, color: Colors.grey[600]),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 4. Seleção de Barbeiro
            const Text('Profissional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            barbersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Erro ao carregar barbeiros: $err', style: const TextStyle(color: Colors.red)),
              data: (barbers) {
                if (barbers.isEmpty) return const Text('Nenhum barbeiro ativo.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: barbers.map((barber) {
                      final barberId = barber['id']?.toString();
                      final isSelected = _selectedBarberId == barberId;
                      final barberName = barber['users']?['name']?.toString() ?? 'Desconhecido';

                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(barberName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedBarberId = selected ? barberId : null;
                              _selectedTime = null; // Reset time when barber changes
                            });
                          },
                          selectedColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.grey[800],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 5. Seleção de Serviços
            const Text('Serviços', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Erro ao carregar serviços: $err', style: const TextStyle(color: Colors.red)),
              data: (services) {
                if (services.isEmpty) return const Text('Nenhum serviço cadastrado.');

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_loadedServices.isEmpty) {
                    _loadedServices = services;
                  }
                });

                return Card(
                  elevation: 0,
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: services.map((service) {
                      final serviceId = service['id']?.toString();
                      final isSelected = _selectedServiceIds.contains(serviceId);
                      final price = (service['price'] as num?)?.toDouble() ?? 0.0;
                      final serviceName = service['name']?.toString() ?? 'Serviço';
                      final duration = service['duration_minutes'] as int? ?? 30;

                      return CheckboxListTile(
                        title: Text(serviceName),
                        subtitle: Text('R\$ ${price.toStringAsFixed(2)} • $duration min'),
                        value: isSelected,
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        onChanged: (bool? value) {
                          setState(() {
                            if (serviceId != null) {
                              if (value == true) {
                                _selectedServiceIds.add(serviceId);
                              } else {
                                _selectedServiceIds.remove(serviceId);
                              }
                            }
                            _calculateTotals(services);
                          });
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      // Rodapé Fixo
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total estimado', style: TextStyle(color: Colors.grey)),
                  Text(
                    'R\$ ${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _selectedBarberId != null && _selectedTime != null && _selectedServiceIds.isNotEmpty && !_isLoading
                    ? () => _saveAppointment(servicesAsync.value ?? _loadedServices)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirmar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
