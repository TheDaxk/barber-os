import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../providers/units_provider.dart';

class UnitFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? unit; // null = criar, não-null = editar

  const UnitFormScreen({super.key, this.unit});

  @override
  ConsumerState<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends ConsumerState<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;
  bool _isLoading = false;

  bool get isEditing => widget.unit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: (widget.unit?['name'] as String?) ?? '');
    _locationController = TextEditingController(text: (widget.unit?['location'] as String?) ?? '');
    _phoneController = TextEditingController(text: (widget.unit?['phone'] as String?) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      if (isEditing) {
        await supabase.from('units').update(data).eq('id', widget.unit!['id'] as String);
      } else {
        await supabase.from('units').insert(data);
      }

      ref.invalidate(unitsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Unidade atualizada!' : 'Unidade criada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUnit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Excluir Unidade', style: TextStyle(color: Colors.red)),
        content: const Text('Tem certeza que deseja excluir esta unidade? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      await supabase.from('units').delete().eq('id', widget.unit!['id'] as String);
      ref.invalidate(unitsProvider);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context); // volta para a lista
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unidade excluída!'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Unidade' : 'Nova Unidade'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _isLoading ? null : _deleteUnit,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome da Unidade *',
                hintText: 'Ex: BarberOS Centro',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Localização',
                hintText: 'Ex: Rua Augusta, 123 - São Paulo',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Telefone',
                hintText: 'Ex: (11) 99999-9999',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveUnit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEditing ? 'Salvar Alterações' : 'Criar Unidade',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
