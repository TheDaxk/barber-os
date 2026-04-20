import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import 'services_provider.dart';

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  
  bool _isComboMode = false; // NOVO: Controla a Aba (Serviço vs Combo)
  int _selectedDuration = 30; 
  String _selectedSector = 'barbearia'; // NOVO: Setor padrão
  bool _isLoading = false;

  // Para o modo Combo
  final Set<String> _selectedSubServices = {};
  int _comboCalculatedDuration = 0;
  double _comboOriginalPrice = 0.0;

  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Calcula o tempo e o preço original do combo ao selecionar/desmarcar serviços
  void _recalculateCombo(List<Map<String, dynamic>> allServices) {
    int duration = 0;
    double price = 0.0;

    for (var s in allServices) {
      if (_selectedSubServices.contains(s['id'])) {
        duration += (s['duration_minutes'] as int? ?? 30);
        price += (s['price'] as num? ?? 0).toDouble();
      }
    }

    setState(() {
      _comboCalculatedDuration = duration;
      _comboOriginalPrice = price;
    });
  }

  Future<void> _saveService() async {
    if (_nameController.text.trim().isEmpty || _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o nome e o preço.')));
      return;
    }

    if (_isComboMode && _selectedSubServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione pelo menos um serviço para o combo.')));
      return;
    }

    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final userId = supabase.auth.currentUser!.id;
      final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();

      final textPrice = _priceController.text.replaceAll(',', '.');
      final price = double.tryParse(textPrice) ?? 0.0;
      
      // Se for combo, usa o tempo calculado; se não, usa o tempo manual
      final finalDuration = _isComboMode ? _comboCalculatedDuration : _selectedDuration;

      await supabase.from('services').insert({
        'unit_id': userRes['unit_id'] as Object,
        'name': _nameController.text.trim(),
        'price': price,
        'duration_minutes': finalDuration,
        'is_combo': _isComboMode,
        'sector': _selectedSector, // NOVO: Salva o setor
        'is_active': true,
      });

      // Limpa tudo após salvar
      _nameController.clear();
      _priceController.clear();
      setState(() {
        _selectedDuration = 30;
        _selectedSubServices.clear();
        _comboCalculatedDuration = 0;
        _comboOriginalPrice = 0.0;
      });

      ref.invalidate(unitServicesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(String id) async {
    try {
      await ref.read(supabaseProvider).from('services').update({'is_active': false}).eq('id', id);
      ref.invalidate(unitServicesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao apagar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(unitServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÁREA DE CRIAÇÃO
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOGGLE: SERVIÇO vs COMBO
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isComboMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isComboMode ? Colors.green : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: !_isComboMode ? Colors.green : Colors.grey[700]!),
                            ),
                            alignment: Alignment.center,
                            child: Text('Serviço Único', style: TextStyle(color: !_isComboMode ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isComboMode = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isComboMode ? Colors.amber : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _isComboMode ? Colors.amber : Colors.grey[700]!),
                            ),
                            alignment: Alignment.center,
                            child: Text('Criar Combo', style: TextStyle(color: _isComboMode ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // SELETOR DE SETOR
                  const Text('Destino (Setor):', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSectorChip('barbearia', 'Barbearia', Icons.content_cut),
                      const SizedBox(width: 8),
                      _buildSectorChip('salao', 'Salão', Icons.spa),
                      const SizedBox(width: 8),
                      _buildSectorChip('premium', 'Premium', Icons.star),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // NOME E PREÇO
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: _isComboMode ? 'Nome do Pacote (Ex: Cabelo + Barba)' : 'Nome do Serviço',
                      prefixIcon: Icon(_isComboMode ? Icons.layers : Icons.content_cut, color: Colors.grey),
                      filled: true, fillColor: Colors.grey[800], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isComboMode ? 'Preço Promocional (R\$)' : 'Preço (R\$)',
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                      filled: true, fillColor: Colors.grey[800], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LÓGICA CONDICIONAL: SE FOR COMBO MOSTRA LISTA, SE FOR SERVIÇO MOSTRA CHIPS
                  if (!_isComboMode) ...[
                    const Text('Duração estimada:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _durationOptions.map((mins) {
                        final isSelected = _selectedDuration == mins;
                        return ChoiceChip(
                          label: Text(mins >= 60 ? '${mins ~/ 60}h ${mins % 60 == 0 ? '' : '${mins % 60}m'}' : '${mins}m'),
                          selected: isSelected,
                          onSelected: (selected) { if (selected) setState(() => _selectedDuration = mins); },
                          selectedColor: Colors.green, labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), backgroundColor: Colors.grey[800],
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    // MODO COMBO: Seleção de Serviços
                    const Text('Selecione os serviços deste pacote:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    servicesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, stack) => const Text('Erro ao carregar'),
                      data: (services) {
                        // Filtra apenas serviços normais (não combos) para montar o pacote
                        final baseServices = services.where((s) => s['is_combo'] != true).toList();
                        
                        if (baseServices.isEmpty) {
                          return const Text('Nenhum serviço base cadastrado ainda.', style: TextStyle(color: Colors.grey));
                        }

                        return Container(
                          decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: baseServices.map((service) {
                              final isChecked = _selectedSubServices.contains(service['id']);
                              return CheckboxListTile(
                                title: Text(service['name'] as String),
                                subtitle: Text('R\$ ${service['price']} • ${service['duration_minutes']} min', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                value: isChecked,
                                activeColor: Colors.amber,
                                checkColor: Colors.black,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedSubServices.add(service['id'] as String);
                                    } else {
                                      _selectedSubServices.remove(service['id'] as String);
                                    }
                                  });
                                  _recalculateCombo(baseServices);
                                },
                              );
                            }).toList(),
                          ),
                        );
                      }
                    ),
                    
                    // Resumo do Combo Automático
                    if (_selectedSubServices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tempo Total Somado:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text('⏱ ${_comboCalculatedDuration >= 60 ? '${_comboCalculatedDuration ~/ 60}h ${_comboCalculatedDuration % 60}m' : '$_comboCalculatedDuration min'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Preço s/ desconto:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text('R\$ ${_comboOriginalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),

                  // Botão Guardar
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isLoading ? null : _saveService,
                      child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // LISTA DE SERVIÇOS CADASTRADOS (INFERIOR)
            const Text('Catálogo Ativo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Erro ao carregar serviços: $err', style: const TextStyle(color: Colors.red)),
              data: (services) {
                if (services.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Nenhum serviço registado.', style: TextStyle(color: Colors.grey))));
                
                return ListView.separated(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final isCombo = service['is_combo'] == true;
                    final priceStr = (service['price'] as num).toStringAsFixed(2);
                    final mins = service['duration_minutes'] as int;
                    final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60 == 0 ? '' : '${mins % 60}m'}' : '${mins}m';

                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                      tileColor: Colors.grey[900],
                      leading: CircleAvatar(backgroundColor: isCombo ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2), child: Icon(isCombo ? Icons.layers : Icons.content_cut, color: isCombo ? Colors.amber : Colors.green)),
                      title: Row(
                        children: [
                          Expanded(child: Text(service['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (isCombo) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: const Text('COMBO', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)))
                        ],
                      ),
                      subtitle: Text('R\$ $priceStr  •  ⏱ $durationStr', style: TextStyle(color: Colors.grey[400])),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteService(service['id'] as String)),
                    );
                  },
                );
              }
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorChip(String value, String label, IconData icon) {
    final isSelected = _selectedSector == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSector = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.blueAccent : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}