import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';
import 'providers/clients_provider.dart';
import 'presentation/client_detail_screen.dart';
import '../../core/rbac/app_permissions.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showClientBottomSheet({Map<String, dynamic>? client}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return ClientFormBottomSheet(client: client);
      },
    );
  }

  // ============================================================
  // TODO(P-04): Quando o provider real do Pedro estiver disponível,
  // substituir o `daysSinceVisit` mock (calculado com hashCode abaixo)
  // por: final days = inactivityData[client['id']] as int?;
  // e remover a lógica de hashCode.
  // ============================================================
  Widget? _buildInactivityBadge(Map<String, dynamic> client) {
    // Mock: usa hashCode do id para simular uma variedade de cenários
    final idHash = (client['id'] as String? ?? '').hashCode.abs();
    final daysSinceVisit = idHash % 45; // distribui entre 0 e 44 dias

    Color? badgeColor;
    String? badgeLabel;
    IconData? badgeIcon;

    if (daysSinceVisit >= 30) {
      badgeColor = Colors.redAccent;
      badgeLabel = '${daysSinceVisit}d sem visita';
      badgeIcon = Icons.warning_amber_rounded;
    } else if (daysSinceVisit >= 15) {
      badgeColor = Colors.orangeAccent;
      badgeLabel = '${daysSinceVisit}d sem visita';
      badgeIcon = Icons.schedule;
    } else if (daysSinceVisit >= 8) {
      badgeColor = const Color(0xFFFFCA28); // amarelo
      badgeLabel = '${daysSinceVisit}d sem visita';
      badgeIcon = Icons.access_time;
    } else {
      return null; // sem badge para clientes recentes
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 11, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final userProfileAsync = ref.watch(userProfileProvider); // RBAC Permissões

    // Fallback permissão carregando
    final perm = userProfileAsync.maybeWhen(
      data: (user) => AppPermissions(user),
      orElse: () => AppPermissions({}),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meus Clientes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Barra de Pesquisa
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nome...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Clientes
            Expanded(
              child: clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
                data: (allClients) {
                  final filteredClients = allClients.where((c) {
                    final name = c['name'].toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filteredClients.isEmpty) {
                    return const Center(child: Text('Nenhum cliente encontrado.', style: TextStyle(color: Colors.grey)));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${filteredClients.length} cliente(s) encontrado(s)', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredClients.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            final initial = client['name'].toString().isNotEmpty ? client['name'].toString()[0].toUpperCase() : '?';
                            
                            // IDENTIFICADOR PREMIUM
                            final subscriptionPlan = client['subscription_plan']?.toString();
                            final isPremium = subscriptionPlan == 'premium';
                            final isBasic = subscriptionPlan == 'basic';

                            // Extrai o nome do barbeiro que cadastrou (pode ser null se campo não existir ainda)
                            final createdByBarber = client['created_by_barber'];
                            final createdByName = createdByBarber?['users']?['name']?.toString();

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                              leading: CircleAvatar(
                                backgroundColor: isPremium ? Colors.amber.withValues(alpha: 0.2) : isBasic ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                child: Text(initial, style: TextStyle(color: isPremium ? Colors.amber : isBasic ? Colors.blue : Colors.green, fontWeight: FontWeight.bold)),
                              ),
                              title: Row(
                                children: [
                                  Flexible(child: Text(client['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  if (isPremium) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                                  ] else if (isBasic) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star_border, color: Colors.blue, size: 18),
                                  ]
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  // Só o Líder vê o telefone real após o cadastro
                                  Builder(
                                    builder: (context) {
                                      final rawPhone = client['phone']?.toString() ?? '';
                                      final displayPhone = rawPhone.isNotEmpty
                                          ? (perm.canViewClientPhone ? rawPhone : '••• •••• ••••')
                                          : 'Sem telefone';
                                      return Text(displayPhone);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (subscriptionPlan != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPremium ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isPremium ? Colors.amber.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            isPremium ? '👑 Premium' : '⭐ Básico',
                                            style: TextStyle(color: isPremium ? Colors.amber : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      
                                      // Badge de inatividade
                                      Builder(
                                        builder: (context) {
                                          final badge = _buildInactivityBadge(client);
                                          return badge ?? const SizedBox.shrink();
                                        },
                                      ),
                                    ],
                                  ),
                                  if (createdByName != null && createdByName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.person_pin_outlined, size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Cadastrado por $createdByName',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ]
                                ],
                              ),
                              // Só mostra icone de edição e permite toque se for o Leader
                              trailing: perm.canEditClients
                                  ? const Icon(Icons.edit_outlined, color: Colors.grey, size: 20)
                                  : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                              onTap: () {
                                if (perm.canEditClients) {
                                  _showClientBottomSheet(client: client);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (context) => ClientDetailScreen(client: client),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientBottomSheet(), 
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ============================================================================
// WIDGET DO FORMULÁRIO (Criar e Editar)
// ============================================================================
class ClientFormBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? client;

  const ClientFormBottomSheet({super.key, this.client});

  @override
  ConsumerState<ClientFormBottomSheet> createState() => _ClientFormBottomSheetState();
}

class _ClientFormBottomSheetState extends ConsumerState<ClientFormBottomSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedBirthday;
  String? _subscriptionPlan; // 'basic', 'premium', or null
  DateTime? _subscriptionAcquiredAt;
  bool _isSaving = false;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = (widget.client!['name'] as String?) ?? '';
      _phoneController.text = (widget.client!['phone'] as String?) ?? '';
      _notesController.text = (widget.client!['notes'] as String?) ?? '';
      _subscriptionPlan = widget.client!['subscription_plan']?.toString();

      if (widget.client!['subscription_acquired_at'] != null) {
        _subscriptionAcquiredAt = DateTime.tryParse(widget.client!['subscription_acquired_at'].toString());
      }
      if (widget.client!['birthday'] != null) {
        _selectedBirthday = DateTime.tryParse(widget.client!['birthday'].toString());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000), 
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.green, onPrimary: Colors.white, surface: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _saveClient() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome é obrigatório.')));
      return;
    }

    setState(() => _isSaving = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final userId = supabase.auth.currentUser!.id;
      final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

      String? birthdayStr;
      if (_selectedBirthday != null) {
        birthdayStr = '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}';
      }

      final clientData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'birthday': birthdayStr,
        'notes': _notesController.text.trim(),
        'subscription_plan': _subscriptionPlan,
        'subscription_acquired_at': _subscriptionAcquiredAt?.toIso8601String().split('T').first,
      };

      if (_isEditing) {
        await supabase.from('clients').update(clientData).eq('id', widget.client!['id'] as Object);
      } else {
        clientData['unit_id'] = userRes['unit_id'] as String?;
        await supabase.from('clients').insert(clientData);
      }

      ref.invalidate(clientsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Cliente atualizado com sucesso!' : 'Cliente cadastrado com sucesso!'), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isEditing ? 'Editar Cliente' : 'Novo Cliente', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nome Completo *',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'WhatsApp / Telefone',
              prefixIcon: const Icon(Icons.phone_outlined),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: _pickBirthday,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    _selectedBirthday == null 
                        ? 'Data de Nascimento (Opcional)' 
                        : '${_selectedBirthday!.day.toString().padLeft(2, '0')}/${_selectedBirthday!.month.toString().padLeft(2, '0')}/${_selectedBirthday!.year}',
                    style: TextStyle(
                      fontSize: 16, 
                      color: _selectedBirthday == null ? Colors.grey[400] : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Seletor de Plano de Assinatura
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plano de Assinatura', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PlanChip(
                    label: 'Sem plano',
                    icon: Icons.person_outline,
                    color: Colors.grey,
                    selected: _subscriptionPlan == null,
                    onTap: () => setState(() {
                      _subscriptionPlan = null;
                      _subscriptionAcquiredAt = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _PlanChip(
                    label: 'Básico',
                    icon: Icons.star_border,
                    color: Colors.blue,
                    selected: _subscriptionPlan == 'basic',
                    onTap: () => setState(() => _subscriptionPlan = 'basic'),
                  ),
                  const SizedBox(width: 8),
                  _PlanChip(
                    label: 'Premium',
                    icon: Icons.workspace_premium,
                    color: Colors.amber,
                    selected: _subscriptionPlan == 'premium',
                    onTap: () => setState(() => _subscriptionPlan = 'premium'),
                  ),
                ],
              ),
              if (_subscriptionPlan != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _subscriptionAcquiredAt ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'Data de aquisição do plano',
                    );
                    if (date != null) setState(() => _subscriptionAcquiredAt = date);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          _subscriptionAcquiredAt == null
                              ? 'Data de aquisição'
                              : '${_subscriptionAcquiredAt!.day.toString().padLeft(2,'0')}/${_subscriptionAcquiredAt!.month.toString().padLeft(2,'0')}/${_subscriptionAcquiredAt!.year}',
                          style: TextStyle(
                            fontSize: 16,
                            color: _subscriptionAcquiredAt == null ? Colors.grey[400] : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _notesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Preferências ou Observações',
              hintText: 'Ex: Alergia a navalha, corte disfarçado baixo, aceita cerveja...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 32), 
                child: Icon(Icons.edit_note),
              ),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _saveClient,
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text(_isEditing ? 'Atualizar Cliente' : 'Salvar Cliente', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PlanChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey[400],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}