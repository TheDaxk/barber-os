import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../../../features/dashboard/presentation/leader_overview_screen.dart';
import '../../../features/orders/presentation/schedule_agenda_screen.dart';
import '../../../features/clients/clients_screen.dart';
import '../../../features/reports/presentation/financial_screen.dart';
import '../../../features/team/presentation/employees_screen.dart';
import '../../../features/units/presentation/units_list_screen.dart';
import '../../../features/settings/menu_screen.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _selectedIndex = 0;
  bool _isRailExpanded = true;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Visão Geral'),
    _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Agenda'),
    _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Clientes'),
    _NavItem(icon: Icons.attach_money_outlined, activeIcon: Icons.attach_money, label: 'Financeiro'),
    _NavItem(icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Equipe'),
    _NavItem(icon: Icons.business_outlined, activeIcon: Icons.business, label: 'Unidades'),
  ];

  final List<Widget> _screens = const [
    LeaderOverviewScreen(),
    ScheduleAgendaScreen(),
    ClientsScreen(),
    FinancialScreen(),
    EmployeesScreen(),
    UnitsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (user) {
        return Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isRailExpanded ? 220 : 72,
                child: Container(
                  color: const Color(0xFF161616),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 24),
                            if (_isRailExpanded) ...[
                              const SizedBox(width: 12),
                              const Text(
                                'BarberOS',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _isRailExpanded ? Icons.menu_open : Icons.menu,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isRailExpanded = !_isRailExpanded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: _navItems.length,
                          itemBuilder: (context, index) {
                            final item = _navItems[index];
                            final isSelected = _selectedIndex == index;
                            return _buildNavItem(item, index, isSelected);
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15),
                              child: Text(
                                (user['name'] as String? ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            if (_isRailExpanded) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  user['name'] as String? ?? 'Usuário',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.grey),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen())),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF121212),
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isSelected ? item.activeIcon : item.icon,
          color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[500],
          size: 22,
        ),
        title: _isRailExpanded
            ? Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[300],
                ),
              )
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isRailExpanded ? 12 : 14,
          vertical: 0,
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
