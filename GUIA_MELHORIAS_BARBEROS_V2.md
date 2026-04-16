# 🛠️ BarberOS — Guia de Correções e Melhorias (V2)

> Diagnóstico completo e instruções de implementação para todos os pontos levantados.

---

## ÍNDICE

1. [BUG — Seletor de Unidade na Home para Barbeiro Líder](#bug-1)
2. [BUG — Barbeiros somem da tela de Equipe ao trocar de unidade](#bug-2)
3. [BUG — Ícones do app "sumiram"](#bug-3)
4. [Inconsistências Gerais Identificadas no Código](#inconsistencias)
5. [MELHORIA — Tela ERP Desktop para Barbeiro Líder](#melhoria-erp)
6. [MELHORIA — Plano de Redesign com Identidade Visual (Dourado & Preto)](#melhoria-design)

---

<a name="bug-1"></a>
## BUG #1 — Seletor de Unidade na Home para Barbeiro Líder

### 🔍 Diagnóstico

O `dashboardProvider` busca dados **fixados na `unit_id` do usuário logado**, sem nenhuma variável de estado que permita trocar a unidade visualizada:

```dart
// lib/features/dashboard/providers/dashboard_provider.dart
final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();
final unitId = userRes['unit_id']; // ← HARDCODED, sem possibilidade de trocar
```

A `HomeScreen` também não verifica o perfil do usuário para exibir controles de liderança — ela simplesmente não sabe se o logado é um líder.

Além disso, já existe um `selectedTeamUnitProvider` em `lib/features/team/providers/selected_unit_provider.dart` usado na tela de Equipe, mas ele **não é compartilhado** com o dashboard. A solução correta é criar um provider global de unidade selecionada e usá-lo em toda a aplicação.

---

### ✅ Como Corrigir

#### Passo 1 — Criar um provider global de unidade selecionada

Crie o arquivo `lib/core/providers/selected_unit_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider global — null significa "unidade padrão do usuário logado"
final selectedUnitIdProvider = StateProvider<String?>((ref) => null);
```

> ⚠️ Não delete o `selectedTeamUnitProvider` ainda — você vai migrar a tela de Equipe para usar este no Passo 3.

---

#### Passo 2 — Atualizar o `dashboardProvider` para respeitar a unidade selecionada

**Arquivo:** `lib/features/dashboard/providers/dashboard_provider.dart`

Substitua o início do provider:

**Antes:**
```dart
final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();
  final unitId = userRes['unit_id'];
```

**Depois:**
```dart
import '../../../core/providers/selected_unit_provider.dart'; // novo import

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnit = ref.watch(selectedUnitIdProvider); // observa a seleção

  String unitId;
  if (selectedUnit != null) {
    unitId = selectedUnit; // usa a unidade escolhida pelo líder
  } else {
    final userId = supabase.auth.currentUser!.id;
    final userRes = await supabase.from('users').select('unit_id').eq('id', userId).single();
    unitId = userRes['unit_id'] as String;
  }
```

---

#### Passo 3 — Adicionar o seletor de unidade na `HomeScreen`

**Arquivo:** `lib/features/dashboard/presentation/home_screen.dart`

Adicione os imports no topo:
```dart
import '../../../core/supabase/providers.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../../features/units/providers/units_provider.dart';
```

No método `build()`, antes do `return RefreshIndicator`, adicione a leitura do perfil:
```dart
final userProfileAsync = ref.watch(userProfileProvider);
final isLeader = userProfileAsync.maybeWhen(
  data: (u) => u['category'] == 'Barbeiro Líder' || u['role'] == 'admin',
  orElse: () => false,
);
final selectedUnitId = ref.watch(selectedUnitIdProvider);
```

Substitua o cabeçalho fixo da `HomeScreen` por um dinâmico com seletor:

**Antes:**
```dart
const Text(
  'Unidade Local',
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
),
```

**Depois:**
```dart
if (isLeader)
  _buildUnitSelectorHeader(selectedUnitId)
else
  const Text(
    'Minha Unidade',
    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  ),
```

Adicione o método `_buildUnitSelectorHeader` na classe `_HomeScreenState`:

```dart
Widget _buildUnitSelectorHeader(String? selectedUnitId) {
  final unitsAsync = ref.watch(unitsProvider);

  return unitsAsync.when(
    loading: () => const Text('Carregando...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    error: (_, __) => const Text('Erro ao carregar unidades'),
    data: (units) {
      final selectedUnit = units.firstWhere(
        (u) => u['id'] == selectedUnitId,
        orElse: () => {'name': 'Todas as Unidades'},
      );

      return InkWell(
        onTap: () => _showUnitPicker(units),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedUnit['name'] as String? ?? 'Unidade',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 22),
          ],
        ),
      );
    },
  );
}

void _showUnitPicker(List<Map<String, dynamic>> units) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Selecionar Unidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: Colors.grey),
              title: const Text('Minha Unidade (Padrão)'),
              trailing: ref.read(selectedUnitIdProvider) == null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                ref.read(selectedUnitIdProvider.notifier).state = null;
                ref.invalidate(dashboardProvider);
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ...units.map((unit) {
              final isSelected = ref.read(selectedUnitIdProvider) == unit['id'];
              return ListTile(
                leading: const Icon(Icons.store_outlined, color: Colors.blueAccent),
                title: Text(unit['name'] as String? ?? 'Unidade'),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  ref.read(selectedUnitIdProvider.notifier).state = unit['id'] as String;
                  ref.invalidate(dashboardProvider);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
```

---

#### Passo 4 — Migrar `EmployeesScreen` para usar o provider global

**Arquivo:** `lib/features/team/providers/employees_provider.dart`

Troque o import de `selected_unit_provider.dart` local pelo global:

```dart
// Remova:
import 'selected_unit_provider.dart';
// Adicione:
import '../../../core/providers/selected_unit_provider.dart';
```

Troque `selectedTeamUnitProvider` por `selectedUnitIdProvider`:
```dart
final selectedUnitId = ref.watch(selectedUnitIdProvider); // era selectedTeamUnitProvider
```

Faça o mesmo nas referências dentro de `employees_screen.dart`.

---

<a name="bug-2"></a>
## BUG #2 — Barbeiros somem ao trocar de unidade na tela de Equipe

### 🔍 Diagnóstico

O `employeesProvider` filtra **estritamente** por `unit_id`:

```dart
// lib/features/team/providers/employees_provider.dart
final response = await supabase
    .from('barbers')
    .select('id, user_id, unit_name, category, commission_rate, is_active, unit_id, users(id, name, email, phone)')
    .eq('unit_id', unitId!)  // ← filtra por unit_id fixo
    .eq('is_active', true);
```

Quando o Barbeiro Líder usa o seletor e muda para uma unidade onde o barbeiro **não tem `unit_id` registrado** (ou foi movido de unidade sem que o campo `unit_id` de `barbers` fosse atualizado), o barbeiro simplesmente desaparece da lista.

**A causa raiz:** quando se cria um funcionário, o `unit_id` em `barbers` é preenchido com a unidade do gestor que criou — e ao editar a "unidade" pelo formulário, o código atual só atualiza o campo de texto `unit_name` (que é apenas um label), **não atualiza o `unit_id` (que é a FK real)**:

```dart
// employees_screen.dart — no update
await supabase.from('barbers').update({
  'category': selectedCategory,
  'commission_rate': commission,
  'unit_name': unitController.text.trim(), // ← só o nome, não o FK unit_id!
}).eq('id', employee['id']);
```

**Solução dupla:** corrigir o update para gravar o `unit_id` real, e para o Barbeiro Líder, oferecer a opção de ver **todos** os barbeiros (sem filtro de unidade).

---

### ✅ Como Corrigir

#### Passo 1 — Adicionar opção "Ver Todos" no `employeesProvider`

**Arquivo:** `lib/features/team/providers/employees_provider.dart`

```dart
final employeesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final selectedUnitId = ref.watch(selectedUnitIdProvider);
  final userProfile = await ref.watch(userProfileProvider.future);
  final isLeader = userProfile['category'] == 'Barbeiro Líder' || userProfile['role'] == 'admin';

  var query = supabase
      .from('barbers')
      .select('id, user_id, unit_name, category, commission_rate, is_active, unit_id, users(id, name, email, phone)')
      .eq('is_active', true);

  // Líderes veem todos quando nenhuma unidade específica está selecionada
  // Barbeiros comuns sempre veem só sua unidade
  if (!isLeader || selectedUnitId != null) {
    final unitId = selectedUnitId ?? (userProfile['unit_id'] as String?);
    if (unitId != null) {
      query = query.eq('unit_id', unitId);
    }
  }

  final response = await query.order('category');
  return List<Map<String, dynamic>>.from(response);
});
```

#### Passo 2 — Corrigir o formulário de edição para atualizar `unit_id` real

**Arquivo:** `lib/features/team/presentation/employees_screen.dart`

No formulário de edição, substitua o campo de texto `unitController` por um dropdown que busque as unidades reais. Primeiro, adicione uma variável de estado no `StatefulBuilder`:

```dart
// Dentro do showModalBottomSheet, no StatefulBuilder
String? selectedUnitIdForEdit = isEditing ? employee['unit_id'] as String? : null;
```

Substitua o `TextField` de unidade (no modo de edição) por:

```dart
// No modo edição (dentro do if isEditing ou no campo de unidade)
const Text('Unidade', style: TextStyle(color: Colors.grey, fontSize: 13)),
const SizedBox(height: 8),
Consumer(builder: (context, ref, _) {
  final unitsAsync = ref.watch(unitsProvider);
  return unitsAsync.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, __) => const Text('Erro ao carregar unidades', style: TextStyle(color: Colors.red)),
    data: (units) => DropdownButtonFormField<String>(
      value: selectedUnitIdForEdit,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: const Icon(Icons.store_outlined, color: Colors.grey, size: 18),
      ),
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
```

No bloco de `update` (salvar edição), inclua o `unit_id`:

```dart
await supabase.from('barbers').update({
  'category': selectedCategory,
  'commission_rate': commission,
  'unit_id': selectedUnitIdForEdit,        // ← FK real
  'unit_name': selectedUnitNameForEdit,    // ← label textual (busque pelo nome da unidade selecionada)
}).eq('id', employee['id']);
```

---

<a name="bug-3"></a>
## BUG #3 — Ícones do app "sumiram" (aparecem como caixas/quadrados)

### 🔍 Diagnóstico

Após análise do `pubspec.yaml` e do projeto, identificamos **duas causas independentes**:

**Causa A — `flutter_launcher_icons` ausente no projeto**

O `pubspec.yaml` **não contém** o pacote `flutter_launcher_icons` nem a seção de configuração `flutter_icons:`. Os ícones nas pastas `mipmap-*` do Android são os ícones padrão do Flutter (o logo azul da mariposa), e nunca foram substituídos pelos ícones do BarberOS.

```yaml
# pubspec.yaml atual — NÃO tem:
# flutter_icons:
#   android: true
#   ios: true
#   image_path: "assets/icons/app_icon.png"
```

**Causa B — `flutter_local_notifications` apontando para ícone inexistente**

O `notification_service.dart` configura as notificações Android com:
```dart
const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
```

Se o app não possui um `ic_launcher` customizado nas pastas `mipmap`, as notificações usarão o ícone padrão do Flutter — que em versões do Android 12+ é renderizado como um **quadrado branco sólido** (ícone monocromático adaptativo), pois o sistema recorta o ícone e aplica a cor do tema.

---

### ✅ Como Corrigir

#### Passo 1 — Instalar e configurar o `flutter_launcher_icons`

Adicione ao `pubspec.yaml` em `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1  # adicione esta linha
```

Adicione também a seção de configuração **no final do `pubspec.yaml`**:

```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
  adaptive_icon_background: "#1E1E1E"   # fundo preto para Android 12+
  adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"
  web:
    generate: true
    image_path: "assets/icons/app_icon.png"
```

#### Passo 2 — Preparar os assets de ícone

Crie a pasta `assets/icons/` na raiz do projeto e adicione:
- `app_icon.png` — ícone completo (1024x1024px, fundo escuro com logo dourado)
- `app_icon_foreground.png` — apenas o logo sem fundo (para ícone adaptativo Android)

Adicione a pasta ao `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/icons/
```

#### Passo 3 — Gerar os ícones

```bash
flutter pub get
dart run flutter_launcher_icons
```

#### Passo 4 — Corrigir ícone de notificação para Android 12+

**Arquivo:** `lib/core/services/notification_service.dart`

Crie um ícone dedicado para notificações (monocromático branco, 96x96px) e salve em `android/app/src/main/res/drawable/ic_notification.png`.

Depois atualize:

```dart
const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
```

E no canal de notificação:
```dart
const androidDetails = AndroidNotificationDetails(
  'barberos_channel',
  'BarberOS Notifications',
  channelDescription: 'Notificações do BarberOS',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@drawable/ic_notification', // ← ícone monocromático
  color: Color(0xFFD4AF37),           // cor dourada para o badge
  showWhen: true,
);
```

---

<a name="inconsistencias"></a>
## Inconsistências Gerais Identificadas no Código

### 🔍 4.1 — Dois sistemas de navegação em conflito

**Problema:** O `pubspec.yaml` declara `go_router: ^17.1.0`, mas toda a navegação do app usa `MaterialPageRoute`. O `go_router` está instalado mas nunca é utilizado — é dependência morta que aumenta o tamanho do build.

**Correção:** Remova o `go_router` do `pubspec.yaml` enquanto não for migrar a navegação:
```yaml
# Remover esta linha de dependencies:
# go_router: ^17.1.0
```

---

### 🔍 4.2 — Dois `unitsProvider` com comportamentos diferentes

**Problema:** Existem dois arquivos com providers de nome `unitsProvider`:
- `lib/features/team/providers/units_provider.dart` — filtra por `is_active: true`
- `lib/features/units/providers/units_provider.dart` — **sem filtro**, busca todas as unidades

Dependendo do arquivo importado, o comportamento muda silenciosamente. Já há importações ambíguas no projeto.

**Correção:** Consolide em um único provider no core:

**Arquivo:** `lib/core/providers/units_provider.dart` (novo arquivo central):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/providers.dart';

final unitsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('units')
      .select('*')
      .eq('is_active', true)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});
```

Depois atualize todos os imports para apontar para este arquivo central e delete os dois providers duplicados.

---

### 🔍 4.3 — `selectedTeamUnitProvider` importa de `riverpod/legacy.dart`

**Problema:** 
```dart
// lib/features/team/providers/selected_unit_provider.dart
import 'package:riverpod/legacy.dart'; // ← API legada
```

Isso usa a API antiga do Riverpod. Com `flutter_riverpod: ^3.x`, deve usar `flutter_riverpod`.

**Correção** (já coberta pelo Bug #1, Passo 4 — ao migrar para o provider global):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart'; // correto
```

---

### 🔍 4.4 — `userProfileProvider` usa `autoDispose` no provider raiz

**Problema:** O `userProfileProvider` usa `.autoDispose`, o que faz com que seja **destruído e recriado** toda vez que nenhuma tela o está observando. Como a `MainNavigation` o usa para decidir o layout (tabs visíveis), cada vez que o usuário sai e volta para uma aba, há uma requisição desnecessária ao Supabase.

**Correção:** Remova o `autoDispose` do `userProfileProvider`, pois ele precisa viver durante toda a sessão:

```dart
// Antes:
final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {

// Depois:
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
```

---

### 🔍 4.5 — `drift` declarado como dependência mas nunca usado

**Problema:** O `pubspec.yaml` declara `drift: ^2.32.1` e `drift_dev`, mas não existe nenhum arquivo `.dart` que importe ou utilize o Drift no projeto. É um banco local que foi planejado mas nunca implementado.

**Correção:** Remova as dependências não utilizadas:
```yaml
# Remover:
# drift: ^2.32.1
# sqlite3_flutter_libs: ^0.6.0+eol
# path_provider: ^2.1.5

# Em dev_dependencies, remover:
# build_runner: ^2.13.1
# drift_dev: ^2.32.1
```

---

<a name="melhoria-erp"></a>
## MELHORIA — Tela ERP Desktop para Barbeiro Líder

### 📐 Visão Geral da Arquitetura

A ideia é criar um layout responsivo: em telas largas (desktop/tablet), exibir um **menu lateral fixo + conteúdo principal**; em telas móveis, manter o `BottomNavigationBar` atual. O Flutter detecta o tamanho da tela via `LayoutBuilder` ou `MediaQuery`.

**Estrutura de arquivos a criar:**
```
lib/
├── core/
│   └── presentation/
│       ├── main_navigation.dart         ← modificar
│       └── desktop_shell.dart           ← CRIAR
├── features/
│   └── dashboard/
│       └── presentation/
│           └── leader_overview_screen.dart  ← CRIAR
```

---

### Passo 1 — Criar o `DesktopShell` (layout ERP com menu lateral)

**Arquivo novo:** `lib/core/presentation/desktop_shell.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/providers.dart';
import '../../features/dashboard/presentation/leader_overview_screen.dart';
import '../../features/orders/presentation/schedule_agenda_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/reports/presentation/financial_screen.dart';
import '../../features/units/presentation/units_list_screen.dart';
import '../../features/team/presentation/employees_screen.dart';
import '../../features/settings/menu_screen.dart';

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
              // ── MENU LATERAL ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isRailExpanded ? 220 : 72,
                child: Container(
                  color: const Color(0xFF161616),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header / Logo
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

                      // Itens de navegação
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

                      // Footer: Avatar do usuário + Configurações
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

              // ── CONTEÚDO PRINCIPAL ──
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
```

---

### Passo 2 — Criar a `LeaderOverviewScreen` (dashboard ERP)

**Arquivo novo:** `lib/features/dashboard/presentation/leader_overview_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/selected_unit_provider.dart';
import '../../../core/providers/units_provider.dart';
import '../providers/dashboard_provider.dart';

class LeaderOverviewScreen extends ConsumerWidget {
  const LeaderOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);
    final selectedUnitId = ref.watch(selectedUnitIdProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TOPBAR DA TELA ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Visão Geral', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(_getDateString(), style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
              const Spacer(),
              // Seletor de unidade inline
              unitsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (units) => _UnitDropdown(units: units, selectedId: selectedUnitId, ref: ref),
              ),
            ],
          ),
        ),

        // ── CONTEÚDO COM SCROLL ──
        Expanded(
          child: dashboardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
            data: (data) => _buildContent(data),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs em linha (desktop tem espaço)
          _buildKPIRow(data),
          const SizedBox(height: 28),

          // Segunda linha: Últimas comandas + Ranking
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentOrdersCard(data['recentes'] as List<Map<String, dynamic>>)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildRankingCard(data['ranking'] as List<Map<String, dynamic>>)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Terceira linha: Status operacional
          _buildOperationalRow(data),
        ],
      ),
    );
  }

  Widget _buildKPIRow(Map<String, dynamic> data) {
    final kpis = [
      {'label': 'Faturamento', 'value': 'R\$ ${(data['faturamento'] as double).toStringAsFixed(2)}', 'icon': Icons.attach_money, 'color': const Color(0xFF4CAF50)},
      {'label': 'Comandas Fechadas', 'value': '${data['fechadas']}', 'icon': Icons.check_circle_outline, 'color': Colors.blueAccent},
      {'label': 'Em Atendimento', 'value': '${data['abertas']}', 'icon': Icons.timelapse, 'color': Colors.orange},
      {'label': 'Total Comissões', 'value': 'R\$ ${(data['comissoes'] as double).toStringAsFixed(2)}', 'icon': Icons.account_balance_wallet_outlined, 'color': const Color(0xFFD4AF37)},
    ];

    return Row(
      children: kpis.map((kpi) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kpi['icon'] as IconData, color: kpi['color'] as Color, size: 26),
                const SizedBox(height: 12),
                Text(kpi['value'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(kpi['label'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildRecentOrdersCard(List<Map<String, dynamic>> orders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Últimas Comandas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sem movimentos hoje.', style: TextStyle(color: Colors.grey))))
          else
            ...orders.map((order) {
              final isClosed = order['status'] == 'closed';
              final total = ((order['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
              final barber = order['barbers']?['users']?['name'] ?? '-';
              final client = order['client_name'] ?? 'Avulso';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isClosed ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      child: Icon(isClosed ? Icons.check : Icons.access_time, color: isClosed ? Colors.green : Colors.orange, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(barber, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    )),
                    Text('R\$ $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRankingCard(List<Map<String, dynamic>> ranking) {
    const colors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ranking do Dia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (ranking.isEmpty)
            const Center(child: Text('Sem dados ainda.', style: TextStyle(color: Colors.grey)))
          else
            ...ranking.asMap().entries.map((e) {
              final color = e.key < 3 ? colors[e.key] : Colors.grey[600]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text('${e.key + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Text('R\$ ${(e.value['revenue'] as double).toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOperationalRow(Map<String, dynamic> data) {
    final items = [
      {'label': 'Em Espera', 'value': '${data['waiting_count']}', 'color': Colors.orange, 'icon': Icons.hourglass_empty_rounded},
      {'label': 'Barbeiros Ativos', 'value': '${data['active_barbers']}', 'color': Colors.blueAccent, 'icon': Icons.people_outline},
      {'label': 'Próximos Agend.', 'value': '${(data['upcoming'] as List).length}', 'color': Colors.purple, 'icon': Icons.schedule},
    ];
    return Row(
      children: items.map((item) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: item['color'] as Color, width: 3)),
            ),
            child: Row(
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['value'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(item['label'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    final days = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    final months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
  }
}

class _UnitDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> units;
  final String? selectedId;
  final WidgetRef ref;

  const _UnitDropdown({required this.units, required this.selectedId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = units.firstWhere(
      (u) => u['id'] == selectedId,
      orElse: () => {'name': 'Todas as Unidades'},
    );

    return PopupMenuButton<String?>(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined, size: 16, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Text(selected['name'] as String? ?? 'Unidade', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
      onSelected: (id) {
        ref.read(selectedUnitIdProvider.notifier).state = id;
        ref.invalidate(dashboardProvider);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('Todas as Unidades')),
        const PopupMenuDivider(),
        ...units.map((u) => PopupMenuItem(
          value: u['id'] as String,
          child: Text(u['name'] as String? ?? 'Unidade'),
        )),
      ],
    );
  }
}
```

---

### Passo 3 — Modificar `MainNavigation` para ser responsivo

**Arquivo:** `lib/core/presentation/main_navigation.dart`

Envolva o `build` com um `LayoutBuilder` que decide qual shell usar:

```dart
@override
Widget build(BuildContext context) {
  final userProfileAsync = ref.watch(userProfileProvider);

  return userProfileAsync.when(
    loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
    error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
    data: (user) {
      final isLeader = user['category'] == 'Barbeiro Líder' || user['role'] == 'admin';

      return LayoutBuilder(
        builder: (context, constraints) {
          // Desktop: largura > 900px E usuário é líder
          if (constraints.maxWidth > 900 && isLeader) {
            return const DesktopShell();
          }
          // Mobile: bottom nav bar (comportamento atual)
          return _buildMobileLayout(user, isLeader);
        },
      );
    },
  );
}
```

---

<a name="melhoria-design"></a>
## MELHORIA — Plano de Redesign: Identidade Visual Dourado & Preto

> Baseado na logomarca **Marcos Styllo 7.0**: fundo escuro/preto, detalhes dourados, estética premium de barbearia.

### 🎨 Paleta de Cores Proposta

| Token | Hex | Uso |
|-------|-----|-----|
| `goldPrimary` | `#D4AF37` | Cor de destaque principal (accent) |
| `goldLight` | `#F0CC5A` | Hover, ícones ativos, badges |
| `goldDark` | `#A8860A` | Sombra/borda de elementos dourados |
| `bgDeep` | `#0E0E0E` | Fundo da tela raiz (Scaffold) |
| `bgCard` | `#1A1A1A` | Cards, bottom sheets |
| `bgElevated` | `#242424` | Campos de input, chips selecionados |
| `borderSubtle` | `#2E2E2E` | Bordas de cards (sem destaque) |
| `textPrimary` | `#F5F5F5` | Texto principal |
| `textSecondary` | `#888888` | Texto secundário, labels |
| `success` | `#4CAF50` | Status concluído |
| `warning` | `#FF9800` | Status em espera |
| `error` | `#F44336` | Erros, cancelamentos |

---

### 📋 Plano de Implementação em Fases

#### Fase 1 — Tokens de Design (ThemeData central) — `main.dart`

Crie um arquivo `lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const goldPrimary  = Color(0xFFD4AF37);
  static const goldLight    = Color(0xFFF0CC5A);
  static const goldDark     = Color(0xFFA8860A);
  static const bgDeep       = Color(0xFF0E0E0E);
  static const bgCard       = Color(0xFF1A1A1A);
  static const bgElevated   = Color(0xFF242424);
  static const borderSubtle = Color(0xFF2E2E2E);
  static const textPrimary  = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF888888);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.goldPrimary,
        onPrimary: Colors.black,
        secondary: AppColors.goldLight,
        surface: AppColors.bgCard,
        onSurface: AppColors.textPrimary,
        error: Color(0xFFF44336),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF141414),
        selectedItemColor: AppColors.goldPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedColor: AppColors.goldPrimary.withOpacity(0.2),
        side: const BorderSide(color: AppColors.borderSubtle),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
```

Aplique no `main.dart`:

```dart
// Antes:
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E1E1E), brightness: Brightness.dark),
  useMaterial3: true,
),

// Depois:
theme: AppTheme.dark,
```

---

#### Fase 2 — Ajustes Pontuais nas Telas (após aplicar o tema)

Após aplicar o `AppTheme`, substitua gradualmente as cores hardcoded:

| Padrão antigo | Substituir por |
|---|---|
| `Colors.green` (botão principal) | `AppColors.goldPrimary` |
| `Colors.grey[900]` (card) | `AppColors.bgCard` |
| `Colors.grey[800]` (input) | `AppColors.bgElevated` |
| `Colors.white10` (borda) | `AppColors.borderSubtle` |
| `const Color(0xFF1E1E1E)` | `AppColors.bgCard` |
| `const Color(0xFF121212)` | `AppColors.bgDeep` |
| `Colors.green` (selectedItem nav) | `AppColors.goldPrimary` |
| `Colors.blueAccent` (category chip) | `AppColors.goldPrimary` |

> 💡 **Dica de execução:** Faça um `Find & Replace` no VS Code para cada padrão listado, tela por tela, testando visualmente no simulador. Não tente substituir tudo de uma vez.

---

#### Fase 3 — Tipografia com personalidade (opcional, impacto alto)

Adicione ao `pubspec.yaml`:
```yaml
  google_fonts: ^6.2.1
```

No `AppTheme`, adicione:
```dart
import 'package:google_fonts/google_fonts.dart';

// Dentro do ThemeData:
textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme).copyWith(
  displayLarge: GoogleFonts.cinzelDecorative(
    color: AppColors.goldPrimary,
    fontWeight: FontWeight.bold,
  ),
  // Cinzel Decorative: para o logo/título do app (dá aquele ar de barbearia clássica)
  // Lato: para o corpo de texto (limpo e legível)
),
```

> `Cinzel Decorative` tem estética de gravação em pedra/metal — combina muito com a logo do Marcos Styllo.

---

#### Fase 4 — Detalhes que fazem a diferença

- **Ícone do app:** Use a logo dourada com fundo `#0E0E0E` (gerado no Bug #3)
- **Splash screen:** Tela preta com o ícone dourado centralizado e fade-in suave
- **Bottom nav selecionado:** Adicionar um `indicator` dourado sobre o ícone:
```dart
bottomNavigationBarTheme: BottomNavigationBarThemeData(
  selectedItemColor: AppColors.goldPrimary,
  // ...
)
```
- **FloatingActionButton:** Mudar de branco para dourado:
```dart
floatingActionButtonTheme: const FloatingActionButtonThemeData(
  backgroundColor: AppColors.goldPrimary,
  foregroundColor: Colors.black,
),
```

---

## 📋 Resumo dos Arquivos a Criar/Modificar

| Arquivo | Ação | Bug/Melhoria |
|---|---|---|
| `lib/core/providers/selected_unit_provider.dart` | **CRIAR** | Bug #1 |
| `lib/core/providers/units_provider.dart` | **CRIAR** | Inconsistência 4.2 |
| `lib/features/dashboard/providers/dashboard_provider.dart` | Modificar | Bug #1 |
| `lib/features/dashboard/presentation/home_screen.dart` | Modificar | Bug #1 |
| `lib/features/team/providers/employees_provider.dart` | Modificar | Bug #2 |
| `lib/features/team/presentation/employees_screen.dart` | Modificar | Bug #2 |
| `lib/core/services/notification_service.dart` | Modificar | Bug #3 |
| `android/app/src/main/res/drawable/ic_notification.png` | **CRIAR** | Bug #3 |
| `assets/icons/app_icon.png` | **CRIAR** | Bug #3 |
| `pubspec.yaml` | Modificar | Bug #3 + Inconsistências |
| `lib/core/presentation/desktop_shell.dart` | **CRIAR** | Melhoria ERP |
| `lib/features/dashboard/presentation/leader_overview_screen.dart` | **CRIAR** | Melhoria ERP |
| `lib/core/presentation/main_navigation.dart` | Modificar | Melhoria ERP |
| `lib/core/theme/app_theme.dart` | **CRIAR** | Melhoria Design |
| `lib/main.dart` | Modificar | Melhoria Design |
