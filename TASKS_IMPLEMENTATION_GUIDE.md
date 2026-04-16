# 🛠️ Guia de Implementação — BarberOS
> Para ser executado por uma IA com acesso ao repositório (ex: Claude Code)  
> Cada tarefa contém: contexto, arquivos alvo, código exato a modificar e saída esperada

---

## ÍNDICE

- [BUG-01 — Coluna `price` inexistente em `order_items`](#bug-01)
- [BUG-02 — Violação de RLS na tabela `users`](#bug-02)
- [BUG-03 — Tela de produtos carrega serviços + empty state](#bug-03)
- [FEAT-01 — Serviços em scroll horizontal](#feat-01)
- [FEAT-02 — Unidades exibem todos os barbeiros](#feat-02)
- [FEAT-03 — Equipe: filtro "Todas as unidades"](#feat-03)
- [FEAT-04 — Clientes: planos de assinatura + data de aquisição](#feat-04)
- [FEAT-05 — Remover "Chamar Próximo" da lista de espera](#feat-05)
- [FEAT-06 — Financeiro: exportação PDF / Excel / CSV](#feat-06)
- [FEAT-07 — Layout Desktop/Tablet responsivo](#feat-07)
- [FEAT-08 — Dashboard Desktop: novos widgets](#feat-08)

---

<a name="bug-01"></a>
## BUG-01 — Coluna `price` inexistente em `order_items`

### Diagnóstico
O schema real da tabela `order_items` no Supabase usa campos diferentes dos que o código envia. A IA deve localizar **todos** os pontos que fazem insert/read nessa tabela e corrigir o mapeamento.

**Erro:** `PostgrestException: Could not find the 'price' column of 'order_items' (PGRST204)`

### Schema real da tabela (Supabase)
```sql
CREATE TABLE public.order_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id       uuid NOT NULL REFERENCES orders(id),
  item_type      TEXT NOT NULL,          -- 'service' | 'product' | 'extra'
  reference_id   uuid,                   -- nullable para extras sem referência
  name           varchar NOT NULL,
  quantity       integer DEFAULT 1,
  unit_price     numeric NOT NULL,       -- ← campo correto (não 'price')
  commission_pct numeric NOT NULL DEFAULT 40,
  commission_value numeric NOT NULL DEFAULT 0,
  created_at     timestamptz DEFAULT now()
);
```

### Arquivo 1: `lib/features/orders/providers/order_items_provider.dart`

**Localizar a função `addOrderItem` e substituir completamente:**

```dart
// ANTES (incorreto):
Future<Map<String, dynamic>> addOrderItem({
  required SupabaseClient supabase,
  required String orderId,
  String? serviceId,
  String? productId,
  required String serviceName,
  String? productName,
  required double price,
  int quantity = 1,
}) async {
  final response = await supabase.from('order_items').insert({
    'order_id': orderId,
    'service_id': serviceId,
    'product_id': productId,
    'service_name': serviceName,
    'product_name': productName,
    'price': price,          // ← campo errado
    'quantity': quantity,
  }).select().single();
  return response;
}

// DEPOIS (correto):
Future<Map<String, dynamic>> addOrderItem({
  required SupabaseClient supabase,
  required String orderId,
  String? referenceId,
  required String itemType,   // 'service' | 'product' | 'extra'
  required String name,
  required double unitPrice,
  int quantity = 1,
  double commissionPct = 40.0,
}) async {
  final commissionValue = unitPrice * (commissionPct / 100) * quantity;

  final response = await supabase.from('order_items').insert({
    'order_id': orderId,
    'item_type': itemType,
    'reference_id': referenceId,
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,          // ← campo correto
    'commission_pct': commissionPct,
    'commission_value': commissionValue,
  }).select().single();

  return response;
}
```

**Localizar a função `calculateOrderTotal` e corrigir a leitura:**
```dart
// ANTES:
total += (item['price'] as num).toDouble() * (item['quantity'] as num).toInt();

// DEPOIS:
total += (item['unit_price'] as num).toDouble() * (item['quantity'] as num).toInt();
```

### Arquivo 2: `lib/features/orders/presentation/checkout_screen.dart`

**Localizar `_addExtra()` e corrigir a chamada:**
```dart
// ANTES:
final item = await addOrderItem(
  supabase: supabase,
  orderId: widget.appointment['id'],
  serviceName: name,
  price: value,
  quantity: 1,
);

// DEPOIS:
final item = await addOrderItem(
  supabase: supabase,
  orderId: widget.appointment['id'],
  itemType: 'extra',
  name: name,
  unitPrice: value,
  quantity: 1,
  commissionPct: 0, // extras não geram comissão por padrão
);
```

**Localizar `_addProduct()` e corrigir:**
```dart
// ANTES:
final item = await addOrderItem(
  supabase: supabase,
  orderId: widget.appointment['id'],
  serviceId: product['id'],
  serviceName: product['name'],
  price: (product['price'] as num).toDouble(),
  quantity: 1,
);

// DEPOIS:
final item = await addOrderItem(
  supabase: supabase,
  orderId: widget.appointment['id'],
  itemType: 'product',
  referenceId: product['id'],
  name: product['name'],
  unitPrice: (product['price'] as num).toDouble(),
  quantity: 1,
  commissionPct: 0,
);
```

**Localizar `_calculateSubtotal()` e corrigir a leitura:**
```dart
// ANTES:
total += (item['price'] as num).toDouble() * (item['quantity'] as num).toInt();

// DEPOIS:
total += (item['unit_price'] as num).toDouble() * (item['quantity'] as num).toInt();
```

**E no widget de exibição do preço dos itens:**
```dart
// ANTES:
'R\$ ${((item['price'] as num).toDouble() * (item['quantity'] as num).toInt()).toStringAsFixed(2)}'

// DEPOIS:
'R\$ ${((item['unit_price'] as num).toDouble() * (item['quantity'] as num).toInt()).toStringAsFixed(2)}'
```

### Arquivo 3: `lib/features/orders/presentation/create_appointment_screen.dart`

**Localizar o bloco que monta `orderItemsToInsert` e substituir:**
```dart
// ANTES:
orderItemsToInsert.add({
  'order_id': orderId,
  'service_id': serviceId,
  'service_name': service['name'],
  'price': (service['price'] as num).toDouble(),
  'quantity': 1,
});

// DEPOIS:
final servicePrice = (service['price'] as num).toDouble();
const commissionPct = 40.0;
orderItemsToInsert.add({
  'order_id': orderId,
  'item_type': 'service',
  'reference_id': serviceId,
  'name': service['name'],
  'quantity': 1,
  'unit_price': servicePrice,
  'commission_pct': commissionPct,
  'commission_value': servicePrice * (commissionPct / 100),
});
```

### ✅ Saída esperada
- Adicionar extra → snackbar verde "Extra adicionado"
- Item aparece na lista com nome e valor correto
- Subtotal recalcula corretamente
- Nenhum erro `PGRST204` no console

---

<a name="bug-02"></a>
## BUG-02 — Violação de RLS na tabela `users`

### Diagnóstico
A operação de transferência/atualização tenta escrever na tabela `users` sem permissão RLS adequada. Isso pode ser um problema de policy no Supabase **ou** um insert/update sendo feito sem o contexto de autenticação correto.

**Erro:** `PostgrestException: new row violates row-level security policy for table "users" (42501)`

### Passo 1 — Localizar o código que escreve em `users`

Buscar no repositório por:
```bash
grep -rn "\.from('users')" lib/
grep -rn "\.from(\"users\")" lib/
```

Identificar qual operação dispara o erro (provavelmente um `.insert()` ou `.upsert()`).

### Passo 2 — Verificar se o cliente Supabase tem o token ativo

Em qualquer provider que faça escrita em `users`, garantir que o usuário está autenticado antes da chamada:
```dart
// Verificar antes de qualquer escrita em 'users':
final session = supabase.auth.currentSession;
if (session == null) {
  throw Exception('Usuário não autenticado');
}
// Só então fazer o insert/update
```

### Passo 3 — Corrigir a policy RLS no Supabase (executar no SQL Editor)

```sql
-- Verificar policies existentes:
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'users';

-- Se não existir policy para UPDATE/INSERT, criar:
CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "users_insert_own" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Se a tabela usa service_role para writes, garantir que a aplicação
-- NÃO está tentando escrever com a anon key em dados de outros usuários.
```

### Passo 4 — Caso o erro ocorra em operação de "transferência"

Se a operação de transferência envolve criar um novo registro em `users` (ex: criar perfil de barbeiro novo), o insert deve ser feito via Edge Function ou com a service_role key — não com a anon/user key diretamente:

```dart
// Em vez de inserir diretamente em 'users' pelo app:
// Chamar uma Edge Function que usa service_role internamente
final response = await supabase.functions.invoke('create-barber-profile', body: {
  'name': name,
  'email': email,
  'unit_id': unitId,
});
```

### ✅ Saída esperada
- Operação de transferência/criação de perfil completa sem erro
- Nenhum erro `42501` no console

---

<a name="bug-03"></a>
## BUG-03 — Tela de produtos carrega tabela de serviços + empty state

### Diagnóstico
`_showProductsBottomSheet` em `checkout_screen.dart` recebe uma lista chamada `services` e faz a busca na tabela errada.

### Arquivo: `lib/features/orders/presentation/checkout_screen.dart`

**1. Localizar onde `_showProductsBottomSheet` é chamado e qual provider é passado:**

```dart
// Buscar no build/body por algo como:
ref.watch(servicesProvider) // ← está usando provider de serviços!
```

**2. Criar (ou usar) o provider de produtos correto:**

Se `productsProvider` não existir em `lib/features/products/providers/products_provider.dart`, criá-lo:

```dart
// lib/features/products/providers/products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';

final productsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userProfile = await ref.watch(userProfileProvider.future);
  final unitId = userProfile['unit_id'] as String?;

  var query = supabase.from('products').select('id, name, price, stock');
  if (unitId != null) {
    query = query.eq('unit_id', unitId);
  }

  final response = await query.order('name');
  return List<Map<String, dynamic>>.from(response);
});
```

**3. Substituir o provider na chamada do bottom sheet:**

```dart
// ANTES (no build ou no botão "Adicionar Produto"):
final services = ref.watch(servicesProvider);
// ...
onPressed: () => _showProductsBottomSheet(services.value ?? [])

// DEPOIS:
final productsAsync = ref.watch(productsProvider);
// ...
onPressed: () => _showProductsBottomSheet(productsAsync.value ?? [])
```

**4. Atualizar o bottom sheet para exibir empty state correto:**

```dart
void _showProductsBottomSheet(List<Map<String, dynamic>> products) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adicionar Produto',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: products.isEmpty

              // ← EMPTY STATE (novo)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 56, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum produto cadastrado',
                          style: TextStyle(
                            fontSize: 16, color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Acesse Configurações › Produtos\npara adicionar itens ao estoque.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )

              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final stock = (product['stock'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: const Icon(Icons.inventory_2,
                            color: Colors.blue, size: 20),
                      ),
                      title: Text(product['name']),
                      subtitle: Text(
                        'R\$ ${(product['price'] as num).toStringAsFixed(2)}'
                        '${stock > 0 ? " · $stock em estoque" : " · Sem estoque"}',
                      ),
                      trailing: stock > 0
                          ? IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              onPressed: () {
                                _addProduct(product);
                                Navigator.pop(context);
                              },
                            )
                          : const Icon(Icons.remove_circle_outline,
                              color: Colors.grey),
                    );
                  },
                ),
          ),
        ],
      ),
    ),
  );
}
```

### ✅ Saída esperada
- Bottom sheet "Adicionar Produto" lista apenas produtos da tabela `products`
- Se não houver produtos: ícone de caixa vazia + mensagem + dica de onde cadastrar
- Se produto sem estoque: ícone cinza, não clicável

---

<a name="feat-01"></a>
## FEAT-01 — Serviços em scroll horizontal

### Arquivo alvo
Localizar o widget que renderiza a lista de serviços no checkout ou na tela de criação de agendamento. Provavelmente um `ListView.builder` vertical.

### Substituição

```dart
// ANTES — lista vertical de serviços:
ListView.builder(
  itemCount: services.length,
  itemBuilder: (context, index) {
    final service = services[index];
    return ListTile(title: Text(service['name']), ...);
  },
)

// DEPOIS — scroll horizontal com cards:
SizedBox(
  height: 110,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    itemCount: services.length,
    itemBuilder: (context, index) {
      final service = services[index];
      final isSelected = _selectedServices.contains(service['id']);
      return GestureDetector(
        onTap: () => _toggleService(service),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.grey[900],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white24,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.content_cut,
                color: isSelected ? Colors.black : Colors.grey[400],
                size: 28,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  service['name'],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'R\$ ${(service['price'] as num).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.black54 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
),
```

### ✅ Saída esperada
- Serviços exibidos como cards lado a lado com scroll horizontal
- Card selecionado fica branco com texto preto
- Card não selecionado permanece escuro com borda sutil

---

<a name="feat-02"></a>
## FEAT-02 — Unidades: exibir todos os barbeiros da unidade

### Arquivo alvo
Tela de detalhes da unidade (provavelmente `lib/features/team/presentation/` ou tela de unidades em `lib/features/settings/`).

### Provider necessário
Verificar se `unitBarbersProvider` já existe em `lib/features/team/providers/`. Se não existir, criar:

```dart
// lib/features/team/providers/unit_barbers_provider.dart
final unitBarbersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('barbers')
      .select('id, users(name, avatar_url), category, is_active')
      .eq('unit_id', unitId)
      .eq('is_active', true)
      .order('category'); // líderes primeiro

  return List<Map<String, dynamic>>.from(response);
});
```

### Widget de exibição na tela de detalhes da unidade

```dart
// Após exibir o responsável, adicionar seção "Equipe":
Consumer(
  builder: (context, ref, _) {
    final barbersAsync = ref.watch(unitBarbersProvider(unit['id']));
    return barbersAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const SizedBox.shrink(),
      data: (barbers) {
        if (barbers.isEmpty) return const SizedBox.shrink();

        // Separar responsável dos demais
        final leader = barbers.where(
          (b) => b['category'] == 'Barbeiro Líder'
        ).toList();
        final others = barbers.where(
          (b) => b['category'] != 'Barbeiro Líder'
        ).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text('Equipe',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...leader.map((b) => _BarberTile(barber: b, isLeader: true)),
            ...others.map((b) => _BarberTile(barber: b, isLeader: false)),
          ],
        );
      },
    );
  },
),

// Widget auxiliar:
class _BarberTile extends StatelessWidget {
  final Map<String, dynamic> barber;
  final bool isLeader;
  const _BarberTile({required this.barber, required this.isLeader});

  @override
  Widget build(BuildContext context) {
    final name = barber['users']?['name'] ?? 'Barbeiro';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: barber['users']?['avatar_url'] != null
            ? NetworkImage(barber['users']['avatar_url'])
            : null,
        child: barber['users']?['avatar_url'] == null
            ? Text(name[0].toUpperCase()) : null,
      ),
      title: Text(name),
      trailing: isLeader
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: const Text('Responsável',
                style: TextStyle(fontSize: 11, color: Colors.amber)),
            )
          : null,
    );
  }
}
```

### ✅ Saída esperada
- Tela de unidade mostra o responsável (com badge "Responsável") e todos os demais barbeiros da unidade
- Sem duplicação

---

<a name="feat-03"></a>
## FEAT-03 — Equipe: filtro "Todas as unidades"

### Arquivo: `lib/features/team/presentation/employees_screen.dart`

**1. Localizar o seletor de unidade (provavelmente um `DropdownButton` ou lista de chips)**

**2. Adicionar opção "Todas as unidades" no início da lista:**

```dart
// Onde o DropdownButton ou seletor é construído:

// Adicionar no início da lista de unidades:
final unitOptions = [
  {'id': null, 'name': 'Todas as unidades'},  // ← nova opção
  ...units,
];

DropdownButton<String?>(
  value: _selectedUnitId,  // null = todas
  items: unitOptions.map((u) => DropdownMenuItem<String?>(
    value: u['id'] as String?,
    child: Text(u['name'] as String),
  )).toList(),
  onChanged: (value) => setState(() => _selectedUnitId = value),
),
```

**3. Ajustar a query dos barbeiros para aceitar `null` como "todos":**

```dart
// No provider ou na chamada de busca:
var query = supabase
    .from('barbers')
    .select('id, users(name, avatar_url), category, unit_id, units(name)');

if (_selectedUnitId != null) {
  query = query.eq('unit_id', _selectedUnitId!);
}

final barbers = await query.order('created_at');
```

**Se o provider usar `.family`, ajustar para aceitar `String?`:**

```dart
final filteredBarbersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  var query = supabase
      .from('barbers')
      .select('id, users(name, avatar_url), category, unit_id, units(name)')
      .eq('is_active', true);
  
  if (unitId != null) {
    query = query.eq('unit_id', unitId);
  }
  
  return List<Map<String, dynamic>>.from(await query.order('created_at'));
});
```

### ✅ Saída esperada
- Seletor de unidade tem "Todas as unidades" como primeira opção
- Ao selecionar, lista exibe barbeiros de todas as unidades
- Cada card de barbeiro mostra o nome da unidade quando em modo "Todas"

---

<a name="feat-04"></a>
## FEAT-04 — Clientes: planos de assinatura + data de aquisição

### Passo 1 — Migration SQL (executar no Supabase SQL Editor)

```sql
-- Adicionar novos campos na tabela clients
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS subscription_plan TEXT 
    CHECK (subscription_plan IN ('basic', 'premium')) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS subscription_acquired_at DATE DEFAULT NULL;

-- Migrar clientes VIP existentes para 'premium' (opcional):
UPDATE public.clients
SET subscription_plan = 'premium'
WHERE is_vip = true;
```

### Passo 2 — Arquivo: `lib/features/clients/clients_screen.dart`

**Localizar o bloco do switch "Cliente VIP / Assinante" e substituir:**

```dart
// ANTES:
Container(
  // SwitchListTile VIP
  child: SwitchListTile(
    title: const Text('Cliente VIP / Assinante', ...),
    value: _isPremium,
    onChanged: (value) => setState(() => _isPremium = value),
  ),
),

// DEPOIS — seletor de plano com 3 opções:
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Plano de Assinatura',
        style: TextStyle(color: Colors.grey[400], fontSize: 13,
            fontWeight: FontWeight.w500)),
    const SizedBox(height: 8),
    Row(
      children: [
        _PlanChip(
          label: 'Sem plano',
          icon: Icons.person_outline,
          color: Colors.grey,
          selected: _subscriptionPlan == null,
          onTap: () => setState(() {
            _subscriptionPlan = null;
            _subscriptionAcquiredAt = null;
          }),
        ),
        const SizedBox(width: 8),
        _PlanChip(
          label: 'Básico',
          icon: Icons.star_border,
          color: Colors.blue,
          selected: _subscriptionPlan == 'basic',
          onTap: () => setState(() => _subscriptionPlan = 'basic'),
        ),
        const SizedBox(width: 8),
        _PlanChip(
          label: 'Premium',
          icon: Icons.workspace_premium,
          color: Colors.amber,
          selected: _subscriptionPlan == 'premium',
          onTap: () => setState(() => _subscriptionPlan = 'premium'),
        ),
      ],
    ),
    // Data de aquisição — só aparece se tiver plano selecionado
    if (_subscriptionPlan != null) ...[
      const SizedBox(height: 12),
      InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _subscriptionAcquiredAt ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            helpText: 'Data de aquisição do plano',
          );
          if (date != null) setState(() => _subscriptionAcquiredAt = date);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                _subscriptionAcquiredAt == null
                    ? 'Data de aquisição'
                    : '${_subscriptionAcquiredAt!.day.toString().padLeft(2,'0')}/'
                      '${_subscriptionAcquiredAt!.month.toString().padLeft(2,'0')}/'
                      '${_subscriptionAcquiredAt!.year}',
                style: TextStyle(
                  color: _subscriptionAcquiredAt == null
                      ? Colors.grey[400] : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ],
),
```

**Widget auxiliar `_PlanChip`:**

```dart
class _PlanChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PlanChip({
    required this.label, required this.icon, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                color: selected ? color : Colors.grey[400],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
          ],
        ),
      ),
    );
  }
}
```

**Passo 3 — Atualizar `_saveClient()` para incluir os novos campos:**

```dart
// Adicionar no Map de dados enviados ao Supabase:
final clientData = {
  'name': _nameController.text.trim(),
  // ... outros campos existentes ...
  'subscription_plan': _subscriptionPlan,
  'subscription_acquired_at': _subscriptionAcquiredAt?.toIso8601String(),
  // Manter compatibilidade com is_vip:
  'is_vip': _subscriptionPlan != null,
};
```

**Passo 4 — Adicionar variáveis de estado no `State`:**

```dart
String? _subscriptionPlan;
DateTime? _subscriptionAcquiredAt;
```

**E inicializá-las no `_loadClient()` (ao editar):**

```dart
_subscriptionPlan = client['subscription_plan'] as String?;
final acquiredStr = client['subscription_acquired_at'] as String?;
_subscriptionAcquiredAt = acquiredStr != null ? DateTime.parse(acquiredStr) : null;
```

### ✅ Saída esperada
- Formulário mostra 3 chips: "Sem plano" | "Básico" | "Premium"
- Ao selecionar Básico ou Premium, aparece date picker para data de aquisição
- Dados salvos corretamente no banco
- Ícone na lista de clientes reflete o plano (gold para premium, azul para básico)

---

<a name="feat-05"></a>
## FEAT-05 — Remover "Chamar Próximo" da lista de espera

### Arquivo: `lib/features/orders/presentation/waiting_list_screen.dart`

**1. Remover o método `_callNext` inteiro:**

```dart
// REMOVER este bloco completo:
bool _isLoading = false;

Future<void> _callNext() async {
  setState(() => _isLoading = true);
  // ... todo o conteúdo ...
  finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**2. Remover o `bottomNavigationBar` do `Scaffold`:**

```dart
// ANTES:
return Scaffold(
  backgroundColor: const Color(0xFF121212),
  appBar: AppBar(...),
  body: ...,
  bottomNavigationBar: SafeArea(       // ← REMOVER este bloco
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _callNext,
        icon: ...,
        label: Text(_isLoading ? 'Chamando...' : 'Chamar Próximo', ...),
        style: ...,
      ),
    ),
  ),
);

// DEPOIS:
return Scaffold(
  backgroundColor: const Color(0xFF121212),
  appBar: AppBar(...),
  body: ...,
  // bottomNavigationBar removido
);
```

**3. Converter `ConsumerStatefulWidget` para `ConsumerWidget` (opcional, pois não há mais estado local):**

```dart
class WaitingListScreen extends ConsumerWidget {
  const WaitingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider);
    // resto do build sem setState
  }
}
```

### ✅ Saída esperada
- Tela de lista de espera não tem mais botão na parte inferior
- Apenas a lista de clientes em espera é exibida

---

<a name="feat-06"></a>
## FEAT-06 — Financeiro: exportação PDF / Excel / CSV

### Dependências — adicionar em `pubspec.yaml`

```yaml
dependencies:
  pdf: ^3.11.0           # geração de PDF
  printing: ^5.12.0      # share sheet nativo no mobile
  excel: ^4.0.2          # geração de Excel
  csv: ^6.0.0            # geração de CSV
  path_provider: ^2.1.3  # diretório temporário
  share_plus: ^10.0.0    # compartilhar arquivo no mobile
  open_filex: ^4.5.0     # abrir arquivo após download
```

Após adicionar, rodar:
```bash
flutter pub get
```

---

### Arquivo: `lib/features/reports/presentation/financial_screen.dart`

**1. Adicionar botão de exportação no AppBar:**

```dart
AppBar(
  title: const Text('Financeiro'),
  actions: [
    IconButton(
      icon: const Icon(Icons.file_download_outlined),
      tooltip: 'Exportar relatório',
      onPressed: () => _showExportBottomSheet(context),
    ),
  ],
),
```

**2. Bottom sheet de exportação:**

```dart
void _showExportBottomSheet(BuildContext context) {
  // Estado local do bottom sheet
  String _format = 'pdf';            // 'pdf' | 'excel' | 'csv'
  String _period = '7days';          // '7days' | '30days' | 'current_month' | 'custom'
  bool _detailed = false;
  DateTimeRange? _customRange;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Exportar Relatório',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Formato
              Text('Formato', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FormatChip(label: 'PDF', icon: Icons.picture_as_pdf,
                    selected: _format == 'pdf',
                    onTap: () => setSheet(() => _format = 'pdf')),
                  const SizedBox(width: 8),
                  _FormatChip(label: 'Excel', icon: Icons.table_chart_outlined,
                    selected: _format == 'excel',
                    onTap: () => setSheet(() => _format = 'excel')),
                  const SizedBox(width: 8),
                  _FormatChip(label: 'CSV', icon: Icons.grid_on,
                    selected: _format == 'csv',
                    onTap: () => setSheet(() => _format = 'csv')),
                ],
              ),
              const SizedBox(height: 20),

              // Período
              Text('Período', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _PeriodChip(label: 'Últimos 7 dias', selected: _period == '7days',
                    onTap: () => setSheet(() => _period = '7days')),
                  _PeriodChip(label: 'Últimos 30 dias', selected: _period == '30days',
                    onTap: () => setSheet(() => _period = '30days')),
                  _PeriodChip(label: 'Mês atual', selected: _period == 'current_month',
                    onTap: () => setSheet(() => _period = 'current_month')),
                  _PeriodChip(label: 'Personalizado', selected: _period == 'custom',
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (range != null) {
                        setSheet(() {
                          _period = 'custom';
                          _customRange = range;
                        });
                      }
                    }),
                ],
              ),
              if (_period == 'custom' && _customRange != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_customRange!.start.day}/${_customRange!.start.month}/${_customRange!.start.year}'
                    ' → '
                    '${_customRange!.end.day}/${_customRange!.end.month}/${_customRange!.end.year}',
                    style: const TextStyle(color: Colors.amber, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),

              // Relatório detalhado (só para PDF)
              if (_format == 'pdf') ...[
                CheckboxListTile(
                  value: _detailed,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gerar relatório detalhado'),
                  subtitle: Text(
                    'Inclui: dia, cliente, serviço, produto, valor e barbeiro por atendimento',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  onChanged: (v) => setSheet(() => _detailed = v ?? false),
                  activeColor: Colors.white,
                  checkColor: Colors.black,
                ),
                const SizedBox(height: 8),
              ],

              // Botão exportar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Gerar e Exportar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _generateExport(
                      format: _format,
                      period: _period,
                      customRange: _customRange,
                      detailed: _detailed,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

---

**3. Criar arquivo `lib/features/reports/presentation/export_service.dart`:**

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExportService {
  /// Resolve o DateTimeRange com base na opção selecionada
  static DateTimeRange resolvePeriod(String period, DateTimeRange? custom) {
    final now = DateTime.now();
    switch (period) {
      case '7days':
        return DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      case '30days':
        return DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
      case 'current_month':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case 'custom':
        return custom!;
      default:
        return DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
    }
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────

  static Future<void> exportPdf({
    required String unitName,
    required List<Map<String, dynamic>> orders,      // receitas
    required List<Map<String, dynamic>> expenses,    // despesas
    required DateTimeRange range,
    required bool detailed,
  }) async {
    final pdf = pw.Document();

    // Carregar fonte e logo da identidade visual
    final logoImage = await _loadLogo();

    // Cores da identidade visual (dark theme dourado)
    const gold = PdfColor.fromInt(0xFFD4AF37);
    const bgDark = PdfColor.fromInt(0xFF1A1A1A);
    const textLight = PdfColor.fromInt(0xFFFFFFFF);
    const textMuted = PdfColor.fromInt(0xFF888888);

    // Cálculos
    final totalRevenue = orders.fold<double>(
        0, (sum, o) => sum + (o['total'] as num).toDouble());
    final totalExpenses = expenses.fold<double>(
        0, (sum, e) => sum + (e['amount'] as num).toDouble());
    final result = totalRevenue - totalExpenses;

    // Agrupar receitas por forma de pagamento
    final revenueByPayment = <String, double>{};
    for (final o in orders) {
      final method = o['payment_method'] as String? ?? 'Outros';
      revenueByPayment[method] = (revenueByPayment[method] ?? 0) +
          (o['total'] as num).toDouble();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.interRegular(),
          bold: await PdfGoogleFonts.interBold(),
        ),
        header: (ctx) => _buildPdfHeader(
          logoImage, unitName, range, gold, bgDark, textLight),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('BarberOS · Relatório Financeiro',
                style: pw.TextStyle(color: textMuted, fontSize: 8)),
              pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(color: textMuted, fontSize: 8)),
            ],
          ),
        ),
        build: (ctx) => [
          // ── RECEITAS (agrupado) ──────────────────────────────────────────
          _pdfSectionTitle('Receitas', gold),
          pw.SizedBox(height: 8),
          _pdfRevenueTable(revenueByPayment, totalRevenue),

          // ── RECEITAS DETALHADAS (se solicitado) ─────────────────────────
          if (detailed) ...[
            pw.SizedBox(height: 16),
            _pdfSectionTitle('Detalhamento de Atendimentos', gold),
            pw.SizedBox(height: 8),
            _pdfDetailedTable(orders),
          ],

          // ── DESPESAS (sempre detalhadas) ─────────────────────────────────
          pw.SizedBox(height: 24),
          _pdfSectionTitle('Despesas', PdfColors.red300),
          pw.SizedBox(height: 8),
          _pdfExpensesTable(expenses, totalExpenses),

          // ── RESUMO FINAL ─────────────────────────────────────────────────
          pw.SizedBox(height: 24),
          _pdfSummaryBox(totalRevenue, totalExpenses, result, gold),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _shareOrDownload(bytes, 'relatorio_financeiro.pdf', 'application/pdf');
  }

  static pw.Widget _buildPdfHeader(
    pw.ImageProvider? logo, String unitName,
    DateTimeRange range, PdfColor gold,
    PdfColor bg, PdfColor textLight,
  ) {
    final fmt = (DateTime d) =>
        '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (logo != null)
              pw.Image(logo, height: 32),
            pw.SizedBox(height: 6),
            pw.Text(unitName,
              style: pw.TextStyle(color: textLight, fontSize: 16,
                  fontWeight: pw.FontWeight.bold)),
            pw.Text('${fmt(range.start)} → ${fmt(range.end)}',
              style: pw.TextStyle(color: gold, fontSize: 11)),
          ]),
          pw.Text('RELATÓRIO\nFINANCEIRO',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(color: gold, fontSize: 14,
                fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _pdfSectionTitle(String title, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
        ),
        child: pw.Text(title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
              color: color)),
      );

  static pw.Widget _pdfRevenueTable(
      Map<String, double> byPayment, double total) {
    final paymentLabels = {
      'pix': 'Pix',
      'credit_card': 'Cartão de Crédito',
      'debit_card': 'Cartão de Débito',
      'cash': 'Dinheiro',
    };
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Forma de Pagamento',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Total',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
        ...byPayment.entries.map((e) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text(paymentLabels[e.key] ?? e.key,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text('R\$ ${e.value.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.right)),
        ])),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6),
                child: pw.Text('TOTAL RECEITAS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6),
                child: pw.Text('R\$ ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _pdfDetailedTable(List<Map<String, dynamic>> orders) {
    final headers = ['Data', 'Cliente', 'Serviço', 'Produto', 'Valor', 'Barbeiro'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(55),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(h, style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 8)),
          )).toList(),
        ),
        ...orders.map((o) {
          final dt = DateTime.parse(o['start_time'] as String).toLocal();
          final dateStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5),
                child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5),
                child: pw.Text(o['client_name'] ?? 'Avulso',
                    style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5),
                child: pw.Text(o['service_name'] ?? '-',
                    style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5),
                child: pw.Text(o['product_name'] ?? '-',
                    style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                    'R\$ ${(o['total'] as num).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(padding: const pw.EdgeInsets.all(5),
                child: pw.Text(o['barber_name'] ?? '-',
                    style: const pw.TextStyle(fontSize: 8))),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _pdfExpensesTable(
      List<Map<String, dynamic>> expenses, double total) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['Descrição', 'Categoria', 'Valor'].map((h) =>
            pw.Padding(padding: const pw.EdgeInsets.all(6),
                child: pw.Text(h, style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 10)))
          ).toList(),
        ),
        ...expenses.map((e) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text(e['description'] ?? '-',
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text(e['category'] ?? '-',
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text('R\$ ${(e['amount'] as num).toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.right)),
        ])),
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text('TOTAL DESPESAS',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text('')),
          pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text('R\$ ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10,
                      color: PdfColors.red400),
                  textAlign: pw.TextAlign.right)),
        ]),
      ],
    );
  }

  static pw.Widget _pdfSummaryBox(
      double revenue, double expenses, double result, PdfColor gold) {
    final isPositive = result >= 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF1A1A1A),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: gold, width: 1),
      ),
      child: pw.Column(children: [
        pw.Text('RESUMO FINANCEIRO',
          style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold,
              fontSize: 12)),
        pw.SizedBox(height: 12),
        _summaryRow('Receitas', revenue, PdfColors.green400),
        pw.SizedBox(height: 4),
        _summaryRow('Despesas', expenses, PdfColors.red400),
        pw.Divider(color: PdfColors.grey400),
        _summaryRow(
          'Resultado',
          result,
          isPositive ? PdfColors.green400 : PdfColors.red400,
          bold: true,
        ),
      ]),
    );
  }

  static pw.Widget _summaryRow(String label, double value, PdfColor color,
      {bool bold = false}) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 11, color: PdfColors.grey100)),
        pw.Text('R\$ ${value.toStringAsFixed(2)}',
          style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 11, color: color)),
      ]);

  // ─── Excel ───────────────────────────────────────────────────────────────

  static Future<void> exportExcel({
    required String unitName,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> expenses,
    required DateTimeRange range,
  }) async {
    final excel = Excel.createExcel();

    // Aba Receitas
    final revenueSheet = excel['Receitas'];
    revenueSheet.appendRow(['Data', 'Cliente', 'Serviço', 'Produto',
        'Forma Pagamento', 'Valor', 'Barbeiro']);
    for (final o in orders) {
      final dt = DateTime.parse(o['start_time'] as String).toLocal();
      revenueSheet.appendRow([
        '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}',
        o['client_name'] ?? 'Avulso',
        o['service_name'] ?? '-',
        o['product_name'] ?? '-',
        o['payment_method'] ?? '-',
        (o['total'] as num).toDouble(),
        o['barber_name'] ?? '-',
      ]);
    }

    // Aba Despesas
    final expenseSheet = excel['Despesas'];
    expenseSheet.appendRow(['Data', 'Descrição', 'Categoria', 'Valor']);
    for (final e in expenses) {
      expenseSheet.appendRow([
        e['date'] ?? '-',
        e['description'] ?? '-',
        e['category'] ?? '-',
        (e['amount'] as num).toDouble(),
      ]);
    }

    // Aba Resumo
    final summarySheet = excel['Resumo'];
    final revenue = orders.fold<double>(0, (s, o) => s + (o['total'] as num).toDouble());
    final exp = expenses.fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());
    summarySheet.appendRow(['Unidade', unitName]);
    summarySheet.appendRow(['Total Receitas', revenue]);
    summarySheet.appendRow(['Total Despesas', exp]);
    summarySheet.appendRow(['Resultado', revenue - exp]);

    // Remover aba default
    excel.delete('Sheet1');

    final bytes = excel.encode()!;
    await _shareOrDownload(
        Uint8List.fromList(bytes), 'relatorio_financeiro.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  // ─── CSV ─────────────────────────────────────────────────────────────────

  static Future<void> exportCsv({
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> expenses,
    required DateTimeRange range,
  }) async {
    final rows = <List<dynamic>>[
      ['RECEITAS'],
      ['Data', 'Cliente', 'Serviço', 'Produto', 'Pagamento', 'Valor', 'Barbeiro'],
      ...orders.map((o) {
        final dt = DateTime.parse(o['start_time'] as String).toLocal();
        return [
          '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}',
          o['client_name'] ?? 'Avulso',
          o['service_name'] ?? '-',
          o['product_name'] ?? '-',
          o['payment_method'] ?? '-',
          (o['total'] as num).toDouble(),
          o['barber_name'] ?? '-',
        ];
      }),
      [],
      ['DESPESAS'],
      ['Data', 'Descrição', 'Categoria', 'Valor'],
      ...expenses.map((e) => [
        e['date'] ?? '-',
        e['description'] ?? '-',
        e['category'] ?? '-',
        (e['amount'] as num).toDouble(),
      ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(csv.codeUnits);
    await _shareOrDownload(bytes, 'relatorio_financeiro.csv', 'text/csv');
  }

  // ─── Compartilhar / Download ──────────────────────────────────────────────

  static Future<void> _shareOrDownload(
      Uint8List bytes, String filename, String mimeType) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: share sheet nativo
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: 'Relatório Financeiro — BarberOS',
      );
    } else {
      // Desktop/Tablet: abrir diretamente
      await OpenFilex.open(file.path);
    }
  }

  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/icons/app_icon.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
```

### ✅ Saída esperada — Fluxo completo
1. Usuário toca ícone de download no AppBar do Financeiro
2. Bottom sheet abre com opções de formato, período e toggle detalhado
3. Ao tocar "Gerar e Exportar":
   - Loading indicator enquanto gera o arquivo
   - **Mobile:** share sheet nativo do iOS/Android abre para o usuário escolher WhatsApp, e-mail, Google Drive, etc.
   - **Desktop/Tablet:** arquivo salvo em temp e aberto automaticamente
4. PDF gerado tem:
   - Cabeçalho com logo + nome da unidade + período (fundo escuro com dourado)
   - Tabela de receitas agrupada por pagamento
   - (Se detalhado) tabela linha a linha com dia/cliente/serviço/produto/valor/barbeiro
   - Seção de despesas sempre detalhada
   - Caixa de resumo final: Receitas | Despesas | Resultado

---

<a name="feat-07"></a>
## FEAT-07 — Layout Desktop/Tablet responsivo

### Estratégia geral

Adicionar um helper de breakpoints em `lib/core/utils/responsive.dart`:

```dart
// lib/core/utils/responsive.dart
import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  /// Retorna valor baseado no breakpoint atual
  static T value<T>(BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }
}
```

### Ajuste nos formulários (campos e fontes)

Localizar nos widgets de formulário (clients, employees, settings) e aplicar:

```dart
// ANTES — tamanhos fixos:
padding: const EdgeInsets.all(28),
TextStyle(fontSize: 22, fontWeight: FontWeight.bold)

// DEPOIS — responsivos:
padding: EdgeInsets.all(Responsive.value(context,
    mobile: 16, tablet: 20, desktop: 28)),
TextStyle(
  fontSize: Responsive.value(context,
      mobile: 16.0, tablet: 18.0, desktop: 22.0),
  fontWeight: FontWeight.bold,
)
```

### KPI cards no Dashboard Desktop

```dart
// ANTES — 4 cards sempre em Row:
Row(
  children: kpis.map((kpi) => Expanded(child: _KpiCard(kpi))).toList(),
)

// DEPOIS — grid responsivo:
LayoutBuilder(
  builder: (context, constraints) {
    final crossAxisCount = constraints.maxWidth > 1024 ? 4
        : constraints.maxWidth > 600 ? 2
        : 2;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: constraints.maxWidth > 600 ? 2.0 : 1.6,
      children: kpis.map((kpi) => _KpiCard(kpi)).toList(),
    );
  },
),
```

### ✅ Saída esperada
- Em tablet (600–1023px): campos de formulário com padding e fonte reduzidos, KPI cards em grid 2×2
- Em desktop (1024px+): layout completo 4 colunas sem distorção

---

<a name="feat-08"></a>
## FEAT-08 — Dashboard Desktop: novos widgets sugeridos

### Widgets a adicionar em `lib/features/dashboard/presentation/home_screen.dart` (versão desktop)

Verificar quais dados já existem no `dashboardProvider`. Para cada widget novo, adicionar a query correspondente no provider antes de implementar a UI.

| Widget | Query Supabase necessária | Prioridade |
|--------|---------------------------|------------|
| **Resultado do Mês** (Receitas − Despesas) | Já tem faturamento; buscar `expenses` do mês | 🔴 Alta |
| **Serviços Mais Realizados** (Top 5) | `order_items` agrupado por `name`, `count DESC` | 🟠 Média |
| **Clientes Novos vs Recorrentes** | `clients` com `created_at` no período vs total | 🟡 Normal |
| **Gráfico de Receita (7 dias)** | `orders` agrupado por `date(start_time)` | 🟡 Normal |
| **Ocupação das Unidades** | `orders` com `status IN ('open','waiting')` por unidade | 🟡 Normal |

### Exemplo — Widget "Resultado do Mês"

```dart
// Adicionar no _buildContent, dentro do Column, após _buildOperationalRow:
if (isDesktop) ...[
  const SizedBox(height: 28),
  _buildMonthResultCard(data),
],

Widget _buildMonthResultCard(Map<String, dynamic> data) {
  final revenue = (data['faturamento'] as double? ?? 0);
  final expenses = (data['total_expenses'] as double? ?? 0);
  final result = revenue - expenses;
  final isPositive = result >= 0;

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isPositive ? Colors.green.withOpacity(0.4)
            : Colors.red.withOpacity(0.4),
        width: 1.5,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ResultItem(label: 'Receitas', value: revenue, color: Colors.green),
        const Icon(Icons.remove, color: Colors.grey),
        _ResultItem(label: 'Despesas', value: expenses, color: Colors.red),
        const Icon(Icons.drag_handle, color: Colors.grey),
        _ResultItem(
          label: 'Resultado',
          value: result,
          color: isPositive ? Colors.green : Colors.red,
          bold: true,
        ),
      ],
    ),
  );
}
```

### ✅ Saída esperada
- Dashboard Desktop mostra bloco de resultado mensal com destaque verde/vermelho
- Widgets adicionais aparecem apenas na versão desktop (protegidos por `if (isDesktop)`)

---

## 📋 Ordem de execução recomendada

```
1. BUG-01  ← desbloqueia checkout completamente
2. BUG-02  ← desbloqueia operações de perfil
3. BUG-03  ← melhora UX imediata
4. FEAT-05 ← remoção simples
5. FEAT-01 ← layout visual
6. FEAT-02 ← dados de unidade
7. FEAT-03 ← filtro de equipe
8. FEAT-04 ← requer migration SQL
9. FEAT-07 ← responsividade (rodar em device tablet para validar)
10. FEAT-06 ← maior complexidade, dependências novas
11. FEAT-08 ← expansão do dashboard
```

---

## 🔧 Comandos úteis para a IA

```bash
# Verificar todos os usos de 'price' na tabela order_items:
grep -rn "'price'" lib/features/orders/

# Verificar imports do supabase_provider:
grep -rn "supabaseProvider" lib/features/reports/

# Rodar o app no modo debug após cada task:
flutter run --debug

# Verificar warnings de tipo:
flutter analyze lib/

# Verificar se pubspec.yaml tem as dependências de export:
grep -E "pdf:|printing:|excel:|csv:|share_plus:" pubspec.yaml
```
