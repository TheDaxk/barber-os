import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../providers/units_provider.dart';
import 'unit_detail_screen.dart';
import 'unit_form_screen.dart';
import '../../../core/rbac/app_permissions.dart';

class UnitsListScreen extends ConsumerWidget {
  const UnitsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Unidades', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
        data: (userProfile) {
          final perm = AppPermissions(userProfile);

          if (!perm.canManageUnits) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Acesso restrito ao Barbeiro Líder',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          }

          return unitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erro ao carregar unidades: $err', style: const TextStyle(color: Colors.red))),
            data: (units) {
              if (units.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Nenhuma unidade cadastrada', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(builder: (context) => const UnitFormScreen()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Cadastrar Unidade'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 600;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: isDesktop
                        ? const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 350,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.15,
                          )
                        : const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.2,
                          ),
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      final unit = units[index];
                      return _UnitCard(unit: Map<String, dynamic>.from(unit));
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (context) => const UnitFormScreen()),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _UnitCard extends ConsumerWidget {
  final Map<String, dynamic> unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(unitBarbersProvider(unit['id'] as String));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => UnitDetailScreen(unitId: unit['id'] as String)),
        );
      },
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.business, color: Colors.green, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (unit['name'] as String?) ?? 'Sem Nome',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (unit['location'] != null && unit['location'].toString().isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        unit['location'].toString(),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (unit['phone'] != null && unit['phone'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      unit['phone'].toString(),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              barbersAsync.when(
                loading: () => const Text('...', style: TextStyle(color: Colors.grey, fontSize: 11)),
                error: (_, _) => const Text('Sem responsável', style: TextStyle(color: Colors.grey, fontSize: 11)),
                data: (barbers) {
                  if (barbers.isEmpty) {
                    return const Text('Sem responsável', style: TextStyle(color: Colors.grey, fontSize: 11));
                  }
                  final responsable = barbers.first;
                  final name = (responsable['users']?['name'] as String?) ?? 'Desconhecido';
                  return Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
