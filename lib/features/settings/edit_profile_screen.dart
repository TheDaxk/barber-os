import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';
// Import do menu_screen removido pois o provider agora está no arquivo core

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> userProfile;

  const EditProfileScreen({super.key, required this.userProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile['name'] as String? ?? '');
    _phoneController = TextEditingController(text: widget.userProfile['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;

      await supabase.from('users').update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('id', userId);

      // Invalida o provider para a tela de Menu carregar os novos dados
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar Placeholder Edit
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Campos de Formulário
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Nome Completo', Icons.person_outline),
              onChanged: (val) => setState(() {}), // Atualiza a Letra Inicial no Avatar
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Telefone (WhatsApp)', Icons.phone_outlined),
            ),
            const SizedBox(height: 16),
            
            // Campos apenas leitura (Email, Categoria)
            TextField(
              controller: TextEditingController(text: widget.userProfile['email'] as String? ?? ''),
              readOnly: true,
              style: const TextStyle(color: Colors.grey),
              decoration: _inputDecoration('E-mail (Apenas Leitura)', Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: widget.userProfile['category'] as String? ?? 'Gestor'),
              readOnly: true,
              style: const TextStyle(color: Colors.grey),
              decoration: _inputDecoration('Cargo (Apenas Leitura)', Icons.badge_outlined),
            ),
            
            const SizedBox(height: 48),

            // Botão Salvar
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
