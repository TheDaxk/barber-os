import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';
import '../../core/presentation/desktop_shell.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/reports/presentation/financial_screen.dart';
import '../../features/orders/presentation/schedule_agenda_screen.dart';
import '../../features/settings/menu_screen.dart';
import '../rbac/app_permissions.dart';
import './widgets/unit_selector_widget.dart';
import '../../features/reports/presentation/widgets/financial_export_sheet.dart';

import '../../features/orders/providers/schedule_lock_provider.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  bool _isTogglingLock = false;

  Future<void> _handleToggleLock({
    required bool currentLockState,
    required String barberId,
  }) async {
    if (_isTogglingLock) return;
    setState(() => _isTogglingLock = true);

    final supabase = ref.read(supabaseProvider);

    try {
      await toggleScheduleLock(
        barberId: barberId,
        currentValue: currentLockState,
        supabase: supabase,
      );
      ref.invalidate(scheduleLockProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar agenda: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingLock = false);
    }
  }

  Widget _buildAgendaActions(Map<String, dynamic> user) {
    final scheduleLockAsync = ref.watch(scheduleLockProvider);
    final perm = AppPermissions(user);
    final barberId = user['barber_id'] as String?;

    // Só exibe o botão de fechar agenda para barbeiros comuns (não líderes/admin)
    if (perm.isGlobalAdmin || barberId == null) return const SizedBox.shrink();

    return scheduleLockAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (isLocked) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLocked ? 'Fechada' : 'Aberta',
              style: TextStyle(
                color: isLocked ? Colors.red[300] : Colors.green[300],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            _isTogglingLock
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: !isLocked,
                      onChanged: (_) => _handleToggleLock(
                        currentLockState: isLocked,
                        barberId: barberId,
                      ),
                      activeThumbColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      loading: () => const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(backgroundColor: const Color(0xFF121212), body: Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red)))),
      data: (user) {
        final perm = AppPermissions(user);

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900 && perm.canAccessDesktop) {
              return const DesktopShell();
            }
            return _buildMobileLayout(user, perm);
          },
        );
      },
    );
  }



  Widget _buildMobileLayout(Map<String, dynamic> user, AppPermissions perm) {
    final List<Widget> tabs = [];
    final List<BottomNavigationBarItem> navItems = [];

    // Aba 1: Início
    tabs.add(const HomeScreen());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined), 
      activeIcon: Icon(Icons.home),
      label: 'Início'
    ));

    // Aba 2: Agenda
    tabs.add(const ScheduleAgendaScreen());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today_outlined), 
      activeIcon: Icon(Icons.calendar_today),
      label: 'Agenda'
    ));

    // Aba 3: Clientes
    tabs.add(const ClientsScreen());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.people_outlined), 
      activeIcon: Icon(Icons.people),
      label: 'Clientes'
    ));

    // Aba 4: Caixa/Financeiro (Apenas se tiver permissão)
    if (perm.canAccessFinancial) {
      tabs.add(const FinancialScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_wallet_outlined), 
        activeIcon: Icon(Icons.account_balance_wallet),
        label: 'Caixa'
      ));
    }

    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    final isFinancialTab = perm.canAccessFinancial && _currentIndex == 3;
    final isAgendaTab = _currentIndex == 1;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        title: const UnitSelectorWidget(),
        centerTitle: false,
        actions: [
          // Ações específicas da Agenda
          if (isAgendaTab) _buildAgendaActions(user),
          


          // Ações específicas do Financeiro
          if (isFinancialTab)
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: Colors.grey),
              tooltip: 'Exportar relatório',
              onPressed: () => FinancialExportSheet.show(context),
            ),

          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.grey),
            onPressed: () => _showNotificationsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const MenuScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: BottomNavigationBar(
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
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: navItems,
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog<void>(
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