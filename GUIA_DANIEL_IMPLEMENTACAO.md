# 📋 Guia de Implementação — Daniel
### Projeto BarberOS | Foco: Funcionalidades Específicas, Ajustes e Otimizações

> **Importante antes de começar:**
> - Crie uma branch separada para cada task: `git checkout -b feat/D-01-persistencia-sessao`
> - Faça commits atômicos ao concluir cada passo relevante
> - Nunca altere arquivos das áreas do Pedro (`clients_provider.dart`, `checkout_screen.dart`, `financial_provider.dart`) ou do Ian (`financial_screen.dart`, `employees_screen.dart`, `units_list_screen.dart`) — mesmo que você precise ler esses arquivos para entender o contexto
> - Abra Pull Request e solicite revisão de pelo menos um colega antes do merge

---

## Índice

- [D-01 — Persistência de Sessão](#d-01--persistência-de-sessão)
- [D-02 — Ocultar Telefone para Não-Líderes](#d-02--ocultar-telefone-para-não-líderes)
- [D-03 — Tag do Barbeiro que Cadastrou o Cliente](#d-03--tag-do-barbeiro-que-cadastrou-o-cliente)
- [D-04 — Histórico do Cliente (UI)](#d-04--histórico-do-cliente-ui)
- [D-05 — Barbeiro Fechar a Agenda](#d-05--barbeiro-fechar-a-agenda)
- [D-06 — Feedback Visual: Agenda Travada e Horários Agendados](#d-06--feedback-visual-agenda-travada-e-horários-agendados)
- [D-07 — Exibição de Serviços por Setor](#d-07--exibição-de-serviços-por-setor)

---

## D-01 — Persistência de Sessão

**Estimativa:** 8h | **Dependências:** Nenhuma

### Contexto do Problema

Atualmente o `main.dart` define `home: const LoginScreen()`, ou seja, toda vez que o app é aberto o usuário é mandado para a tela de login — mesmo que já estivesse logado. O Supabase Flutter **já persiste o token de sessão** automaticamente no dispositivo, mas o app nunca verifica essa sessão ao inicializar.

### Arquivos que você vai modificar

- `lib/main.dart`

### Passo a Passo

**Passo 1 — Criar um widget de splash/roteamento inicial**

Substitua o `home: const LoginScreen()` por um widget que verifica se já existe uma sessão ativa antes de decidir para onde navegar.

Abra `lib/main.dart` e substitua a classe `BarberOSApp` pelo código abaixo:

```dart
class BarberOSApp extends StatelessWidget {
  const BarberOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AuthGate(), // <-- mudança aqui
    );
  }
}

/// Widget que decide se o usuário vai para Login ou para o app principal
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Pequeno delay para garantir que o Supabase terminou de restaurar a sessão
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Sessão válida → vai direto para o app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      // Sem sessão → vai para login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela de splash enquanto verifica a sessão
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cut_rounded, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'BarberOS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
```

**Passo 2 — Adicionar os imports necessários no topo do `main.dart`**

Certifique-se de que estes imports existem no arquivo:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_os/features/auth/presentation/login_screen.dart';
import 'package:barber_os/core/presentation/main_navigation.dart';
import 'package:barber_os/core/theme/app_theme.dart';
```

**Passo 3 — Verificar o comportamento do logout**

O logout já está correto em `menu_screen.dart` — ele chama `signOut()` e redireciona para `LoginScreen`. Não precisa alterar nada lá.

**Passo 4 — Testar manualmente**

1. Faça login normalmente no app
2. Force o fechamento do app (sem fazer logout)
3. Abra o app novamente
4. **Resultado esperado:** O app deve exibir brevemente a tela de splash e ir direto para a tela principal sem pedir login novamente
5. Faça logout pelo menu de configurações
6. Feche e abra o app novamente
7. **Resultado esperado:** App deve ir para a tela de login normalmente

### ⚠️ Cuidados

- Não modifique a lógica de login em `login_screen.dart` — essa é responsabilidade de outro membro
- O `_AuthGate` deve ficar dentro do `main.dart` mesmo, sem criar um arquivo separado — mantém simples

---

## D-02 — Ocultar Telefone para Não-Líderes

**Estimativa:** 6h | **Dependências:** Nenhuma

### Contexto do Problema

Na `ClientsScreen`, o número de telefone é exibido para todos os usuários. A lógica de permissão `isLeader` já existe no arquivo, mas ainda não é usada para controlar a visibilidade do telefone. Basta condicionar a exibição do campo `phone`.

### Arquivos que você vai modificar

- `lib/features/clients/clients_screen.dart`

### Passo a Passo

**Passo 1 — Localizar o trecho que exibe o telefone**

Dentro do método `build` da classe `_ClientsScreenState`, o telefone é exibido no `subtitle` do `ListTile`. Localize o trecho abaixo:

```dart
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const SizedBox(height: 4),
    Text(phone),         // <-- esta linha exibe para todos
    ...
  ],
),
```

**Passo 2 — Condicionar a exibição usando `isLeader`**

A variável `isLeader` já está disponível no escopo do `build`. Altere o trecho para:

```dart
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const SizedBox(height: 4),
    // Só exibe telefone se for Barbeiro Líder ou admin
    if (isLeader)
      Text(phone)
    else
      Text(
        '••••••••••',
        style: TextStyle(color: Colors.grey[600], letterSpacing: 2),
      ),
    ...
  ],
),
```

> **Nota:** Exibir `••••••••••` ao invés de esconder completamente é preferível — deixa claro que existe um número, mas está oculto. Isso evita confusão de "o cliente não tem telefone".

**Passo 3 — Verificar que o floating action button (Novo Cliente) continua aberto para todos**

O botão de adicionar cliente (`FloatingActionButton`) chama `_showClientBottomSheet()` sem verificação de permissão. O `ClientFormBottomSheet` não exibe o campo de telefone de forma problemática. **Não altere esse comportamento** — qualquer barbeiro pode cadastrar um cliente, mas não pode ver os telefones de clientes já cadastrados por outros.

**Passo 4 — Testar manualmente**

1. Faça login como um **barbeiro comum** (sem ser líder)
2. Vá para a aba Clientes
3. **Resultado esperado:** Os números de telefone aparecem mascarados como `••••••••••`
4. Faça login como **Barbeiro Líder** ou **admin**
5. **Resultado esperado:** Os números de telefone aparecem normalmente

### ⚠️ Cuidados

- Não modifique a lógica de busca de clientes em `clients_provider.dart` — é do Pedro
- Não oculte o campo `phone` dentro do `ClientFormBottomSheet` — o formulário é para edição e deve manter o campo visível para o líder

---

## D-03 — Tag do Barbeiro que Cadastrou o Cliente

**Estimativa:** 8h | **Dependências:** P-02 (Pedro precisa criar o campo `created_by_barber_id` na tabela `clients` antes)

### Contexto do Problema

Após o Pedro implementar a task P-02, a tabela `clients` terá o campo `created_by_barber_id` (UUID, FK para `barbers.id`). Você precisa exibir visualmente na `ClientsScreen` o nome do barbeiro que cadastrou aquele cliente, usando uma tag/badge abaixo do nome.

### Arquivos que você vai modificar

- `lib/features/clients/clients_screen.dart`
- `lib/features/clients/providers/clients_provider.dart` *(apenas a query de SELECT — coordene com Pedro antes)*

### Passo a Passo

**Passo 1 — Aguardar e confirmar o P-02 com o Pedro**

Antes de começar, confirme com o Pedro que:
1. A coluna `created_by_barber_id` foi criada no Supabase
2. O campo está sendo populado corretamente ao criar novos clientes

**Passo 2 — Atualizar a query do `clients_provider.dart` para trazer o nome do barbeiro**

> ⚠️ Converse com o Pedro antes de alterar este arquivo — ele também pode estar modificando o provider na task P-01 ou P-02.

Localize `lib/features/clients/providers/clients_provider.dart` e atualize o SELECT para incluir o join com a tabela `barbers`:

```dart
final clientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('clients')
      .select('*, created_by_barber:barbers!created_by_barber_id(id, users(name))')
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});
```

> **Como o join funciona:** `barbers!created_by_barber_id` força o Supabase a usar a FK `created_by_barber_id` para fazer o join com a tabela `barbers`, e dentro de `barbers` trazemos o `users(name)` para obter o nome do profissional.

**Passo 3 — Extrair o nome do barbeiro dentro do `itemBuilder` da lista**

No `itemBuilder` da `ListView.separated` dentro de `ClientsScreen`, logo após onde você extraiu `phone` e `initial`, adicione:

```dart
// Extrai o nome do barbeiro que cadastrou (pode ser null se campo não existir ainda)
final createdByBarber = client['created_by_barber'];
final createdByName = createdByBarber?['users']?['name']?.toString();
```

**Passo 4 — Adicionar a tag no `subtitle` do `ListTile`**

Dentro do `Column` do `subtitle`, após as tags de plano de assinatura, adicione:

```dart
if (createdByName != null && createdByName.isNotEmpty) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      Icon(Icons.person_pin_outlined, size: 12, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(
        'Cadastrado por $createdByName',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
        ),
      ),
    ],
  ),
],
```

**Passo 5 — Testar**

1. Peça ao Pedro para confirmar que a migração do campo `created_by_barber_id` foi aplicada
2. Cadastre um novo cliente estando logado como um barbeiro
3. Veja se a tag "Cadastrado por [Nome]" aparece na lista de clientes
4. Clientes cadastrados antes da migração não terão o campo — certifique-se que a tag simplesmente não aparece nesses casos (o `if (createdByName != null)` já cuida disso)

### ⚠️ Cuidados

- O join Supabase só vai funcionar se a FK `created_by_barber_id` estiver criada no banco — não tente implementar antes disso
- Se o Pedro também estiver modificando o `clients_provider.dart` para o P-01 (Realtime), combine a query num único select para não haver conflito de merge

---

## D-04 — Histórico do Cliente (UI)

**Estimativa:** 12h | **Dependências:** P-03 (Pedro precisa criar a tabela `client_history` e popular os dados)

### Contexto do Problema

Após o Pedro implementar a task P-03, existirá a tabela `client_history` com registros dos serviços/produtos de cada cliente. Você precisa criar a interface que exibe esse histórico quando o usuário acessa os detalhes de um cliente.

Atualmente, ao clicar em um cliente na lista, nada acontece para o barbeiro comum (só o líder pode editar). Você vai criar uma tela de detalhes do cliente com a seção de histórico.

### Arquivos que você vai criar/modificar

- `lib/features/clients/presentation/client_detail_screen.dart` *(arquivo novo)*
- `lib/features/clients/providers/client_history_provider.dart` *(arquivo novo)*
- `lib/features/clients/clients_screen.dart` *(adicionar navegação)*

### Passo a Passo

**Passo 1 — Aguardar e confirmar o P-03 com o Pedro**

Confirme com o Pedro:
1. A tabela `client_history` foi criada com os campos: `client_id`, `order_id`, `service_id` / `product_id`, `type` (enum: 'service', 'product'), `name`, `price`, `date`
2. O checkout já está populando essa tabela corretamente
3. As RLS policies permitem que os barbeiros consultem a tabela para clientes da sua unidade

**Passo 2 — Criar o provider para buscar o histórico**

Crie o arquivo `lib/features/clients/providers/client_history_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

// Provider que recebe o client_id e retorna o histórico daquele cliente
final clientHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('client_history')
      .select('*')
      .eq('client_id', clientId)
      .order('date', ascending: false); // Mais recente primeiro

  return List<Map<String, dynamic>>.from(response);
});
```

**Passo 3 — Criar a tela de detalhes do cliente**

Crie o arquivo `lib/features/clients/presentation/client_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/client_history_provider.dart';

class ClientDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientId = client['id'].toString();
    final historyAsync = ref.watch(clientHistoryProvider(clientId));

    final name = client['name'] ?? 'Cliente';
    final phone = client['phone'] ?? 'Sem telefone';
    final notes = client['notes'];
    final birthday = client['birthday'];
    final subscriptionPlan = client['subscription_plan']?.toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isPremium = subscriptionPlan == 'premium';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Cabeçalho do cliente ───────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: isPremium
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isPremium ? Colors.amber : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subscriptionPlan != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? Colors.amber.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPremium
                                  ? Colors.amber.withOpacity(0.5)
                                  : Colors.blue.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            isPremium ? '👑 Premium' : '⭐ Básico',
                            style: TextStyle(
                              color: isPremium ? Colors.amber : Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Informações básicas ────────────────────────────────────
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Telefone',
                  value: phone,
                ),
                if (birthday != null) ...[
                  const Divider(color: Colors.white10, height: 1),
                  _InfoRow(
                    icon: Icons.cake_outlined,
                    label: 'Aniversário',
                    value: _formatDate(birthday.toString()),
                  ),
                ],
                if (notes != null && notes.toString().isNotEmpty) ...[
                  const Divider(color: Colors.white10, height: 1),
                  _InfoRow(
                    icon: Icons.edit_note,
                    label: 'Observações',
                    value: notes.toString(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // ─── Histórico de serviços/produtos ────────────────────────
            const Text(
              'Histórico de Atendimentos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Erro ao carregar histórico: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Nenhum atendimento registrado ainda.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isService = item['type'] == 'service';
                    final itemName = item['name']?.toString() ?? 'Item';
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final date = item['date'] != null
                        ? _formatDate(item['date'].toString())
                        : 'Data desconhecida';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isService
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isService
                                  ? Icons.content_cut
                                  : Icons.inventory_2_outlined,
                              color: isService ? Colors.blue : Colors.purple,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'R\$ ${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Passo 4 — Adicionar navegação para a tela de detalhes em `clients_screen.dart`**

Na lista de clientes, o `ListTile` possui `onTap: isLeader ? () => _showClientBottomSheet(client: client) : null`. Você vai alterar isso para que **qualquer usuário** possa ver os detalhes, mas **somente o líder** abre o formulário de edição:

Primeiro, adicione o import no topo do arquivo:
```dart
import 'presentation/client_detail_screen.dart';
```

Depois, altere o `onTap` e o `trailing` do `ListTile`:

```dart
// Antes:
trailing: isLeader ? const Icon(Icons.edit_outlined, color: Colors.grey, size: 20) : null,
onTap: isLeader ? () => _showClientBottomSheet(client: client) : null,

// Depois:
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

> **Por que assim?** O líder continua com o fluxo de edição via bottom sheet. O barbeiro comum agora navega para uma tela de visualização somente leitura.

**Passo 5 — Testar**

1. Faça login como barbeiro comum → clique em um cliente → deve abrir a `ClientDetailScreen`
2. Faça login como líder → clique em um cliente → deve abrir o bottom sheet de edição (comportamento inalterado)
3. Confirme que a seção de histórico aparece vazia antes do Pedro terminar o P-03, e com dados reais depois

### ⚠️ Cuidados

- Não altere o `ClientFormBottomSheet` — é responsabilidade do Pedro (task P-02)
- Não modifique o `clients_provider.dart` sem combinar com o Pedro
- O arquivo `client_detail_screen.dart` fica dentro de uma subpasta `presentation/` que você precisará criar dentro de `lib/features/clients/`

---

## D-05 — Barbeiro "Fechar" sua Agenda

**Estimativa:** 15h | **Dependências:** Nenhuma

### Contexto do Problema

Precisa existir uma forma do barbeiro travar sua agenda para um dia específico, impedindo novos agendamentos. Isso requer: (1) uma nova coluna no banco de dados, (2) um provider para ler/escrever esse estado e (3) uma UI de toggle na tela de agenda.

### Arquivos que você vai criar/modificar

- Supabase: migração SQL
- `lib/features/orders/providers/schedule_lock_provider.dart` *(arquivo novo)*
- `lib/features/orders/presentation/schedule_agenda_screen.dart`

### Passo a Passo

**Passo 1 — Criar a migração SQL no Supabase**

Acesse o **Supabase Dashboard → SQL Editor** e execute:

```sql
-- Adiciona coluna para controle de agenda travada
ALTER TABLE public.barbers
ADD COLUMN IF NOT EXISTS is_schedule_locked boolean DEFAULT false;

-- Comentário para documentar o campo
COMMENT ON COLUMN public.barbers.is_schedule_locked IS
  'Quando true, a agenda do barbeiro está fechada e não aceita novos agendamentos';
```

Após executar, confirme que a coluna aparece na tabela `barbers` no Table Editor do Supabase.

**Passo 2 — Criar o provider para leitura e escrita do estado da agenda**

Crie o arquivo `lib/features/orders/providers/schedule_lock_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

/// Retorna true se a agenda do barbeiro logado está travada
final scheduleLockProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userProfile = await ref.watch(userProfileProvider.future);

  final barberId = userProfile['barber_id'] as String?;

  // Admins e líderes não possuem barber_id próprio para travar
  if (barberId == null) return false;

  final response = await supabase
      .from('barbers')
      .select('is_schedule_locked')
      .eq('id', barberId)
      .single();

  return response['is_schedule_locked'] as bool? ?? false;
});

/// Função utilitária para alternar o estado (não é um provider, é uma função)
Future<void> toggleScheduleLock({
  required String barberId,
  required bool currentValue,
  required dynamic supabase, // SupabaseClient
}) async {
  await supabase
      .from('barbers')
      .update({'is_schedule_locked': !currentValue})
      .eq('id', barberId);
}
```

**Passo 3 — Adicionar o toggle de agenda na `ScheduleAgendaScreen`**

No arquivo `lib/features/orders/presentation/schedule_agenda_screen.dart`, transforme o widget de `ConsumerWidget` para `ConsumerStatefulWidget` (necessário para gerenciar o estado local do toggle enquanto aguarda a confirmação do servidor):

Localize:
```dart
class ScheduleAgendaScreen extends ConsumerWidget {
  const ScheduleAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

Substitua por:
```dart
class ScheduleAgendaScreen extends ConsumerStatefulWidget {
  const ScheduleAgendaScreen({super.key});

  @override
  ConsumerState<ScheduleAgendaScreen> createState() =>
      _ScheduleAgendaScreenState();
}

class _ScheduleAgendaScreenState extends ConsumerState<ScheduleAgendaScreen> {
  bool _isTogglingLock = false;

  Future<void> _handleToggleLock({
    required bool currentLockState,
    required String barberId,
  }) async {
    if (_isTogglingLock) return;
    setState(() => _isTogglingLock = true);

    final supabase = ref.read(supabaseProvider);

    try {
      await supabase
          .from('barbers')
          .update({'is_schedule_locked': !currentLockState})
          .eq('id', barberId);

      ref.invalidate(scheduleLockProvider); // Atualiza o provider
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar agenda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingLock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref; // disponível via ConsumerState
```

**Passo 4 — Adicionar o import do novo provider e incluir o toggle na AppBar**

Adicione o import no topo do arquivo:
```dart
import '../providers/schedule_lock_provider.dart';
```

Dentro do `build`, observe os dados do usuário e do lock:
```dart
final userProfileAsync = ref.watch(userProfileProvider);
final scheduleLockAsync = ref.watch(scheduleLockProvider);

final isLeader = userProfileAsync.maybeWhen(
  data: (u) => u['category'] == 'Barbeiro Líder' || u['role'] == 'admin',
  orElse: () => false,
);

final barberId = userProfileAsync.maybeWhen(
  data: (u) => u['barber_id'] as String?,
  orElse: () => null,
);
```

Substitua a `AppBar` atual por uma que inclui o toggle (somente para barbeiros não-líderes que possuem `barber_id`):

```dart
appBar: AppBar(
  title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
  backgroundColor: const Color(0xFF1E1E1E),
  elevation: 0,
  actions: [
    // Só exibe o botão de fechar agenda para barbeiros comuns
    if (!isLeader && barberId != null)
      scheduleLockAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: !isLocked, // true = aberta, false = fechada
                      onChanged: (_) => _handleToggleLock(
                        currentLockState: isLocked,
                        barberId: barberId,
                      ),
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

**Passo 5 — Testar**

1. Faça login como barbeiro comum
2. Acesse a aba Agenda
3. O toggle deve aparecer na AppBar: "Agenda aberta" (verde) / "Agenda fechada" (vermelho)
4. Ao alternar, o estado deve persistir (verificar no Supabase se `is_schedule_locked` mudou)
5. Faça login como Barbeiro Líder → o toggle **não deve aparecer** (líderes gerenciam outros, não "fecham" a própria agenda)

### ⚠️ Cuidados

- Não altere o `appointmentsProvider` — apenas leia o `barberId` do `userProfileProvider`
- Comunique ao Ian que a coluna `is_schedule_locked` existe, pois ele vai precisar ler esse dado na task D-06 (que é também sua) e o campo também pode ser útil para as telas I-06 e I-07 dele
- A migração SQL deve ser feita em ambiente de desenvolvimento antes de subir para produção

---

## D-06 — Feedback Visual: Agenda Travada e Horários Agendados

**Estimativa:** 10h | **Dependências:** D-05

### Contexto do Problema

Ao criar um novo agendamento (telas `CreateAppointmentScreen` e `ScheduleScreen`), os slots de horário já exibem visualmente horários bloqueados, mas de forma genérica (cinza escuro). A nova lógica requer:
- **Azul + ✂️** para horários que já têm agendamento
- **Vermelho + ❌** para todos os horários de um barbeiro com `is_schedule_locked = true`

### Arquivos que você vai modificar

- `lib/features/orders/presentation/create_appointment_screen.dart`
- `lib/features/orders/presentation/schedule_screen.dart`

### Passo a Passo

**Passo 1 — Criar um provider para buscar o status de lock de todos os barbeiros**

Adicione ao arquivo `lib/features/orders/providers/schedule_lock_provider.dart` (criado na D-05) o seguinte provider:

```dart
/// Retorna um Map de {barberId: isLocked} para todos os barbeiros ativos da unidade
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

**Passo 2 — Modificar `CreateAppointmentScreen` para distinguir os tipos de bloqueio**

Abra `lib/features/orders/presentation/create_appointment_screen.dart`.

No início do método `build`, adicione a leitura do provider de lock:

```dart
final lockStatusAsync = ref.watch(allBarbersLockStatusProvider);
final Map<String, bool> lockStatus = lockStatusAsync.maybeWhen(
  data: (data) => data,
  orElse: () => {},
);
```

Ainda dentro do `build`, localize a linha onde `bookedSlots` é calculado:
```dart
final bookedSlots = (effectiveBarberId != null && appointmentsAsync.hasValue) 
    ? _getBookedSlots(appointmentsAsync.value!, effectiveBarberId) 
    : <String>[];
```

Adicione logo abaixo:
```dart
// Verifica se a agenda do barbeiro selecionado está travada
final isSelectedBarberLocked = effectiveBarberId != null
    ? (lockStatus[effectiveBarberId] ?? false)
    : false;
```

**Passo 3 — Atualizar a renderização dos slots de horário**

Localize o `itemBuilder` da `ListView.builder` que renderiza os slots. Atualmente o código é:

```dart
final isBooked = bookedSlots.contains(slot);
final isSelected = _selectedTime == slot;
```

Adicione a variável de slot bloqueado por agenda travada:
```dart
final isBooked = bookedSlots.contains(slot);
final isLocked = isSelectedBarberLocked; // todos os slots ficam vermelhos
final isSelected = _selectedTime == slot && !isLocked;
```

Substitua o `Container` do slot inteiro pelo código abaixo:

```dart
return Padding(
  padding: const EdgeInsets.only(right: 8),
  child: InkWell(
    // Não permite toque em slots agendados ou agenda travada
    onTap: (isBooked || isLocked)
        ? null
        : () => setState(() => _selectedTime = slot),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.green
            : isLocked
                ? Colors.red.withOpacity(0.2)
                : isBooked
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: Colors.greenAccent, width: 2)
            : isLocked
                ? Border.all(color: Colors.red.withOpacity(0.5))
                : isBooked
                    ? Border.all(color: Colors.blue.withOpacity(0.5))
                    : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            slot,
            style: TextStyle(
              color: isLocked
                  ? Colors.red[300]
                  : isBooked
                      ? Colors.blue[300]
                      : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          if (isLocked)
            const Text('❌', style: TextStyle(fontSize: 12))
          else if (isBooked)
            const Text('✂️', style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  ),
);
```

**Passo 4 — Adicionar aviso visual quando a agenda está completamente travada**

Logo antes da seção de horários (antes do `ListView.builder` dos slots), adicione um banner de aviso quando a agenda do barbeiro selecionado está travada:

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

**Passo 5 — Aplicar as mesmas mudanças em `schedule_screen.dart`**

O `ScheduleScreen` usa uma lógica semelhante de renderização de slots. Repita os passos 2, 3 e 4 neste arquivo. A lógica de `_getBookedSlots` é idêntica — apenas adicione o suporte a `isLocked` da mesma forma.

**Passo 6 — Adicionar import do provider no topo dos dois arquivos**

```dart
import '../providers/schedule_lock_provider.dart';
```

**Passo 7 — Testar**

1. Faça login como barbeiro comum e feche a agenda (usando o toggle da D-05)
2. Faça login como outro usuário (ou líder) e abra a tela de novo agendamento
3. Selecione o barbeiro que fechou a agenda
4. **Resultado esperado:** Todos os slots aparecem em vermelho com ❌, sem possibilidade de seleção, e o banner de aviso é exibido
5. Selecione um barbeiro com a agenda aberta
6. **Resultado esperado:** Horários já agendados aparecem em azul com ✂️; demais horários disponíveis normalmente

### ⚠️ Cuidados

- Não remova a lógica de `bookedSlots` existente — apenas adicione a nova lógica de `isLocked` em paralelo
- Verifique que o botão "Confirmar" do agendamento também fica desabilitado quando `isLocked` está ativo (a condição atual já faz isso via `_selectedTime == null`)
- Essa alteração não toca na `ScheduleAgendaScreen` principal — apenas nas telas de criação de agendamento

---

## D-07 — Exibição de Serviços por Setor

**Estimativa:** 8h | **Dependências:** P-06 (Pedro), I-06 e I-07 (Ian)

### Contexto do Problema

Após o Pedro adicionar o campo `sector` (enum: 'barbearia', 'salao', 'premium') em `services` e o Ian criar as telas `SalonScreen` e `PremiumSpaceScreen`, você precisa garantir que as telas de agendamento (`CreateAppointmentScreen` e `ScheduleScreen`) filtrem os serviços corretamente pelo setor. Cada tela de agendamento deve exibir apenas os serviços relevantes para o contexto em que foi aberta.

### Arquivos que você vai modificar

- `lib/features/orders/presentation/create_appointment_screen.dart`
- `lib/features/orders/presentation/schedule_screen.dart`
- `lib/core/supabase/providers.dart` *(com cuidado — apenas adicionar novo provider)*

### Passo a Passo

**Passo 1 — Aguardar a conclusão do P-06 e I-06/I-07**

Confirme com Pedro e Ian que:
1. A coluna `sector` foi criada na tabela `services` e os serviços existentes foram categorizados
2. As telas `SalonScreen` e `PremiumSpaceScreen` foram criadas e estão navegando para `CreateAppointmentScreen`

**Passo 2 — Criar um provider parametrizado por setor**

Em `lib/core/supabase/providers.dart`, adicione abaixo do `servicesProvider` existente (**não modifique o provider existente**):

```dart
/// Provider filtrado por setor — use este ao abrir agendamentos de uma tela específica
/// sector: 'barbearia', 'salao', ou 'premium'. null = retorna todos (comportamento padrão).
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

**Passo 3 — Adicionar um parâmetro `sector` nas telas de agendamento**

Para que as telas de agendamento saibam qual setor filtrar, adicione um parâmetro opcional às classes `CreateAppointmentScreen` e `ScheduleScreen`.

Em `create_appointment_screen.dart`:

```dart
// Antes:
class CreateAppointmentScreen extends ConsumerStatefulWidget {
  const CreateAppointmentScreen({super.key});

// Depois:
class CreateAppointmentScreen extends ConsumerStatefulWidget {
  /// Setor para filtrar serviços. null = exibe todos (padrão: barbearia)
  final String? sector;

  const CreateAppointmentScreen({super.key, this.sector});
```

Faça o mesmo em `schedule_screen.dart`:
```dart
class ScheduleScreen extends ConsumerStatefulWidget {
  final String? sector;
  const ScheduleScreen({super.key, this.sector});
```

**Passo 4 — Substituir o uso de `servicesProvider` pelo novo provider nos dois arquivos**

Em `create_appointment_screen.dart`, dentro do `build`, localize:
```dart
final servicesAsync = ref.watch(servicesProvider);
```

Substitua por:
```dart
// Usa o provider filtrado pelo setor (se não tiver setor, filtra para 'barbearia' por padrão)
final servicesAsync = ref.watch(servicesBySectorProvider(widget.sector ?? 'barbearia'));
```

Repita a mesma substituição em `schedule_screen.dart`.

**Passo 5 — Coordenar com Ian para passar o parâmetro `sector` na navegação**

Ian vai chamar `CreateAppointmentScreen` ou `ScheduleScreen` a partir das novas telas dele (SalonScreen, PremiumSpaceScreen). Mostre a ele como passar o parâmetro:

```dart
// Chamada da SalonScreen (Ian passará isto):
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const CreateAppointmentScreen(sector: 'salao'),
  ),
);

// Chamada da PremiumSpaceScreen (Ian passará isto):
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const CreateAppointmentScreen(sector: 'premium'),
  ),
);

// Chamada padrão da ScheduleAgendaScreen (sem mudança — já usa 'barbearia'):
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const CreateAppointmentScreen()),
);
```

**Passo 6 — Verificar o `_saveToSupabase` para manter o `service_id` correto**

A lógica de salvar o agendamento não precisa mudar — os `service_id`s já são únicos por serviço. O filtro por setor é apenas para a exibição na seleção.

**Passo 7 — Testar**

1. Abra um novo agendamento pela tela normal de Agenda (sem setor)
2. **Resultado esperado:** Apenas serviços com `sector = 'barbearia'` aparecem (ou todos, se quiser manter o padrão atual — combine com a equipe)
3. Abra um agendamento a partir da `SalonScreen` do Ian (após ele implementar)
4. **Resultado esperado:** Apenas serviços com `sector = 'salao'` aparecem
5. Confirme com o Pedro que todos os serviços cadastrados têm o campo `sector` preenchido

### ⚠️ Cuidados

- **Não remova** o `servicesProvider` original de `providers.dart` — outras telas podem estar usando ele (ex: `checkout_screen.dart` do Pedro)
- Comunique ao Ian **antes** de implementar — ele precisa saber qual parâmetro passar ao navegar para as telas de agendamento
- Combine com o Pedro qual deve ser o valor padrão do `sector` para serviços já cadastrados sem esse campo (sugerir `'barbearia'` como padrão na migration SQL dele)
- O Daniel (você) é responsável pelo **filtro dentro das telas de agendamento**; o Ian é responsável pela **tela de exibição** e por acionar a navegação com o setor correto

---

## Resumo das Dependências

| Task | Pode começar imediatamente? | Aguarda quem? |
|------|----------------------------|---------------|
| D-01 | ✅ Sim | — |
| D-02 | ✅ Sim | — |
| D-03 | ⏳ Parcialmente | Aguarda P-02 (Pedro) |
| D-04 | ⏳ Parcialmente | Aguarda P-03 (Pedro) |
| D-05 | ✅ Sim | — |
| D-06 | ⏳ Aguarda D-05 | Aguarda sua própria D-05 |
| D-07 | ⏳ Aguarda todos | Aguarda P-06 (Pedro) + I-06 e I-07 (Ian) |

**Ordem de execução recomendada:**
1. Comece por **D-01** e **D-02** — sem dependências, impacto imediato e controlado
2. Em paralelo, execute **D-05** e **D-06** (D-06 depende de D-05)
3. Enquanto isso, crie a estrutura de **D-03** e **D-04** (providers e telas) deixando a integração final para quando Pedro terminar P-02 e P-03
4. Execute **D-07** por último, após confirmar que Pedro e Ian terminaram suas partes

---

*Guia gerado com base na análise completa do código-fonte do BarberOS (Flutter + Riverpod + Supabase)*
