import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';
import '../../core/presentation/desktop_shell.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/reports/presentation/financial_screen.dart';
import '../../features/orders/presentation/schedule_agenda_screen.dart';
import '../../features/units/presentation/units_list_screen.dart';
import '../../features/settings/menu_screen.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      loading: () => const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(backgroundColor: const Color(0xFF121212), body: Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red)))),
      data: (user) {
        final isLeader = user['category'] == 'Barbeiro Líder' || user['role'] == 'admin';

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900 && isLeader) {
              return const DesktopShell();
            }
            return _buildMobileLayout(user, isLeader);
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> user, bool isLeader) {
    final List<Widget> tabs = [
      const HomeScreen(),
      const ScheduleAgendaScreen(),
      const ClientsScreen(),
      if (isLeader) const FinancialScreen(),
      if (isLeader) const UnitsListScreen(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
      const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Agenda'),
      const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
      if (isLeader) const BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Caixa'),
      if (isLeader) const BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Unidades'),
    ];

    if (_currentIndex >= tabs.length) {
      _currentIndex = tabs.length - 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BarberOS', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              _showNotificationsDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MenuScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: navItems,
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Notificações', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Nenhuma notificação ainda',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Os lembretes de agendamento aparecerão aqui.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}