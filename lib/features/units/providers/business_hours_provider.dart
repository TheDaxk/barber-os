import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Modelo de horário de funcionamento
class BusinessHour {
  final String id;
  final String unitId;
  final String day;
  final String? openTime;
  final String? closeTime;
  final bool isOpen;

  BusinessHour({
    required this.id,
    required this.unitId,
    required this.day,
    this.openTime,
    this.closeTime,
    required this.isOpen,
  });

  factory BusinessHour.fromMap(Map<String, dynamic> map) {
    return BusinessHour(
      id: map['id'] as String,
      unitId: map['unit_id'] as String,
      day: map['day'] as String,
      openTime: map['open_time'] as String?,
      closeTime: map['close_time'] as String?,
      isOpen: map['is_open'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unit_id': unitId,
      'day': day,
      'open_time': openTime,
      'close_time': closeTime,
      'is_open': isOpen,
    };
  }

  BusinessHour copyWith({
    String? id,
    String? unitId,
    String? day,
    String? openTime,
    String? closeTime,
    bool? isOpen,
  }) {
    return BusinessHour(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      day: day ?? this.day,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      isOpen: isOpen ?? this.isOpen,
    );
  }
}

// Provider que busca os horários de funcionamento de uma unidade
final unitBusinessHoursProvider = FutureProvider.family.autoDispose<List<BusinessHour>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('business_hours')
      .select('*')
      .eq('unit_id', unitId);

  final hours = (response as List).map((e) => BusinessHour.fromMap(Map<String, dynamic>.from(e as Map))).toList();

  // Ordena manualmente por dia da semana
  const ordemDias = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
  hours.sort((a, b) {
    final aIndex = ordemDias.indexOf(a.day);
    final bIndex = ordemDias.indexOf(b.day);
    return aIndex.compareTo(bIndex);
  });

  return hours;
});
