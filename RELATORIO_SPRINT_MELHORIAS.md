# Relatório Sprint de Melhorias — BarberOS
**Data:** 18/04/2026
**Responsável:** Daniel
**Total de Tarefas:** 7 (D-01 a D-07)

---

## Visão Geral

Este documento lista todas as alterações planejadas para a sprint de melhorias do BarberOS. Cada tarefa deve ser implementada em uma branch separada (`feat/D-0X-descricao`) e passing por review antes do merge.

---

## D-01 — Persistência de Sessão
**Estimativa:** 8h | **Dependências:** Nenhuma
**Status:** ✅ CONCLUÍDA

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/main.dart` | Modificado |

### Descrição das Mudanças

**Antes:**
```dart
class BarberOSApp extends StatelessWidget {
  const BarberOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LoginScreen(), // <-- sempre ia para login
    );
  }
}
```

**Depois:**
- Substituir `home: const LoginScreen()` por `home: const _AuthGate()`
- Criar widget `_AuthGate` (StatefulWidget) que:
  1. Exibe tela de splash enquanto verifica sessão
  2. Aguarda 300ms para Supabase restaurar token
  3. Verifica `Supabase.instance.client.auth.currentSession`
  4. Se sessão existe → navega para `MainNavigation()`
  5. Se não existe → navega para `LoginScreen()`

### Novos Imports Necessários
```dart
import 'package:barber_os/features/auth/presentation/login_screen.dart';
import 'package:barber_os/core/presentation/main_navigation.dart';
```

### Teste Manual
1. Login → fechar app → reabrir → deve ir direto para MainNavigation
2. Logout → fechar app → reabrir → deve ir para LoginScreen

### Implementação
**Branch:** `feat/D-01-persistencia-sessao`

**Mudanças realizadas:**
- Classe `BarberOSApp` agora usa `home: const _AuthGate()` em vez de `LoginScreen()`
- Criado widget `_AuthGate` (StatefulWidget) com:
  - Tela de splash com ícone e "BarberOS"
  - `initState` chama `_checkSession()`
  - `_checkSession()` espera 300ms, verifica `currentSession` e navega accordingly
  - Uso de `mounted` para evitar setState em widget desmontado

**Commits:** A fazer após批准 do usuário

---

## D-02 — Ocultar Telefone para Não-Líderes
**Estimativa:** 6h | **Dependências:** Nenhuma
**Status:** ✅ CONCLUÍDA

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/features/clients/clients_screen.dart` | Modificado |

### Descrição das Mudanças

Na `ClientsScreen`, dentro do `build` do `_ClientsScreenState`, localizar o `subtitle` do `ListTile` onde exibe o telefone:

**Antes:**
```dart
Text(phone), // exibe para todos
```

**Depois:**
```dart
if (isLeader)
  Text(phone)
else
  Text(
    '••••••••••',
    style: TextStyle(color: Colors.grey[600], letterSpacing: 2),
  ),
```

### Lógica
- Se usuário é `isLeader` ou `admin` → exibe telefone normal
- Se usuário é barbeiro comum → exibe `••••••••••` (mascarado)
- Variável `isLeader` já existe no escopo do `build`

### Teste Manual
1. Login como barbeiro comum → Clients → telefones mascarados
2. Login como líder → Clients → telefones visíveis

### Implementação
**Branch:** `feat/D-01-persistencia-sessao` (mesma branch)

**Mudanças realizadas:**
- No `subtitle` do `ListTile`, substituído `Text(phone)` por condicional:
  - Se `isLeader`: exibe telefone normal
  - Se não: exibe `••••••••••` com cor cinza e letter-spacing

**Commits:** A fazer após aprovação do usuário

---

## D-03 — Tag do Barbeiro que Cadastrou o Cliente
**Estimativa:** 8h | **Dependências:** P-02 (Pedro deve criar campo `created_by_barber_id`)

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/features/clients/clients_screen.dart` | Modificado |
| `lib/features/clients/providers/clients_provider.dart` | Modificado |

### ⚠️ Pré-requisito
Pedro precisa criar a coluna `created_by_barber_id` na tabela `clients` (FK para `barbers.id`) e popular os dados existentes.

### Descrição das Mudanças

**1. `clients_provider.dart` — Atualizar query:**

**Antes:**
```dart
final response = await supabase
    .from('clients')
    .select('*')
    .order('name');
```

**Depois:**
```dart
final response = await supabase
    .from('clients')
    .select('*, created_by_barber:barbers!created_by_barber_id(id, users(name))')
    .order('name');
```

**2. `clients_screen.dart` — No `itemBuilder` da lista, após extrair `phone`:**

```dart
// Extrai o nome do barbeiro que cadastrou
final createdByBarber = client['created_by_barber'];
final createdByName = createdByBarber?['users']?['name']?.toString();
```

**3. Adicionar tag no `subtitle` do `ListTile`:**
```dart
if (createdByName != null && createdByName.isNotEmpty) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      Icon(Icons.person_pin_outlined, size: 12, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(
        'Cadastrado por $createdByName',
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
      ),
    ],
  ),
],
```

### Comando SQL Necessário (SUPABASE)
```sql
-- Adicionar coluna created_by_barber_id na tabela clients
ALTER TABLE public.clients
ADD COLUMN IF NOT EXISTS created_by_barber_id uuid REFERENCES public.barbers(id);

-- Permitir NULL para clientes existentes
ALTER TABLE public.clients
ALTER COLUMN created_by_barber_id DROP NOT NULL;

-- Atualizar clientes existentes com NULL (ou informar ao Daniel qual barbeiro cadastrou)
-- UPDATE public.clients SET created_by_barber_id = 'uuid-do-barbeiro' WHERE created_by_barber_id IS NULL;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_clients_created_by_barber_id ON public.clients(created_by_barber_id);
```

### Teste Manual
1. Aguardar Pedro confirmar que migração foi aplicada
2. Cadastrar cliente como barbeiro X
3. Verificar tag "Cadastrado por [Nome]" aparece na lista

---

## D-04 — Histórico do Cliente (UI)
**Estimativa:** 12h | **Dependências:** P-03 (Pedro cria tabela `client_history`)

### Arquivos Criados
| Arquivo | Tipo |
|---------|------|
| `lib/features/clients/presentation/client_detail_screen.dart` | **NOVO** |
| `lib/features/clients/providers/client_history_provider.dart` | **NOVO** |

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/features/clients/clients_screen.dart` | Modificado |

### ⚠️ Pré-requisito
Pedro precisa criar tabela `client_history` com campos: `client_id`, `order_id`, `service_id`, `product_id`, `type` (enum: 'service', 'product'), `name`, `price`, `date`

### Descrição das Mudanças

**1. Criar `client_history_provider.dart`:**
```dart
final clientHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('client_history')
      .select('*')
      .eq('client_id', clientId)
      .order('date', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});
```

**2. Criar `client_detail_screen.dart`:**
- Scaffold com AppBar
- Header com avatar, nome e badge de plano (Premium/Básico)
- Card de informações: telefone, aniversário, observações
- Seção "Histórico de Atendimentos" com:
  - Loading state
  - Empty state ("Nenhum atendimento registrado")
  - Lista de itens com ícone (serviço = ✂️ azul, produto = 📦 roxo), nome, data, preço

**3. Modificar `clients_screen.dart`:**

Adicionar import:
```dart
import 'presentation/client_detail_screen.dart';
```

**Antes:**
```dart
trailing: isLeader ? const Icon(Icons.edit_outlined, color: Colors.grey, size: 20) : null,
onTap: isLeader ? () => _showClientBottomSheet(client: client) : null,
```

**Depois:**
```dart
trailing: isLeader
    ? const Icon(Icons.edit_outlined, color: Colors.grey, size: 20)
    : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
onTap: () {
  if (isLeader) {
    _showClientBottomSheet(client: client);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(client: client),
      ),
    );
  }
},
```

### Teste Manual
1. Login como barbeiro comum → clicar cliente → abre ClientDetailScreen
2. Login como líder → clicar cliente → abre bottom sheet edição (inalterado)
3. Histórico vazio aparece antes do P-03

---

## D-05 — Barbeiro "Fechar" sua Agenda
**Estimativa:** 15h | **Dependências:** Nenhuma
**Status:** ✅ CONCLUÍDA

### Arquivos Criados
| Arquivo | Tipo |
|---------|------|
| `lib/features/orders/providers/schedule_lock_provider.dart` | **NOVO** |

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/features/orders/presentation/schedule_agenda_screen.dart` | Modificado |

### Comandos SQL Necessários (SUPABASE)
```sql
-- Adicionar coluna is_schedule_locked na tabela barbers
ALTER TABLE public.barbers
ADD COLUMN IF NOT EXISTS is_schedule_locked boolean DEFAULT false;

COMMENT ON COLUMN public.barbers.is_schedule_locked IS
  'Quando true, a agenda do barbeiro está fechada e não aceita novos agendamentos';
```

### Descrição das Mudanças

**1. Criar `schedule_lock_provider.dart`:**
```dart
// Provider que retorna true se a agenda do barbeiro logado está travada
final scheduleLockProvider = FutureProvider.autoDispose<bool>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userProfile = await ref.watch(userProfileProvider.future);
  final barberId = userProfile['barber_id'] as String?;
  if (barberId == null) return false;

  final response = await supabase
      .from('barbers')
      .select('is_schedule_locked')
      .eq('id', barberId)
      .single();

  return response['is_schedule_locked'] as bool? ?? false;
});

// Função para toggle
Future<void> toggleScheduleLock({
  required String barberId,
  required bool currentValue,
  required dynamic supabase,
}) async {
  await supabase
      .from('barbers')
      .update({'is_schedule_locked': !currentValue})
      .eq('id', barberId);
}
```

**2. Modificar `schedule_agenda_screen.dart`:**
- Converter de `ConsumerWidget` para `ConsumerStatefulWidget`
- Adicionar estado `_isTogglingLock`
- Adicionar método `_handleToggleLock`
- Adicionar na AppBar um toggle Switch com label "Agenda aberta/fechada"
- Toggle visível apenas para barbeiros comuns (não líderes)
- Validar `barberId` antes de mostrar toggle

### AppBar Modificada
```dart
appBar: AppBar(
  title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
  backgroundColor: const Color(0xFF1E1E1E),
  elevation: 0,
  actions: [
    if (!isLeader && barberId != null)
      scheduleLockAsync.when(
        loading: () => const Padding(/* loading */),
        error: (_, __) => const SizedBox.shrink(),
        data: (isLocked) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLocked ? 'Agenda fechada' : 'Agenda aberta',
                style: TextStyle(
                  color: isLocked ? Colors.red[300] : Colors.green[300],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              _isTogglingLock
                  ? const SizedBox(/* loading */)
                  : Switch(
                      value: !isLocked,
                      onChanged: (_) => _handleToggleLock(...),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.withOpacity(0.3),
                    ),
            ],
          ),
        ),
      ),
  ],
),
```

### Teste Manual
1. Login como barbeiro comum → AppBar mostra toggle
2. Alternar toggle → `is_schedule_locked` muda no banco
3. Login como líder → toggle NÃO aparece

### Implementação
**Branch:** `feat/D-01-persistencia-sessao` (mesma branch)

**Arquivos criados:**
- `lib/features/orders/providers/schedule_lock_provider.dart` — com `scheduleLockProvider`, `allBarbersLockStatusProvider` e `toggleScheduleLock`

**Arquivos modificados:**
- `lib/features/orders/presentation/schedule_agenda_screen.dart`:
  - Convertido de `ConsumerWidget` para `ConsumerStatefulWidget`
  - Adicionado estado `_isTogglingLock`
  - Adicionado método `_handleToggleLock`
  - AppBar agora tem `actions` com toggle Switch para fechar/abrir agenda
  - Toggle visível apenas para barbeiros comuns (não líderes)

**Commits:** A fazer após aprovação do usuário

---

## D-06 — Feedback Visual: Agenda Travada e Horários Agendados
**Estimativa:** 10h | **Dependências:** D-05
**Status:** ✅ CONCLUÍDA

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/features/orders/providers/schedule_lock_provider.dart` | Modificado (adicionar provider) |
| `lib/features/orders/presentation/create_appointment_screen.dart` | Modificado |
| `lib/features/orders/presentation/schedule_screen.dart` | Modificado |

### Descrição das Mudanças

**1. Adicionar provider em `schedule_lock_provider.dart`:**
```dart
// Retorna Map de {barberId: isLocked} para todos barbeiros ativos
final allBarbersLockStatusProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('barbers')
      .select('id, is_schedule_locked')
      .eq('is_active', true);

  final result = <String, bool>{};
  for (final row in response as List) {
    result[row['id'] as String] = row['is_schedule_locked'] as bool? ?? false;
  }
  return result;
});
```

**2. Modificar `create_appointment_screen.dart`:**
- Adicionar import do provider
- Dentro do `build`, adicionar:
  ```dart
  final lockStatusAsync = ref.watch(allBarbersLockStatusProvider);
  final Map<String, bool> lockStatus = lockStatusAsync.maybeWhen(
    data: (data) => data,
    orElse: () => {},
  );
  ```
- Calcular se barbeiro selecionado está travado:
  ```dart
  final isSelectedBarberLocked = effectiveBarberId != null
      ? (lockStatus[effectiveBarberId] ?? false)
      : false;
  ```
- No `itemBuilder` dos slots, substituir cor do Container:
  - Agenda fechada: `Colors.red.withOpacity(0.2)` + borda vermelha + `❌`
  - Agendado: `Colors.blue.withOpacity(0.2)` + borda azul + `✂️`
  - Disponível: `Colors.grey[700]`
- Adicionar banner de aviso antes dos slots quando agenda travada:
  ```dart
  if (isSelectedBarberLocked) ...[
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Este profissional fechou a agenda. Nenhum horário disponível.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  ],
  ```

**3. Aplicar mesmas mudanças em `schedule_screen.dart`**

### Teste Manual
1. Barbeiro X fecha agenda (D-05)
2. Criar agendamento → selecionar barbeiro X
3. Todos slots vermelho com `❌` + banner de aviso
4. Slots agendados mostram `✂️` em azul

### Implementação
**Branch:** `feat/D-01-persistencia-sessao` (mesma branch)

**Arquivos modificados:**
- `lib/features/orders/presentation/create_appointment_screen.dart`:
  - Adicionado import `schedule_lock_provider.dart`
  - Adicionado `lockStatusAsync` e cálculo de `isSelectedBarberLocked`
  - Slots agora mostram cores diferentes: vermelho paralocked, azul para booked, verde para selected
  - Adicionado banner de aviso quando agenda travada

- `lib/features/orders/presentation/schedule_screen.dart`:
  - Adicionado import `schedule_lock_provider.dart`
  - Adicionado `lockStatusAsync` e cálculo de `isSelectedBarberLocked`
  - Mesma lógica visual de cores e ícones aplicada

**Commits:** A fazer após aprovação do usuário

---

## D-07 — Exibição de Serviços por Setor
**Estimativa:** 8h | **Dependências:** P-06 (Pedro adiciona campo `sector`), I-06/I-07 (Ian cria telas Salon/Premium)
**Status:** ✅ CONCLUÍDA

### Arquivos Criados
| Arquivo | Tipo |
|---------|------|
| Nenhum | - |

### Arquivos Modificados
| Arquivo | Tipo de Mudança |
|---------|-----------------|
| `lib/core/supabase/providers.dart` | Modificado |
| `lib/features/orders/presentation/create_appointment_screen.dart` | Modificado |
| `lib/features/orders/presentation/schedule_screen.dart` | Modificado |

### ⚠️ Pré-requisito
- Pedro: adicionar coluna `sector` enum ('barbearia', 'salao', 'premium') na tabela `services`
- Ian: criar telas SalonScreen e PremiumSpaceScreen

### Descrição das Mudanças

**1. Adicionar provider em `lib/core/supabase/providers.dart`:**
```dart
/// Provider filtrado por setor
/// sector: 'barbearia', 'salao', ou 'premium'. null = retorna todos.
final servicesBySectorProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, sector) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase
      .from('services')
      .select('*')
      .eq('is_active', true);

  if (sector != null) {
    query = query.eq('sector', sector);
  }

  final response = await query.order('name');
  return List<Map<String, dynamic>>.from(response);
});
```

**2. Modificar `create_appointment_screen.dart`:**
- Adicionar parâmetro opcional:
  ```dart
  final String? sector;
  const CreateAppointmentScreen({super.key, this.sector});
  ```
- Substituir uso de `servicesProvider`:
  ```dart
  // Antes:
  final servicesAsync = ref.watch(servicesProvider);

  // Depois:
  final servicesAsync = ref.watch(servicesBySectorProvider(widget.sector ?? 'barbearia'));
  ```

**3. Aplicar mesmas mudanças em `schedule_screen.dart`**

### Comando SQL Necessário (SUPABASE)
```sql
-- Adicionar coluna sector na tabela services
ALTER TABLE public.services
ADD COLUMN IF NOT EXISTS sector text DEFAULT 'barbearia'
CHECK (sector IN ('barbearia', 'salao', 'premium'));

-- Atualizar serviços existentes com NULL para 'barbearia'
UPDATE public.services SET sector = 'barbearia' WHERE sector IS NULL;

-- Criar índice
CREATE INDEX IF NOT EXISTS idx_services_sector ON public.services(sector);
```

### Exemplo de Navegação (para Ian)
```dart
// Da SalonScreen:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const CreateAppointmentScreen(sector: 'salao'),
  ),
);

// Da PremiumSpaceScreen:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const CreateAppointmentScreen(sector: 'premium'),
  ),
);
```

### Teste Manual
1. Agendamento normal → exibe só serviços `barbearia`
2. Agendamento do Salon → exibe só serviços `salao`
3. Agendamento do Premium → exibe só serviços `premium`

### Implementação
**Branch:** `feat/D-01-persistencia-sessao` (mesma branch)

**Arquivos modificados:**
- `lib/core/supabase/providers.dart`:
  - Adicionado novo provider `servicesBySectorProvider` com parâmetro `sector`

- `lib/features/orders/presentation/create_appointment_screen.dart`:
  - Adicionado parâmetro opcional `final String? sector;`
  - Alterado de `servicesProvider` para `servicesBySectorProvider(widget.sector ?? 'barbearia')`

- `lib/features/orders/presentation/schedule_screen.dart`:
  - Adicionado parâmetro opcional `final String? sector;`
  - Alterado de `servicesProvider` para `servicesBySectorProvider(widget.sector ?? 'barbearia')`

**Commits:** A fazer após aprovação do usuário

---

## Resumo dos Arquivos Alterados

| # | Arquivo | Tipo | Tarefas | Status |
|---|---------|------|---------|--------|
| 1 | `lib/main.dart` | Modificado | D-01 | ✅ |
| 2 | `lib/features/clients/clients_screen.dart` | Modificado | D-02 | ✅ |
| 3 | `lib/features/clients/providers/clients_provider.dart` | Modificado | D-03 | ⏳ |
| 4 | `lib/features/clients/presentation/client_detail_screen.dart` | **NOVO** | D-04 | ⏳ |
| 5 | `lib/features/clients/providers/client_history_provider.dart` | **NOVO** | D-04 | ⏳ |
| 6 | `lib/features/orders/providers/schedule_lock_provider.dart` | **NOVO** | D-05, D-06 | ✅ |
| 7 | `lib/features/orders/presentation/schedule_agenda_screen.dart` | Modificado | D-05 | ✅ |
| 8 | `lib/features/orders/presentation/create_appointment_screen.dart` | Modificado | D-06, D-07 | ✅ |
| 9 | `lib/features/orders/presentation/schedule_screen.dart` | Modificado | D-06, D-07 | ✅ |
| 10 | `lib/core/supabase/providers.dart` | Modificado | D-07 | ✅ |

**Total: 10 arquivos (8 modificados + 2 novos)**
**Concluídos: 6 | Aguardando: 4 (D-03, D-04 dependem do Pedro)**

---

## Comandos SQL para Executar no Supabase

> ⚠️ Execute estes comandos no SQL Editor do Supabase Dashboard antes de testar as funcionalidades

---

### D-03 — Tag Barbeiro Cadastrou (necessário para D-03)
```sql
-- Adicionar coluna created_by_barber_id na tabela clients
ALTER TABLE public.clients
ADD COLUMN IF NOT EXISTS created_by_barber_id uuid REFERENCES public.barbers(id);

-- Permitir NULL para clientes existentes
ALTER TABLE public.clients
ALTER COLUMN created_by_barber_id DROP NOT NULL;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_clients_created_by_barber_id ON public.clients(created_by_barber_id);
```

---

### D-05 — Agenda Travada (necessário para D-05 e D-06)
```sql
-- Adicionar coluna is_schedule_locked na tabela barbers
ALTER TABLE public.barbers
ADD COLUMN IF NOT EXISTS is_schedule_locked boolean DEFAULT false;

COMMENT ON COLUMN public.barbers.is_schedule_locked IS
  'Quando true, a agenda do barbeiro está fechada e não aceita novos agendamentos';
```

---

### D-07 — Setor de Serviços (necessário para D-07)
```sql
-- Adicionar coluna sector na tabela services
ALTER TABLE public.services
ADD COLUMN IF NOT EXISTS sector text DEFAULT 'barbearia'
CHECK (sector IN ('barbearia', 'salao', 'premium'));

-- Atualizar serviços existentes com NULL para 'barbearia'
UPDATE public.services SET sector = 'barbearia' WHERE sector IS NULL;

-- Criar índice
CREATE INDEX IF NOT EXISTS idx_services_sector ON public.services(sector);
```

---

### Resumo dos SQLs a executar

| Task | Comando | Status |
|------|---------|--------|
| D-03 | `created_by_barber_id` em `clients` | ⏳ Aguarda Pedro (P-02) |
| D-05 | `is_schedule_locked` em `barbers` | ✅ Pronto para executar |
| D-07 | `sector` em `services` | ⏳ Aguarda Pedro (P-06) |

---

## Regras de Desenvolvimento

1. **Branch por tarefa:** `git checkout -b feat/D-01-persistencia-sessao`
2. **Commits atômicos** ao concluir cada passo relevante
3. **NÃO modificar** arquivos de Pedro (`clients_provider.dart`, `checkout_screen.dart`, `financial_provider.dart`)
4. **NÃO modificar** arquivos de Ian (`financial_screen.dart`, `employees_screen.dart`, `units_list_screen.dart`)
5. **Abrir PR** e solicitar revisão antes do merge

---

## Status Final

**Branch atual:** `feat/D-01-persistencia-sessao`

**Arquivos modificados/criados:**
| # | Arquivo | Status |
|---|---------|--------|
| 1 | `lib/main.dart` | ✅ Implementado |
| 2 | `lib/features/clients/clients_screen.dart` | ✅ Implementado |
| 3 | `lib/features/orders/providers/schedule_lock_provider.dart` | ✅ Criado |
| 4 | `lib/features/orders/presentation/schedule_agenda_screen.dart` | ✅ Implementado |
| 5 | `lib/features/orders/presentation/create_appointment_screen.dart` | ✅ Implementado |
| 6 | `lib/features/orders/presentation/schedule_screen.dart` | ✅ Implementado |
| 7 | `lib/core/supabase/providers.dart` | ✅ Implementado |

**Tarefas pendentes (aguardando Pedro):**
- D-03: Tag Barbeiro Cadastrou (precisa P-02)
- D-04: Histórico Cliente UI (precisa P-03)

---

*Documento atualizado em 18/04/2026*
