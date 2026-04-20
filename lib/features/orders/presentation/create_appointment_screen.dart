import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../providers/appointments_provider.dart';
import '../providers/schedule_lock_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../../../core/rbac/app_permissions.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../units/providers/business_hours_provider.dart';

class CreateAppointmentScreen extends ConsumerStatefulWidget {
  /// Setor para filtrar serviços. null = exibe todos (padrão: barbearia)
  final String? sector;

  const CreateAppointmentScreen({super.key, this.sector});

  @override
  ConsumerState<CreateAppointmentScreen> createState() => _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState extends ConsumerState<CreateAppointmentScreen> {
  final _clientController = TextEditingController();
  Map<String, dynamic>? _selectedClient; // NOVO: Guarda o cliente selecionado do Autocomplete
  
  DateTime _selectedDate = DateTime.now(); 
  Map<String, dynamic>? _selectedBarber; 
  String? _selectedTime; 
  final Set<String> _selectedServiceIds = {};
  
  double _totalPrice = 0.0;
  int _totalDuration = 0;
  bool _isLoading = false;

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

  List<String> _generateTimeSlots({int startHour = 9, int endHour = 19}) {
    List<String> slots = [];
    for (int h = startHour; h <= endHour; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      if (h < endHour) {
        slots.add('${h.toString().padLeft(2, '0')}:30');
      }
    }
    return slots;
  }

  /// Converte o dia da semana (1=Monday) para o nome usado na tabela business_hours
  String _dayOfWeekToName(int weekday) {
    const days = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
    return days[weekday - 1];
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

  Future<void> _saveToSupabase() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final userId = supabase.auth.currentUser!.id;
      final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();
      
      // Resolve a unidade ativa — prioriza seleção global
      final selectedUnit = ref.read(selectedUnitIdProvider);
      final unitId = selectedUnit ?? (userRes['unit_id'] as String);

      final startParts = _selectedTime!.split(':');
      final startDateTime = DateTime(
        _selectedDate.year, 
        _selectedDate.month, 
        _selectedDate.day, 
        int.parse(startParts[0]), 
        int.parse(startParts[1])
      );
      final endDateTime = startDateTime.add(Duration(minutes: _totalDuration));

      // Se o cliente escolheu alguém da lista, o _selectedClient não é nulo.
      // Se apenas escreveu um nome, usamos o texto do _clientController.
      final finalClientName = _selectedClient != null ? _selectedClient!['name'] : (_clientController.text.isNotEmpty ? _clientController.text : 'Cliente Avulso');

      final userProfile = await ref.read(userProfileProvider.future);
      final perm = AppPermissions(userProfile);
      final String finalBarberId = perm.canScheduleForOthers
          ? (_selectedBarber!['id'] as String)
          : (userProfile['barber_id'] as String? ?? '');

      // Inserir a ordem e obter o ID retornado
      final orderResponse = await supabase.from('orders').insert({
        'unit_id': unitId,
        'barber_id': finalBarberId,
        'client_id': _selectedClient?['id'], // Grava o ID oficial do cliente (se existir)
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
        final servicesData = await ref.read(servicesProvider.future);
        final orderItemsToInsert = <Map<String, dynamic>>[];

        for (final serviceId in _selectedServiceIds) {
          final service = servicesData.firstWhere(
            (s) => s['id'] == serviceId,
            orElse: () => {'name': 'Serviço', 'price': 0.0},
          );
          final servicePrice = (service['price'] as num).toDouble();
          final commissionPct = (service['commission_pct'] as num?)?.toDouble() ?? 40.0;
          final commissionValue = servicePrice * (commissionPct / 100);

          orderItemsToInsert.add({
            'order_id': orderId,
            'item_type': 'service',
            'reference_id': serviceId,
            'name': service['name'],
            'quantity': 1,
            'unit_price': servicePrice,
            'commission_pct': commissionPct,
            'commission_value': commissionValue,
          });
        }

        if (orderItemsToInsert.isNotEmpty) {
          await supabase.from('order_items').insert(orderItemsToInsert);
        }
      }

      ref.invalidate(appointmentsProvider);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agendamento salvo com sucesso!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barbersAsync = ref.watch(barbersProvider);
    // Usa o provider filtrado pelo setor (se não tiver setor, filtra para 'barbearia' por padrão)
    final servicesAsync = ref.watch(servicesBySectorProvider(widget.sector ?? 'barbearia'));
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final userProfileAsync = ref.watch(userProfileProvider); // RBAC Permissões
    final lockStatusAsync = ref.watch(allBarbersLockStatusProvider);

    final AppPermissions perm = userProfileAsync.maybeWhen(
      data: (user) => AppPermissions(user),
      orElse: () => AppPermissions({}),
    );

    final String? loggedInBarberId = userProfileAsync.maybeWhen(
      data: (user) => user['barber_id'] as String?,
      orElse: () => null,
    );

    // Se é líder, exige _selectedBarber. Se não, exige loggedInBarberId.
    final String? effectiveBarberId = perm.canScheduleForOthers ? (_selectedBarber?['id'] as String?) : loggedInBarberId;

    final bookedSlots = (effectiveBarberId != null && appointmentsAsync.hasValue)
        ? _getBookedSlots(appointmentsAsync.value!, effectiveBarberId)
        : <String>[];

    // Verifica se a agenda do barbeiro selecionado está travada
    final Map<String, bool> lockStatus = lockStatusAsync.maybeWhen(
      data: (data) => data,
      orElse: () => {},
    );
    final isSelectedBarberLocked = effectiveBarberId != null
        ? (lockStatus[effectiveBarberId] ?? false)
        : false;

    // Busca horário de funcionamento da unidade para o dia selecionado
    final selectedUnit = ref.watch(selectedUnitIdProvider);
    final unitIdForHours = selectedUnit ?? userProfileAsync.maybeWhen(
      data: (user) => user['unit_id'] as String?,
      orElse: () => null,
    );
    final businessHoursAsync = unitIdForHours != null
        ? ref.watch(unitBusinessHoursProvider(unitIdForHours))
        : null;

    // Gera slots dinâmicos baseados no horário de funcionamento do dia
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

    final allSlots = isDayClosed ? <String>[] : _generateTimeSlots(startHour: startHour, endHour: endHour);
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
            // 1. Cliente (Agora com Pesquisa Inteligente)
            const Text('Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            clientsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => const Text('Erro ao carregar clientes'),
              data: (clients) {
                return Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['name'] as String? ?? '',
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
                    // Mantemos o controller sincronizado para permitir clientes não registados
                    if (controller.text != _clientController.text) {
                      controller.text = _clientController.text;
                    }
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      onChanged: (val) {
                        _clientController.text = val;
                        // Se o texto mudar, significa que já não é o cliente selecionado
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
                              final isPremium = option['is_premium'] == true;
                              final clientName = option['name']?.toString() ?? '';
                              final clientPhone = option['phone']?.toString();
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPremium ? Colors.amber.withAlpha(51) : Colors.green.withAlpha(51),
                                  child: Text(clientName.isNotEmpty ? clientName[0].toUpperCase() : '?', style: TextStyle(color: isPremium ? Colors.amber : Colors.green, fontSize: 14)),
                                ),
                                title: Row(
                                  children: [
                                    Text(clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                    if (isPremium) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                                    ]
                                  ],
                                ),
                                subtitle: Text(clientPhone ?? 'Sem telemóvel', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
                    const Icon(Icons.edit, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Profissional (Oculto se não for Líder)
            if (perm.canScheduleForOthers) ...[
              const Text('Profissional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              barbersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => Text('Erro: $err'),
                data: (barbers) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 110,
                  ),
                  itemCount: barbers.length,
                  itemBuilder: (context, index) {
                    final barber = barbers[index];
                    final isSelected = _selectedBarber?['id'] == barber['id'];
                    final barberName = (barber['name'] ?? barber['users']?['name'] ?? 'Sem Nome').toString();
                    
                    return _BarberCard(
                      name: barberName,
                      isSelected: isSelected,
                      onTap: () => setState(() {
                        _selectedBarber = isSelected ? null : barber;
                        _selectedTime = null;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 4. Horários
            if (effectiveBarberId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Horários Disponíveis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_selectedTime != null ? 'Término: $_calculatedEndTime' : 'Selecione', style: TextStyle(color: _selectedTime != null ? Colors.green : Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              if (isSelectedBarberLocked) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este profissional fechou a agenda. Nenhum horário disponível.',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900], 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: allSlots.length,
                  itemBuilder: (context, index) {
                    final slot = allSlots[index];
                    final isBooked = bookedSlots.contains(slot);
                    final isLocked = isSelectedBarberLocked;
                    final isSelected = _selectedTime == slot && !isLocked;

                    return InkWell(
                      onTap: (isBooked || isLocked)
                          ? null
                          : () => setState(() => _selectedTime = slot),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green
                              : isLocked
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : isBooked
                                      ? Colors.grey[850]
                                      : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? Colors.greenAccent 
                                : isLocked 
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          slot,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : isLocked
                                    ? Colors.red[300]
                                    : isBooked
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 5. Serviços
            const Text('Serviços', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            servicesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Erro: $err'),
              data: (services) => SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final isSelected = _selectedServiceIds.contains(service['id']);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedServiceIds.remove(service['id'].toString());
                          } else {
                            _selectedServiceIds.add(service['id'].toString());
                          }
                          _calculateTotals(services);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.grey[900],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white24,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.content_cut,
                              color: isSelected ? Colors.black : Colors.grey[400],
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                service['name']?.toString() ?? '',
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'R\$ ${(service['price'] as num).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.black54 : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16), color: const Color(0xFF1E1E1E),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total a cobrar', style: TextStyle(color: Colors.grey)),
                  Text('R\$ ${_totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                onPressed: effectiveBarberId != null && _selectedTime != null && _totalPrice > 0 && !_isLoading
                    ? _saveToSupabase
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('Confirmar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _BarberCard({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white10,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isSelected ? Colors.black12 : Colors.white10,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}