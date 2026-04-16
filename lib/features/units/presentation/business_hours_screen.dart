import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/business_hours_provider.dart';
import '../../../core/supabase/providers.dart';

class BusinessHoursScreen extends ConsumerStatefulWidget {
  final String unitId;
  final String unitName;

  const BusinessHoursScreen({
    super.key,
    required this.unitId,
    required this.unitName,
  });

  @override
  ConsumerState<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends ConsumerState<BusinessHoursScreen> {
  List<BusinessHour>? _hours;
  bool _isLoading = false;
  bool _initializedFromData = false;

  static const _dias = [
    {'key': 'segunda', 'label': 'Segunda-feira'},
    {'key': 'terca', 'label': 'Terça-feira'},
    {'key': 'quarta', 'label': 'Quarta-feira'},
    {'key': 'quinta', 'label': 'Quinta-feira'},
    {'key': 'sexta', 'label': 'Sexta-feira'},
    {'key': 'sabado', 'label': 'Sábado'},
    {'key': 'domingo', 'label': 'Domingo'},
  ];

  @override
  Widget build(BuildContext context) {
    final hoursAsync = ref.watch(unitBusinessHoursProvider(widget.unitId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Horário - ${widget.unitName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: hoursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Erro: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (hours) {
          if (!_initializedFromData) {
            _hours = _initializeHours(hours);
            _initializedFromData = true;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dias.length,
                  itemBuilder: (context, index) {
                    final dia = _dias[index];
                    final hour = _hours!.firstWhere(
                      (h) => h.day == dia['key'],
                      orElse: () => BusinessHour(
                        id: '',
                        unitId: widget.unitId,
                        day: dia['key']!,
                        isOpen: true,
                      ),
                    );

                    return _buildDayCard(dia['label']!, dia['key']!, hour);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveHours,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Salvar Horários', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<BusinessHour> _initializeHours(List<BusinessHour> existingHours) {
    return _dias.map((dia) {
      final existing = existingHours.where((h) => h.day == dia['key']).firstOrNull;
      if (existing != null) {
        return existing;
      }
      return BusinessHour(
        id: '',
        unitId: widget.unitId,
        day: dia['key']!,
        openTime: '09:00',
        closeTime: '18:00',
        isOpen: dia['key'] != 'domingo', // domingo fechado por padrão
      );
    }).toList();
  }

  Widget _buildDayCard(String label, String dayKey, BusinessHour hour) {
    final index = _hours!.indexWhere((h) => h.day == dayKey);

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: hour.isOpen,
                  onChanged: (value) {
                    setState(() {
                      _hours![index] = hour.copyWith(isOpen: value);
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            if (hour.isOpen) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeButton(
                      label: 'Abertura',
                      time: hour.openTime,
                      onTap: () => _selectTime(index, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeButton(
                      label: 'Fechamento',
                      time: hour.closeTime,
                      onTap: () => _selectTime(index, false),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Fechado',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required String? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time ?? '--:--',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(int index, bool isOpenTime) async {
    final hour = _hours![index];
    final currentTime = isOpenTime ? hour.openTime : hour.closeTime;

    final parts = (currentTime ?? '09:00').split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.grey[900],
              dialHandColor: Colors.green,
              dialBackgroundColor: Colors.grey[800],
              hourMinuteColor: Colors.grey[800],
              hourMinuteTextColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpenTime) {
          _hours![index] = hour.copyWith(openTime: timeStr);
        } else {
          _hours![index] = hour.copyWith(closeTime: timeStr);
        }
      });
    }
  }

  Future<void> _saveHours() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);

      for (int i = 0; i < _hours!.length; i++) {
        final hour = _hours![i];
        final data = {
          'unit_id': widget.unitId,
          'day': hour.day,
          'open_time': hour.isOpen ? hour.openTime : null,
          'close_time': hour.isOpen ? hour.closeTime : null,
          'is_open': hour.isOpen,
        };

        // Se já existe um registro, atualiza; senão, insere
        if (hour.id.isNotEmpty) {
          await supabase
              .from('business_hours')
              .update(data)
              .eq('id', hour.id);
        } else {
          await supabase
              .from('business_hours')
              .insert(data);
        }
      }

      // Invalida o cache para forçar recarregamento
      ref.invalidate(unitBusinessHoursProvider(widget.unitId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horários salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
