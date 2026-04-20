import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/units/providers/units_provider.dart';
import '../../providers/selected_unit_provider.dart';

class UnitSelectorWidget extends ConsumerWidget {
  const UnitSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);
    final selectedUnitId = ref.watch(selectedUnitIdProvider);

    return unitsAsync.when(
      loading: () => const SizedBox(
        width: 100,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        ),
      ),
      error: (err, stack) => const Icon(Icons.error_outline, color: Colors.red, size: 20),
      data: (units) {
        if (units.isEmpty) return const SizedBox.shrink();

        final selectedUnit = units.firstWhere(
          (u) => u['id'] == selectedUnitId,
          orElse: () => {'name': 'Todas as Unidades'},
        );

        return InkWell(
          onTap: () => _showUnitPicker(context, ref, units),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    selectedUnit['name'] as String? ?? 'Unidade',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnitPicker(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> units) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Selecionar Unidade',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_outlined, color: Colors.grey),
                      title: const Text('Unidade Padrão', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Conforme seu perfil', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: ref.read(selectedUnitIdProvider) == null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        ref.read(selectedUnitIdProvider.notifier).state = null;
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ...units.map((unit) {
                      final isSelected = ref.read(selectedUnitIdProvider) == unit['id'];
                      return ListTile(
                        leading: Icon(
                          Icons.store_outlined,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          unit['name'] as String? ?? 'Unidade',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[300],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          ref.read(selectedUnitIdProvider.notifier).state = unit['id'] as String;
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
