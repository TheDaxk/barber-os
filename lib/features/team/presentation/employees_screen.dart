import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../../core/supabase/providers.dart';
import '../providers/employees_provider.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../units/providers/units_provider.dart';
import 'employee_details_screen.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {

  // Bottom Sheet para CADASTRO ou EDIÇÃO
  void _showEmployeeBottomSheet({Map<String, dynamic>? employee}) {
    final isEditing = employee != null;
    
    // Controladores (alguns só usados na criação)
    final nameController = TextEditingController(text: isEditing ? (employee['users']?['name'] ?? '') : '');
    final emailController = TextEditingController(text: isEditing ? (employee['users']?['email'] ?? '') : '');
    final phoneController = TextEditingController(text: isEditing ? (employee['users']?['phone'] ?? '') : '');
    final unitController = TextEditingController(text: isEditing ? ((employee['unit_name'] ?? '')) : '');
    final passwordController = TextEditingController();
    
    final commissionController = TextEditingController(
      text: isEditing ? (employee['commission_rate'] as num).toStringAsFixed(0) : '40',
    );
    
    String selectedCategory = isEditing ? (employee['category'] ?? 'Barbeiro') : 'Barbeiro';
    bool isSaving = false;

    final categories = [
      {'id': 'Barbeiro Líder', 'label': 'Barbeiro Líder', 'icon': Icons.workspace_premium},
      {'id': 'Barbeiro Pro Max', 'label': 'Barbeiro Pro Max', 'icon': Icons.star},
      {'id': 'Barbeiro Pro', 'label': 'Barbeiro Pro', 'icon': Icons.star_border},
      {'id': 'Barbeiro', 'label': 'Barbeiro', 'icon': Icons.content_cut},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            String? selectedUnitIdForEdit = isEditing ? employee['unit_id'] as String? : null;

            return Container(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEditing ? 'Editar Profissional' : 'Novo Profissional', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- SÓ MOSTRA NO CADASTRO ----
                    if (!isEditing) ...[
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration('Nome Completo', Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('E-mail (Login)', Icons.email_outlined),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration('WhatsApp', Icons.phone_outlined),
                      ),
                      const SizedBox(height: 12),
                      Consumer(builder: (context, ref, _) {
                        final unitsAsync = ref.watch(unitsProvider);
                        return unitsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Erro ao carregar unidades', style: TextStyle(color: Colors.red)),
                          data: (units) => DropdownButtonFormField<String>(
                            value: selectedUnitIdForEdit,
                            decoration: _inputDecoration('Unidade', Icons.location_on_outlined),
                            dropdownColor: Colors.grey[800],
                            hint: const Text('Selecione a unidade'),
                            items: units.map((u) => DropdownMenuItem(
                              value: u['id'] as String,
                              child: Text(u['name'] as String? ?? 'Unidade'),
                            )).toList(),
                            onChanged: (val) => setStateSheet(() => selectedUnitIdForEdit = val),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: _inputDecoration('Senha', Icons.lock_outline),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text('Função', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = selectedCategory == cat['id'];
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(cat['label'] as String, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey[300])),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: Colors.blueAccent,
                          backgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          showCheckmark: false,
                          onSelected: (_) => setStateSheet(() => selectedCategory = cat['id'] as String),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: commissionController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Comissão (%)', Icons.percent),
                    ),
                    const SizedBox(height: 24),

                    // BOTÕES
                    Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              onPressed: isSaving ? null : () async {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.grey[900],
                                    title: const Text('Desativar?'),
                                    content: const Text('O profissional não aparecerá mais na agenda ativa.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desativar', style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;

                                setStateSheet(() => isSaving = true);
                                try {
                                  await ref.read(supabaseProvider).from('barbers').update({'is_active': false}).eq('id', employee['id']);
                                  ref.invalidate(employeesProvider);
                                  ref.invalidate(barbersProvider);
                                  if (context.mounted) Navigator.pop(context); // Fecha bottomsheet
                                  if (context.mounted) Navigator.pop(context); // Fecha tela de detalhes (se veio dela)
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                                  setStateSheet(() => isSaving = false);
                                }
                              },
                              icon: const Icon(Icons.person_off_outlined, color: Colors.redAccent, size: 18),
                              label: const Text('Desativar', style: TextStyle(color: Colors.redAccent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent, width: 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: isSaving ? null : () async {
                              setStateSheet(() => isSaving = true);
                              final supabase = ref.read(supabaseProvider);
                              
                              try {
                                final commission = double.tryParse(commissionController.text) ?? 40.0;

                                if (isEditing) {
                                  // ATUALIZAR
                                  await supabase.from('barbers').update({
                                    'category': selectedCategory,
                                    'commission_rate': commission,
                                    'unit_id': selectedUnitIdForEdit,
                                  }).eq('id', employee['id']);

                                  // Tentar atualizar telefone no users (Pode falhar se RLS bloquear update no auth, mas como é via banco, funciona se admin tiver acesso)
                                  await supabase.from('users').update({
                                    'phone': phoneController.text.trim(),
                                  }).eq('id', employee['user_id']);
                                  
                                  ref.invalidate(employeesProvider);
                                  ref.invalidate(barbersProvider);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atualizado com sucesso!'), backgroundColor: Colors.green));
                                  }
                                } else {
                                  // CRIAR NOVO
                                  if (emailController.text.trim().isEmpty || passwordController.text.trim().length < 6) {
                                    throw Exception('Preencha E-mail e Senha (mínimo 6 caracteres).');
                                  }

                                  final adminId = supabase.auth.currentUser!.id;
                                  final userRes = await supabase.from('users').select('unit_id').eq('id', adminId).single();
                                  final unitId = userRes['unit_id'];

                                  // Criação "limpa" via REST para evitar deslogar o gestor
                                  final authRes = await http.post(
                                    Uri.parse('$supabaseUrl/auth/v1/signup'),
                                    headers: {'apikey': supabaseAnonKey, 'Content-Type': 'application/json'},
                                    body: jsonEncode({
                                      'email': emailController.text.trim(),
                                      'password': passwordController.text,
                                    }),
                                  );

                                  if (authRes.statusCode >= 400) {
                                    throw Exception('Erro Auth: ${jsonDecode(authRes.body)['msg'] ?? 'Desconhecido'}');
                                  }
                                  
                                  final authData = jsonDecode(authRes.body);
                                  final newUserId = authData['user'] != null ? authData['user']['id'] : authData['id'];

                                  // Inserir perfil base
                                  await supabase.from('users').insert({
                                    'id': newUserId,
                                    'name': nameController.text.trim(),
                                    'email': emailController.text.trim(),
                                    'unit_id': unitId,
                                    'role': 'barber',
                                    'phone': phoneController.text.trim(),
                                  });

                                  // Inserir Barbeiro
                                  await supabase.from('barbers').insert({
                                    'user_id': newUserId,
                                    'unit_id': unitId,
                                    'category': selectedCategory,
                                    'commission_rate': commission,
                                    'unit_name': unitController.text.trim(),
                                  });

                                  ref.invalidate(employeesProvider);
                                  ref.invalidate(barbersProvider);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profissional criado com sucesso!'), backgroundColor: Colors.green));
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
                                }
                              } finally {
                                if (context.mounted) setStateSheet(() => isSaving = false);
                              }
                            },
                            child: isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey, size: 18),
      filled: true,
      fillColor: Colors.grey[800],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      labelStyle: TextStyle(color: Colors.grey[400]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Equipe de Profissionais', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          _buildUnitSelector(),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.grey[900],
        onRefresh: () async {
          ref.invalidate(employeesProvider);
          ref.invalidate(barbersProvider);
        },
        child: employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
          data: (employees) {
            if (employees.isEmpty) {
              return const Center(child: Text('Nenhum profissional cadastrado.', style: TextStyle(color: Colors.grey)));
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: employees.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Equipe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  );
                }
                final emp = employees[index - 1];
                final userName = emp['users']?['name'] ?? 'Sem Nome';
                final category = emp['category'] ?? '';
                final commission = (emp['commission_rate'] as num?)?.toStringAsFixed(0) ?? '40';

                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
                  tileColor: Colors.grey[900],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.15),
                    child: const Icon(Icons.content_cut, color: Colors.blueAccent, size: 20),
                  ),
                  title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$category • $commission% comissão', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                  onTap: () {
                    // Vai para a TELA DE DETALHES em vez do BottomSheet de edição
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmployeeDetailsScreen(
                          employee: emp,
                          onEdit: () {
                            // O botão de Editar lá dentro abre o mesmo BottomSheet daqui
                            _showEmployeeBottomSheet(employee: emp);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeBottomSheet(), // NOVO
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Novo Profissional', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildUnitSelector() {
    final unitsAsync = ref.watch(unitsProvider);
    final selectedUnit = ref.watch(selectedUnitIdProvider);

    return unitsAsync.when(
      loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Icon(Icons.business, color: Colors.grey),
      data: (units) {
        return PopupMenuButton<String?>(
          icon: const Icon(Icons.business, color: Colors.white),
          tooltip: 'Selecionar Unidade',
          onSelected: (unitId) {
            ref.read(selectedUnitIdProvider.notifier).state = unitId;
            ref.invalidate(employeesProvider);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: null,
              child: Text('Todas as unidades'),
            ),
            const PopupMenuDivider(),
            ...units.map((unit) => PopupMenuItem(
              value: unit['id'] as String,
              child: Row(
                children: [
                  if (unit['id'] == selectedUnit)
                    const Icon(Icons.check, color: Colors.green, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(unit['name'] as String? ?? 'Unidade'),
                ],
              ),
            )),
          ],
        );
      },
    );
  }
}
