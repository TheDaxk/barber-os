import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';

// Provider para carregar configurações da unidade
final unitSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  if (user == null) throw Exception('Sessão expirada');

  final userData = await supabase.from('users').select('unit_id').eq('id', user.id).single();
  final unitId = userData['unit_id'] as String;

  final unitData = await supabase.from('units').select('*, business_hours(*)').eq('id', unitId).single();

  return Map<String, dynamic>.from(unitData);
});

class UnitSettingsScreen extends ConsumerStatefulWidget {
  const UnitSettingsScreen({super.key});

  @override
  ConsumerState<UnitSettingsScreen> createState() => _UnitSettingsScreenState();
}

class _UnitSettingsScreenState extends ConsumerState<UnitSettingsScreen> {
  bool _isLoading = false;
  bool _hasChanges = false;

  // Horários padrão
  final Map<String, TimeOfDay> _openingTimes = {};
  final Map<String, TimeOfDay> _closingTimes = {};
  final Map<String, bool> _isOpen = {};

  final List<String> _diasSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    // Inicializa com horários padrão
    for (var dia in _diasSemana) {
      _isOpen[dia] = true;
      _openingTimes[dia] = const TimeOfDay(hour: 9, minute: 0);
      _closingTimes[dia] = const TimeOfDay(hour: 19, minute: 0);
    }
  }

  void _loadSettingsFromUnit(Map<String, dynamic> unitData) {
    if (unitData['business_hours'] != null) {
      final List<dynamic> hours = unitData['business_hours'];
      final diasMap = {
        'segunda': 'Segunda-feira',
        'terca': 'Terça-feira',
        'quarta': 'Quarta-feira',
        'quinta': 'Quinta-feira',
        'sexta': 'Sexta-feira',
        'sabado': 'Sábado',
        'domingo': 'Domingo',
      };

      for (var h in hours) {
        final dayKey = h['day'];
        final dia = diasMap[dayKey];
        if (dia != null) {
          _isOpen[dia] = h['is_open'] ?? true;
          if (h['open_time'] != null) {
            final parts = h['open_time'].toString().split(':');
            _openingTimes[dia] = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (h['close_time'] != null) {
            final parts = h['close_time'].toString().split(':');
            _closingTimes[dia] = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        }
      }
    }
    setState(() {});
  }

  Future<void> _selectTime(String day, bool isOpening) async {
    final currentTime = isOpening ? _openingTimes[day]! : _closingTimes[day]!;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTimes[day] = picked;
        } else {
          _closingTimes[day] = picked;
        }
        _hasChanges = true;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final user = supabase.auth.currentUser!;
      final userData = await supabase.from('users').select('unit_id').eq('id', user.id).single();
      final unitId = userData['unit_id'];

      // Get existing business_hours
      final currentHoursList = await supabase.from('business_hours').select('id, day').eq('unit_id', unitId);
      final currentHoursMap = { for (var item in currentHoursList) item['day'] as String : item['id'] as String };

      final diasToDb = {
        'Segunda-feira': 'segunda',
        'Terça-feira': 'terca',
        'Quarta-feira': 'quarta',
        'Quinta-feira': 'quinta',
        'Sexta-feira': 'sexta',
        'Sábado': 'sabado',
        'Domingo': 'domingo',
      };

      for (var dia in _diasSemana) {
        final dbDay = diasToDb[dia]!;
        
        final data = {
          'unit_id': unitId,
          'day': dbDay,
          'open_time': _isOpen[dia]! ? _formatTime(_openingTimes[dia]!) : null,
          'close_time': _isOpen[dia]! ? _formatTime(_closingTimes[dia]!) : null,
          'is_open': _isOpen[dia]!,
        };

        if (currentHoursMap.containsKey(dbDay)) {
           await supabase.from('business_hours').update(data).eq('id', currentHoursMap[dbDay]!);
        } else {
           await supabase.from('business_hours').insert(data);
        }
      }

      ref.invalidate(unitSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso!'),
              backgroundColor: Colors.green),
        );
        setState(() => _hasChanges = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitSettingsAsync = ref.watch(unitSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Horário de Funcionamento',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: unitSettingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro ao carregar configurações: $err',
              style: const TextStyle(color: Colors.red)),
        ),
        data: (unitData) {
          // Carrega configurações existentes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_hasChanges) {
              _loadSettingsFromUnit(unitData);
            }
          });

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Defina os horários de funcionamento para cada dia da semana',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Lista de dias
                    ...(_diasSemana.map((dia) => _buildDayCard(dia))),
                  ],
                ),
              ),

              // Botão salvar
              if (_hasChanges)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Salvar Alterações',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCard(String day) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _isOpen[day]!,
                  onChanged: (value) {
                    setState(() {
                      _isOpen[day] = value;
                      _hasChanges = true;
                    });
                  },
                  activeTrackColor: Colors.green,
                ),
              ],
            ),
            if (_isOpen[day]!) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTimeButton(day, true),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  _buildTimeButton(day, false),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Fechado',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String day, bool isOpening) {
    final time = isOpening ? _openingTimes[day]! : _closingTimes[day]!;
    final label = isOpening ? 'Abertura' : 'Fechamento';

    return InkWell(
      onTap: _isOpen[day]! ? () => _selectTime(day, isOpening) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
