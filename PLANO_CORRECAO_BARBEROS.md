# PLANO_CORRECAO_BARBEROS.md
> Playbook operacional para agente de IA corrigir 3 bugs críticos do BarberOS.
> Escrito para execução com GSD + Gstack + Superpowers.

---

## FASE 0 — ENTENDIMENTO DO SISTEMA

### 🎯 Objetivo
Mapear os arquivos-chave antes de tocar em qualquer código.

### 🔍 O que investigar

| Arquivo | Caminho | Relevância |
|---|---|---|
| `appointments_provider.dart` | `lib/features/orders/providers/` | Bug da agenda |
| `order_items_provider.dart` | `lib/features/orders/providers/` | Bug de comissão |
| `checkout_screen.dart` | `lib/features/orders/presentation/` | Bug de comissão |
| `create_appointment_screen.dart` | `lib/features/orders/presentation/` | Bug de comissão |
| `financial_screen.dart` | `lib/features/reports/presentation/` | Bug do export + comissão exibida |
| `financial_provider.dart` | `lib/features/reports/presentation/` | Queries financeiras |
| `quick_report_screen.dart` | `lib/features/reports/presentation/` | Bug de comissão hardcoded |
| `financial_export_sheet.dart` | `lib/features/reports/presentation/widgets/` | Bug do botão export |
| `main_navigation.dart` | `lib/core/presentation/` | Bug do botão export (lógica do index) |
| `app_permissions.dart` | `lib/core/rbac/` | Permissões RBAC |

### ⚙️ Ações passo a passo

1. Abra o repositório no editor.
2. Execute: `grep -rn "commission_rate\|40\.0\|40%" lib/ --include=*.dart` — anote todos os arquivos com comissão hardcoded.
3. Execute: `grep -rn "startOfToday\|gte.*start_time" lib/ --include=*.dart` — anote filtros de data da agenda.
4. Execute: `grep -rn "FinancialExportSheet\|exportar\|file_download" lib/ --include=*.dart` — rastreie o botão de export.
5. Execute `flutter analyze` e guarde o output para comparação após as correções.

### ✅ Critérios de sucesso
- Você sabe exatamente quais arquivos serão editados em cada bug.
- `flutter analyze` baseline registrado.

---

## FASE 1 — INVESTIGAÇÃO DO BUG DE COMISSÃO

### 🎯 Objetivo
Entender onde o 40% fixo está sendo aplicado e onde `barbers.commission_rate` deveria ser usado.

### 🔍 O que investigar

**Locais com 40% hardcoded confirmados no código atual:**

| Arquivo | Linha aproximada | Contexto |
|---|---|---|
| `financial_screen.dart` | `double comissoes = faturamento * 0.40;` | KPI card "Comissões (40%)" |
| `quick_report_screen.dart` | `comissoesPorBarbeiro[barberName] = ... (total * 0.40)` | Comissão calculada sem consultar barbeiro |
| `order_items_provider.dart` | `double commissionPct = 40.0` (parâmetro default da função `addOrderItem`) | Usado ao adicionar produto/extra |
| `create_appointment_screen.dart` | `(service['commission_pct'] as num?)?.toDouble() ?? 40.0` | Fallback quando serviço não tem `commission_pct` |

**Fonte da verdade:**
- Tabela `barbers`, coluna `commission_rate` (numeric, default 40.00)
- A comissão por barbeiro é individual — não é 40% global

**Fluxo atual de criação de order_item (correto parcialmente):**
```
create_appointment_screen.dart → addOrderItem → usa service['commission_pct'] ?? 40.0
```

**Problema real:**
- A comissão por serviço (`services.commission_pct`) existe no banco, mas não necessariamente reflete a taxa individual do barbeiro (`barbers.commission_rate`).
- A query do `create_appointment_screen` não busca `barber.commission_rate` no momento da criação.
- A `financial_screen` soma tudo com 40% fixo, ignorando `commission_value` já gravado nos `order_items`.

### ⚙️ Ações passo a passo

1. Abra `lib/features/orders/presentation/create_appointment_screen.dart`.
2. Localize a função `_saveAppointment` (próximo da linha 14530).
3. Identifique onde o `finalBarberId` é resolvido — ele já está disponível como variável local.
4. Confirme que a query de barbeiros (`barbersProvider`) retorna `commission_rate`:
   - Busque em `lib/core/supabase/providers.dart` por `barbersProvider`.
   - Confirme que o select inclui `commission_rate`.
5. Abra `lib/features/reports/presentation/financial_screen.dart`.
6. Localize a linha: `double comissoes = faturamento * 0.40;` (método `build`, logo após calcular `faturamento`).
7. Abra `lib/features/reports/presentation/quick_report_screen.dart`.
8. Localize: `comissoesPorBarbeiro[barberName] = ... (total * 0.40)`.
9. Confirme que `monthlyRevenueProvider` NÃO retorna `commission_value` atualmente:
   - Em `financial_provider.dart`, olhe o select: `'id, total, closed_at, client_name, payment_method, barbers(users(name))'`
   - Não inclui `commission_value` dos `order_items` — isso precisa mudar.

### ⚠️ Armadilhas comuns
- ❌ NÃO apague o fallback `?? 40.0` — mantenha como segurança, mas use `barber.commission_rate` primeiro.
- ❌ NÃO altere a estrutura da tabela `order_items` — os campos `commission_pct` e `commission_value` já existem.
- ❌ Não confundir `services.commission_pct` (comissão do tipo de serviço) com `barbers.commission_rate` (taxa pessoal do barbeiro). A lógica correta: a taxa do barbeiro deve sobrepor a do serviço no momento do atendimento.

### ✅ Critérios de sucesso
- Você sabe os 4 locais exatos de 40% hardcoded.
- Você confirmou que `barbersProvider` já inclui `commission_rate` no select.
- Você entendeu que `monthlyRevenueProvider` precisa ser expandido para somar `commission_value` dos `order_items`.

---

## FASE 2 — CORREÇÃO DO BUG DE COMISSÃO

### 🎯 Objetivo
Usar `barbers.commission_rate` ao criar order_items e calcular comissões corretamente no financeiro.

### ⚙️ Ações passo a passo

---

#### PASSO 2.1 — Corrigir `create_appointment_screen.dart`

**Arquivo:** `lib/features/orders/presentation/create_appointment_screen.dart`

**Problema:** Ao criar `order_items`, usa `service['commission_pct'] ?? 40.0` sem considerar a taxa pessoal do barbeiro.

**Correção:**

Localize a função `_saveAppointment`. Antes do loop `for (final serviceId in _selectedServiceIds)`, recupere a `commission_rate` do barbeiro selecionado:

```dart
// ANTES do loop de serviços, buscar commission_rate do barbeiro
double barberCommissionRate = 40.0; // fallback seguro
if (finalBarberId != null) {
  try {
    final barberData = await supabase
        .from('barbers')
        .select('commission_rate')
        .eq('id', finalBarberId)
        .single();
    barberCommissionRate = (barberData['commission_rate'] as num?)?.toDouble() ?? 40.0;
  } catch (_) {
    // Mantém fallback de 40%
  }
}
```

Depois, no loop de criação dos `order_items`, substitua:
```dart
// ANTES (ERRADO):
final commissionPct = (service['commission_pct'] as num?)?.toDouble() ?? 40.0;

// DEPOIS (CORRETO):
// Usa a taxa do barbeiro. Se não existir, cai para commission_pct do serviço, depois para 40%
final commissionPct = barberCommissionRate;
```

O `commissionValue` já é calculado corretamente logo após:
```dart
final commissionValue = servicePrice * (commissionPct / 100);
```

---

#### PASSO 2.2 — Corrigir `financial_provider.dart` para incluir comissões reais

**Arquivo:** `lib/features/reports/presentation/financial_provider.dart`

**Problema:** O `monthlyRevenueProvider` não traz `commission_value` dos `order_items`.

**Correção:** Expandir o select para incluir os `order_items` com `commission_value`:

```dart
// ANTES:
final response = await supabase
    .from('orders')
    .select('id, total, closed_at, client_name, payment_method, barbers(users(name))')
    .eq('unit_id', unitId)
    .eq('status', 'closed')
    .gte('closed_at', startOfMonth)
    .lte('closed_at', endOfMonth);

// DEPOIS:
final response = await supabase
    .from('orders')
    .select('id, total, closed_at, client_name, payment_method, barbers(id, commission_rate, users(name)), order_items(commission_value)')
    .eq('unit_id', unitId)
    .eq('status', 'closed')
    .gte('closed_at', startOfMonth)
    .lte('closed_at', endOfMonth);
```

---

#### PASSO 2.3 — Corrigir `financial_screen.dart` (KPI de comissões)

**Arquivo:** `lib/features/reports/presentation/financial_screen.dart`

**Problema:** Linha `double comissoes = faturamento * 0.40;` ignora comissões reais.

**Correção:** Calcule a comissão somando `commission_value` dos `order_items` de cada order:

```dart
// ANTES (ERRADO):
double comissoes = faturamento * 0.40; 

// DEPOIS (CORRETO):
double comissoes = 0.0;
if (revenueAsync.hasValue) {
  for (var order in revenueAsync.value!) {
    final items = order['order_items'] as List? ?? [];
    for (var item in items) {
      comissoes += (item['commission_value'] as num?)?.toDouble() ?? 0.0;
    }
  }
}
```

**Também corrigir o label do KPI card:**
```dart
// ANTES:
title: 'Comissões (40%)',

// DEPOIS:
title: 'Comissões (real)',
```

---

#### PASSO 2.4 — Corrigir `quick_report_screen.dart`

**Arquivo:** `lib/features/reports/presentation/quick_report_screen.dart`

**Problema:** `comissoesPorBarbeiro[barberName] = ... (total * 0.40)` — usa 40% fixo.

**Correção:** A query já traz `barbers(users(name))` mas não traz `commission_rate`. Adicione e use:

```dart
// Na query, adicione commission_rate:
final ordersResponse = await supabase
    .from('orders')
    .select('total, status, barbers(commission_rate, users(name))')
    .gte('start_time', startOfToday)
    .lte('start_time', endOfToday);

// No loop de cálculo, substitua:
// ANTES:
comissoesPorBarbeiro[barberName] =
    (comissoesPorBarbeiro[barberName] ?? 0) + (total * 0.40);

// DEPOIS:
final rate = (order['barbers']?['commission_rate'] as num?)?.toDouble() ?? 40.0;
comissoesPorBarbeiro[barberName] =
    (comissoesPorBarbeiro[barberName] ?? 0) + (total * (rate / 100));
```

---

#### PASSO 2.5 — Corrigir `order_items_provider.dart` (função `addOrderItem`)

**Arquivo:** `lib/features/orders/providers/order_items_provider.dart`

**Problema:** Parâmetro default `double commissionPct = 40.0` na função global `addOrderItem`.

**Ação:** O default de 40.0 pode ser mantido como fallback, mas quem chama a função deve sempre passar o valor correto do barbeiro. Verifique todos os call sites:

```bash
grep -rn "addOrderItem" lib/ --include=*.dart
```

Em `checkout_screen.dart`, `_addProduct` chama com `commissionPct: 0` (correto para produtos). `_addExtra` também usa `commissionPct: 0` (correto para avulsos). Esses estão OK.

O problema estava apenas no `create_appointment_screen.dart`, já corrigido no Passo 2.1.

---

### ⚠️ Armadilhas comuns
- ❌ Não remova o fallback `?? 40.0` em nenhum lugar — ele protege contra barbeiros sem `commission_rate` cadastrado.
- ❌ Não altere a tabela `order_items` nem `orders` no banco — os campos já existem.
- ⚠️ Após modificar `monthlyRevenueProvider`, valide que `financial_screen.dart` não quebra ao parsear a nova estrutura de dados (testar com `order_items` vazio = `[]`).

### ✅ Critérios de sucesso
- `create_appointment_screen` usa `barbers.commission_rate` ao criar order_items.
- `financial_screen` soma `commission_value` reais dos order_items.
- `quick_report_screen` usa `barbers.commission_rate` por atendimento.
- Fallback de 40% mantido em todos os locais como segurança.
- `flutter analyze` sem novos erros.

---

## FASE 3 — INVESTIGAÇÃO DO BUG DA AGENDA

### 🎯 Objetivo
Entender por que agendamentos passados não aparecem na agenda e identificar o filtro que precisa mudar.

### 🔍 O que investigar

**Arquivo principal:** `lib/features/orders/providers/appointments_provider.dart`

**Código atual (problema identificado):**
```dart
final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();

var query = supabase
    .from('orders')
    .select('id, start_time, end_time, client_name, client_id, status, total, barbers(id, users(name)), clients(id, name, is_vip)')
    .eq('unit_id', unitId)
    .gte('start_time', startOfToday); // ← AQUI ESTÁ O PROBLEMA
```

O `.gte('start_time', startOfToday)` bloqueia qualquer agendamento anterior a hoje.

**Impacto:**
- Barbeiro tem agendamento de ontem com status `open` → não consegue ver → não consegue fechar.
- Agendamentos passados abertos ficam "perdidos" no sistema.

**Arquivos adicionais a verificar:**
- `schedule_agenda_screen.dart` — tela que exibe a agenda visualmente (calendário)
- `schedule_screen.dart` — lista de ordens

Busque nesses arquivos por filtros adicionais de data que possam estar duplicando o problema:
```bash
grep -n "startOfToday\|gte\|DateTime.now\|start_time" lib/features/orders/presentation/ -r --include=*.dart
```

### ⚠️ Armadilhas comuns
- ❌ NÃO remova o filtro totalmente — sem nenhum filtro, a query pode trazer anos de dados e causar timeout ou lentidão.
- ❌ NÃO altere o RLS do Supabase — o filtro de unidade e barbeiro já está sendo feito corretamente.

### ✅ Critérios de sucesso
- Você identificou que o único filtro de data está em `appointments_provider.dart`.
- Você definiu a estratégia: filtrar por um período razoável (ex: 30 dias atrás) ao invés de bloquear tudo antes de hoje.

---

## FASE 4 — CORREÇÃO DO BUG DA AGENDA

### 🎯 Objetivo
Permitir que agendamentos anteriores (especialmente `status: open`) sejam visíveis e possam ser fechados.

### ⚙️ Ações passo a passo

---

#### PASSO 4.1 — Corrigir `appointments_provider.dart`

**Arquivo:** `lib/features/orders/providers/appointments_provider.dart`

**Estratégia:** Substituir o filtro de "hoje" por um filtro de "últimos 30 dias + todos os futuros". Isso garante performance e também permite visualizar agendamentos passados abertos.

```dart
// ANTES:
final now = DateTime.now();
final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();

var query = supabase
    .from('orders')
    .select('id, start_time, end_time, client_name, client_id, status, total, barbers(id, users(name)), clients(id, name, is_vip)')
    .eq('unit_id', unitId)
    .gte('start_time', startOfToday); // REMOVE ESTE FILTRO RESTRITIVO

// DEPOIS:
final now = DateTime.now();
// Permite ver 60 dias atrás (agendamentos abertos pendentes) + todos os futuros
final lookbackStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 60)).toIso8601String();

var query = supabase
    .from('orders')
    .select('id, start_time, end_time, client_name, client_id, status, total, barbers(id, users(name)), clients(id, name, is_vip)')
    .eq('unit_id', unitId)
    .gte('start_time', lookbackStart); // Janela de 60 dias atrás
```

> **Por que 60 dias?** É um período razoável que captura agendamentos abertos esquecidos sem trazer dados históricos excessivos. Ajuste conforme necessidade do cliente.

---

#### PASSO 4.2 — Verificar `schedule_agenda_screen.dart`

**Arquivo:** `lib/features/orders/presentation/schedule_agenda_screen.dart`

Verifique se a tela de agenda (visualização de calendário) tem alguma limitação de navegação para datas anteriores:

```bash
grep -n "DateTime\|selectedDate\|canGoBack\|isBefore\|isAfter" lib/features/orders/presentation/schedule_agenda_screen.dart
```

Se encontrar algo como `if (selectedDate.isBefore(DateTime.now()))` impedindo navegar para dias anteriores, remova ou ajuste essa restrição para permitir navegação até 60 dias atrás.

**Exemplo de correção caso exista:**
```dart
// ANTES (se existir):
onPressed: selectedDate.isAfter(DateTime.now()) ? null : () => _goToPreviousDay(),

// DEPOIS:
final minDate = DateTime.now().subtract(const Duration(days: 60));
onPressed: selectedDate.isAfter(minDate) ? () => _goToPreviousDay() : null,
```

---

#### PASSO 4.3 — Verificar `schedule_screen.dart`

Mesma verificação: busque filtros de data que bloqueiam visualização de dias anteriores.

```bash
grep -n "startOfToday\|gte\|DateTime.now" lib/features/orders/presentation/schedule_screen.dart
```

Se houver filtro igual ao do provider, ele estará sendo sobreposto pelo provider já corrigido. Apenas confirme que não há um filtro local na tela.

---

#### PASSO 4.4 — Garantir que agendamentos passados abertos possam ser fechados

O checkout (`checkout_screen.dart`) não tem nenhum filtro de data — ele opera sobre o appointment passado por parâmetro. Portanto, uma vez que o agendamento apareça na lista, ele **pode ser fechado normalmente**. Nenhuma alteração necessária no checkout para este bug.

---

### ⚠️ Armadilhas comuns
- ❌ NÃO use `startOfToday` como ponto de corte para a agenda — esse era exatamente o bug.
- ⚠️ Se a tela de agenda tiver paginação ou scroll infinito, valide que ela renderiza corretamente datas anteriores.
- ⚠️ O filtro por `barber_id` para barbeiros comuns (`if (!perm.isGlobalAdmin && userProfile['barber_id'] != null)`) deve ser **mantido** — ele é necessário para privacidade de dados.

### ✅ Critérios de sucesso
- Provider retorna agendamentos de até 60 dias atrás.
- Tela de agenda permite navegar para dias anteriores.
- Agendamento criado ontem com `status: open` aparece e pode ser fechado.
- Agendamentos futuros continuam aparecendo normalmente.

---

## FASE 5 — INVESTIGAÇÃO DO BOTÃO DE EXPORTAÇÃO

### 🎯 Objetivo
Entender por que o botão de exportar sumiu da tela financeira.

### 🔍 O que investigar

**Diagnóstico baseado no código analisado:**

O botão de exportação **existe** em `main_navigation.dart`, mas sua visibilidade depende de uma condição:

```dart
// Em main_navigation.dart, método _buildMobileLayout:
final isFinancialTab = perm.canAccessFinancial && _currentIndex == 3;

// O botão só aparece se isFinancialTab == true:
if (isFinancialTab)
  IconButton(
    icon: const Icon(Icons.file_download_outlined, color: Colors.grey),
    tooltip: 'Exportar relatório',
    onPressed: () => FinancialExportSheet.show(context),
  ),
```

**Causa do bug:**
- O índice `3` é hardcoded para a aba financeira.
- Se uma nova aba for adicionada ANTES do financeiro, ou se o financeiro for movido, `_currentIndex == 3` fica errado.
- Atualmente as abas são: `[0: Início, 1: Agenda, 2: Clientes, 3: Caixa (se permitido)]`
- Se `perm.canAccessFinancial` for `false`, a aba de Caixa **não é adicionada** — o índice 3 não existe, portanto `isFinancialTab` nunca é `true`.

**Verificar também:** O `DesktopShell` tem o botão de export?

```bash
grep -n "FinancialExportSheet\|file_download\|Exportar" lib/core/presentation/desktop_shell.dart
```

### ⚠️ Armadilhas comuns
- ❌ NÃO use índice hardcoded `== 3` para detectar a aba financeira — isso é frágil.
- ⚠️ Verifique se o problema está só no mobile ou também no desktop.

### ✅ Critérios de sucesso
- Você identificou que o bug é o índice hardcoded `_currentIndex == 3`.
- Você tem a estratégia de correção: usar o índice real da aba financeira calculado dinamicamente.

---

## FASE 6 — CORREÇÃO DO BOTÃO DE EXPORTAÇÃO

### 🎯 Objetivo
Fazer o botão de exportar aparecer de forma confiável quando o usuário está na aba Caixa/Financeiro.

### ⚙️ Ações passo a passo

---

#### PASSO 6.1 — Corrigir detecção da aba financeira em `main_navigation.dart`

**Arquivo:** `lib/core/presentation/main_navigation.dart`

**Problema:** `_currentIndex == 3` é frágil. O índice do financeiro depende de quantas abas foram adicionadas antes dele.

**Correção:** Rastrear o índice correto dinamicamente:

```dart
Widget _buildMobileLayout(Map<String, dynamic> user, AppPermissions perm) {
  final List<Widget> tabs = [];
  final List<BottomNavigationBarItem> navItems = [];

  // Aba 0: Início
  tabs.add(const HomeScreen());
  navItems.add(const BottomNavigationBarItem(
    icon: Icon(Icons.home_outlined), 
    activeIcon: Icon(Icons.home),
    label: 'Início'
  ));

  // Aba 1: Agenda
  tabs.add(const ScheduleAgendaScreen());
  navItems.add(const BottomNavigationBarItem(
    icon: Icon(Icons.calendar_today_outlined), 
    activeIcon: Icon(Icons.calendar_today),
    label: 'Agenda'
  ));

  // Aba 2: Clientes
  tabs.add(const ClientsScreen());
  navItems.add(const BottomNavigationBarItem(
    icon: Icon(Icons.people_outlined), 
    activeIcon: Icon(Icons.people),
    label: 'Clientes'
  ));

  // Aba financeira: rastrear o índice real
  int? financialTabIndex; // ← NOVO
  if (perm.canAccessFinancial) {
    financialTabIndex = tabs.length; // ← SALVA O ÍNDICE REAL
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

  // CORRIGIDO: usa o índice real, não hardcoded 3
  final isFinancialTab = financialTabIndex != null && _currentIndex == financialTabIndex;
  final isAgendaTab = _currentIndex == 1;

  // ... resto do build permanece igual
```

---

#### PASSO 6.2 — Verificar se o botão existe no `DesktopShell`

**Arquivo:** `lib/core/presentation/desktop_shell.dart`

```bash
grep -n "FinancialExportSheet\|file_download\|Exportar\|export" lib/core/presentation/desktop_shell.dart
```

Se o botão **não existir** no desktop, adicione-o na AppBar do `DesktopShell` dentro do contexto da aba financeira:

```dart
// Dentro do build do DesktopShell, na AppBar actions:
if (currentScreen is FinancialScreen)
  IconButton(
    icon: const Icon(Icons.file_download_outlined, color: Colors.grey),
    tooltip: 'Exportar relatório',
    onPressed: () => FinancialExportSheet.show(context),
  ),
```

> Se o `DesktopShell` não tem controle de qual tela está ativa desta forma, use uma variável de estado semelhante ao mobile.

---

#### PASSO 6.3 — Verificar import do `FinancialExportSheet` em `main_navigation.dart`

O import já existe (confirmado no código):
```dart
import '../../features/reports/presentation/widgets/financial_export_sheet.dart';
```

Nenhuma ação necessária aqui.

---

### ⚠️ Armadilhas comuns
- ❌ NÃO use `_currentIndex == 3` — já demonstrou ser bugado.
- ⚠️ Se futuras abas forem adicionadas entre Clientes e Caixa, o índice dinâmico funcionará automaticamente.
- ⚠️ Verifique que `FinancialExportSheet` continua importado após refatoração.

### ✅ Critérios de sucesso
- Usuário com `canAccessFinancial == true` vê o botão de exportar ao abrir a aba Caixa.
- Usuário sem permissão financeira não vê o botão (a aba não existe para ele).
- `FinancialExportSheet.show(context)` abre o modal de exportação corretamente.
- Export de PDF/Excel/CSV funciona do início ao fim.

---

## FASE 7 — VALIDAÇÃO FINAL

### 🎯 Objetivo
Confirmar que todos os 3 bugs foram corrigidos sem quebrar funcionalidades existentes.

### ⚙️ Ações passo a passo

#### 7.1 — Rodar análise estática
```bash
flutter analyze
```
Não deve haver novos erros ou warnings além dos que existiam antes.

#### 7.2 — Testar Bug 1: Comissão

**Cenário A — Barbeiro com commission_rate diferente de 40%:**
1. No Supabase, localize um barbeiro na tabela `barbers`.
2. Atualize `commission_rate` para `30` (ex: João tem 30%).
3. No app, faça login como João (ou como líder e selecione João).
4. Crie um agendamento com um serviço de R$ 100,00.
5. Feche o agendamento via checkout.
6. Acesse a tela Caixa/Financeiro.
7. **Esperado:** A comissão mostrada deve ser R$ 30,00 (não R$ 40,00).

**Cenário B — Verificar Relatório Rápido:**
1. Acesse o Relatório Rápido.
2. **Esperado:** Comissão por barbeiro deve refletir a taxa individual de cada um.

**Cenário C — Barbeiro sem commission_rate cadastrado:**
1. No Supabase, defina `commission_rate = NULL` para um barbeiro de teste.
2. Crie um atendimento para esse barbeiro.
3. **Esperado:** Sistema usa 40% como fallback — sem crash.

---

#### 7.3 — Testar Bug 2: Agenda

**Cenário A — Ver agendamento de ontem:**
1. No Supabase, localize ou crie um `order` com `start_time` = ontem e `status = 'open'`.
2. Abra o app na aba Agenda.
3. Navegue para ontem no calendário.
4. **Esperado:** O agendamento aparece.

**Cenário B — Fechar agendamento passado:**
1. Tap no agendamento de ontem (status open).
2. Abra o checkout.
3. Selecione forma de pagamento e confirme.
4. **Esperado:** Status muda para `closed`, sem erro.

**Cenário C — Agendamentos futuros não foram afetados:**
1. Vá para amanhã na agenda.
2. **Esperado:** Agendamentos futuros continuam aparecendo normalmente.

---

#### 7.4 — Testar Bug 3: Botão de Exportação

**Cenário A — Usuário líder/admin vê o botão:**
1. Faça login como Barbeiro Líder ou admin.
2. Vá para a aba Caixa.
3. **Esperado:** Ícone de download aparece na AppBar.
4. Tap no ícone.
5. **Esperado:** Modal de exportação abre com opções PDF, Excel, CSV.

**Cenário B — Exportar PDF:**
1. No modal, selecione PDF e "Últimos 7 dias".
2. Tap "Gerar e Exportar".
3. **Esperado:** PDF gerado e compartilhado/baixado sem erro.

**Cenário C — Usuário barbeiro comum:**
1. Faça login como barbeiro comum (sem `canAccessFinancial`).
2. **Esperado:** Aba Caixa não aparece → botão de export não aparece. Correto.

---

## FASE 8 — GARANTIA DE NÃO REGRESSÃO

### 🎯 Objetivo
Garantir que as correções não quebraram nenhuma funcionalidade existente.

### ⚙️ Ações passo a passo

#### 8.1 — Testar fluxo completo de agendamento
1. Criar agendamento novo → confirmar.
2. Abrir checkout → adicionar produto → adicionar extra.
3. Aplicar desconto.
4. Fechar com forma de pagamento.
5. Verificar na aba Caixa que o atendimento aparece.

#### 8.2 — Testar permissões RBAC
1. Login como barbeiro comum: não deve ver Caixa.
2. Login como líder: deve ver Caixa + botão export.
3. Login como admin global: deve ver tudo.

#### 8.3 — Testar multi-unidade (se aplicável)
1. Trocar de unidade via `UnitSelectorWidget`.
2. Agenda deve mostrar apenas agendamentos da unidade selecionada.
3. Financeiro deve mostrar apenas dados da unidade selecionada.

#### 8.4 — Rodar testes automatizados
```bash
flutter test
```
Todos os testes devem passar. Se algum falhar por causa das mudanças, atualize o teste para refletir o novo comportamento correto.

---

## 🔥 CHECKLIST DE VALIDAÇÃO FINAL

```
COMISSÃO
[ ] Barbeiro com commission_rate=30% → order_item gravado com commission_pct=30
[ ] financial_screen soma commission_value real (não 40% fixo)
[ ] quick_report_screen usa commission_rate do barbeiro
[ ] Fallback 40% funciona quando commission_rate é NULL
[ ] Label "Comissões (40%)" removido/atualizado

AGENDA
[ ] Agendamentos de ontem aparecem na tela de agenda
[ ] Agendamentos de 30+ dias atrás (status open) aparecem
[ ] Agendamento antigo pode ser aberto no checkout
[ ] Agendamento antigo pode ser fechado com pagamento
[ ] Agendamentos futuros continuam aparecendo
[ ] Filtro por unidade mantido
[ ] Filtro por barber_id (barbeiro comum) mantido

EXPORTAÇÃO
[ ] Botão export aparece quando usuário está na aba Caixa
[ ] Botão export não aparece para barbeiro comum (sem acesso ao Caixa)
[ ] Modal FinancialExportSheet abre corretamente
[ ] Export PDF funciona (sem crash)
[ ] Export Excel funciona
[ ] Export CSV funciona
[ ] Período "Últimos 7 dias" funciona
[ ] Período "Mês atual" funciona
[ ] Período "Personalizado" funciona

NÃO REGRESSÃO
[ ] flutter analyze sem novos erros
[ ] Criar agendamento novo funciona
[ ] Checkout com produto funciona
[ ] Checkout com extra funciona
[ ] Desconto aplicado corretamente
[ ] Multi-unidade: dados isolados por unidade
[ ] Login/logout sem problemas
[ ] Tela de Clientes funciona
[ ] Tela de Equipe funciona
```

---

## 🧪 TESTES SUGERIDOS

### Teste 1: Comissão diferente de 40%
```sql
-- No Supabase SQL Editor, antes do teste:
UPDATE barbers SET commission_rate = 25 WHERE id = '<ID_DO_BARBEIRO_TESTE>';

-- Após criar e fechar um atendimento de R$ 80:
SELECT commission_pct, commission_value FROM order_items 
WHERE order_id = '<ID_DA_ORDER_CRIADA>';
-- Esperado: commission_pct = 25, commission_value = 20 (80 * 0.25)
```

### Teste 2: Agendamento passado aberto
```sql
-- Criar agendamento de 3 dias atrás para teste:
INSERT INTO orders (unit_id, barber_id, client_name, start_time, end_time, total, status)
VALUES (
  '<UNIT_ID>',
  '<BARBER_ID>',
  'Teste Passado',
  NOW() - INTERVAL '3 days',
  NOW() - INTERVAL '3 days' + INTERVAL '1 hour',
  50.00,
  'open'
);
-- Abrir app → ir para a data de 3 dias atrás → confirmar que aparece → fechar pelo checkout
```

### Teste 3: Exportação com dados reais
1. Navegar para aba Caixa com pelo menos 1 atendimento fechado no mês.
2. Tap no botão de export.
3. Selecionar PDF + "Mês atual" + relatório detalhado.
4. Confirmar que o PDF gerado:
   - Tem o nome da unidade correto.
   - Lista os atendimentos do mês.
   - Mostra total de receitas e despesas.
   - Não tem caracteres estranhos (encoding OK).

### Teste 4: Fallback de comissão (segurança)
```sql
-- Barbeiro sem commission_rate:
UPDATE barbers SET commission_rate = NULL WHERE id = '<ID_DO_BARBEIRO_TESTE>';
-- Criar atendimento → order_item deve usar 40% como fallback → sem crash
```

---

## REFERÊNCIA RÁPIDA DE ARQUIVOS

```
lib/
├── core/
│   ├── presentation/
│   │   └── main_navigation.dart          ← Bug 3: índice financialTabIndex
│   └── rbac/
│       └── app_permissions.dart          ← Permissões (não alterar)
└── features/
    ├── orders/
    │   ├── presentation/
    │   │   ├── checkout_screen.dart      ← Sem alterações necessárias
    │   │   ├── create_appointment_screen.dart ← Bug 1: buscar commission_rate do barbeiro
    │   │   └── schedule_agenda_screen.dart ← Bug 2: verificar filtros de navegação de datas
    │   └── providers/
    │       ├── appointments_provider.dart ← Bug 2: remover .gte(startOfToday)
    │       └── order_items_provider.dart  ← Bug 1: parâmetro default mantido como fallback
    └── reports/
        └── presentation/
            ├── financial_provider.dart    ← Bug 1: expandir select com order_items
            ├── financial_screen.dart      ← Bug 1: calcular comissão real; Bug 3: sem alteração de exibição
            ├── quick_report_screen.dart   ← Bug 1: usar commission_rate por barbeiro
            └── widgets/
                └── financial_export_sheet.dart ← Sem alterações (funcional)
```

---

*Fim do PLANO_CORRECAO_BARBEROS.md — Gerado por análise do Repomix do projeto BarberOS.*
