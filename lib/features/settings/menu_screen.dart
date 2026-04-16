import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';
import '../services/create_service_screen.dart';
import '../team/presentation/employees_screen.dart';
import '../auth/presentation/login_screen.dart'; // Import do Login para o Logout
import '../products/presentation/products_management_screen.dart';
import 'edit_profile_screen.dart';
import 'unit_settings_screen.dart';

// userProfileProvider movido para ../../core/supabase/providers.dart

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Gestão e Configurações', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar perfil: $err', style: const TextStyle(color: Colors.red))),
        data: (user) {
          final name = user['name'] ?? 'Usuário';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          final category = user['category'] ?? 'Gestor';
          final isLeader = category == 'Barbeiro Líder' || user['role'] == 'admin';
          
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // ===============================
              // SESSÃO DO PERFIL
              // ===============================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: 'Editar Perfil',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(userProfile: user),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (isLeader) ...[
                // ===============================
                // SESSÃO DE CONFIGURAÇÕES GERAIS
                // ===============================
                const Text('Catálogo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  icon: Icons.content_cut,
                  title: 'Serviços e Combos',
                  subtitle: 'Cadastre novos cortes, barbas e pacotes',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateServiceScreen()));
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: 'Gestão de Produtos',
                  subtitle: 'Cadastre e gerencie produtos',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsManagementScreen()));
                  },
                ),

                const SizedBox(height: 24),

                // Seção: Equipe
                const Text('Equipe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  icon: Icons.badge_outlined,
                  title: 'Profissionais',
                  subtitle: 'Gerencie os barbeiros e comissões',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeesScreen()));
                  },
                ),

                const SizedBox(height: 24),

                // Seção: Configurações da Barbearia
                const Text('Unidade', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                _buildMenuCard(
                  context,
                  icon: Icons.store_outlined,
                  title: 'Horário de Funcionamento',
                  subtitle: 'Defina os horários de abertura e fechamento',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UnitSettingsScreen()));
                  },
                ),
              ],

              const SizedBox(height: 48),

              // Botão de Sair
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    ref.invalidate(userProfileProvider);
                    await ref.read(supabaseProvider).auth.signOut();
                    
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sair do Aplicativo', style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget reutilizável para deixar os botões do menu padronizados e bonitos
  Widget _buildMenuCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      color: Colors.grey[900],
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}