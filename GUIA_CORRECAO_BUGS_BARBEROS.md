# 🛠️ Guia de Correção de Bugs — BarberOS

> Documento técnico com diagnóstico detalhado e orientações de correção para os 3 problemas reportados.

---

## BUG #1 — Grade de Horários não aparece ao abrir agendamento pela Home

### 🔍 Diagnóstico

O botão **"Agendar Cliente"** na Home navega para `CreateAppointmentScreen`:

```dart
// lib/features/dashboard/presentation/home_screen.dart
'onTap': () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const CreateAppointmentScreen()),
  );
},
```

O problema está na lógica que **controla a visibilidade da grade de horários** dentro de `CreateAppointmentScreen`. A grade só é renderizada quando o bloco condicional `if (_selectedBarber != null)` é verdadeiro:

```dart
// lib/features/orders/presentation/create_appointment_screen.dart
// 4. Horários
if (_selectedBarber != null) ...[ // ← A GRADE SÓ APARECE SE HOUVER BARBEIRO SELECIONADO
  Row(...),
  const SizedBox(height: 12),
  Container(
    height: 180,
    ...grade de horários...
  ),
],
```

**O que ocorre na prática:**

- Se o usuário logado é um **Barbeiro comum** (`isLeader == false`), o campo de seleção de profissional é ocultado (`if (isLeader)` no bloco "3. Profissional") — o que é correto.
- Porém, a **grade de horários** usa `_selectedBarber` como guarda, e esse campo **nunca é preenchido automaticamente** para barbeiros não-líderes.
- Logo, um barbeiro normal abre a tela e a grade de horários **nunca aparece**, pois `_selectedBarber` permanece `null`.

O sistema usa `effectiveBarberId` para a lógica de agendamento (correto), mas **esquece de usar esse mesmo critério para exibir a grade**. Há uma inconsistência entre o `effectiveBarberId` (que funciona) e a condição de renderização da grade (que ainda depende de `_selectedBarber`).

---

### ✅ Como Corrigir

**Arquivo:** `lib/features/orders/presentation/create_appointment_screen.dart`

Localize a condição que envolve a grade de horários (bloco "4. Horários") e **substitua `_selectedBarber != null` por `effectiveBarberId != null`**:

**Antes:**
```dart
// 4. Horários
if (_selectedBarber != null) ...[
```

**Depois:**
```dart
// 4. Horários
if (effectiveBarberId != null) ...[
```

Essa mudança garante que:
- **Barbeiros comuns** verão a grade imediatamente ao abrir a tela (seu `barber_id` já está disponível via `userProfileProvider`).
- **Barbeiros Líderes e Admins** continuarão vendo a grade somente após selecionar um profissional (comportamento correto).

> ⚠️ **Atenção:** A variável `effectiveBarberId` já está declarada corretamente no `build()`:
> ```dart
> final String? effectiveBarberId = isLeader
>     ? (_selectedBarber?['id'] as String?)
>     : loggedInBarberId;
> ```
> Basta utilizá-la também na condição de visibilidade da grade.

---

## BUG #2 — Botão "Confirmar" (Salvar Agendamento) não funciona

### 🔍 Diagnóstico

O botão de confirmação na `bottomSheet` da `CreateAppointmentScreen` possui a seguinte condição de ativação:

```dart
onPressed: effectiveBarberId != null && _selectedTime != null && _totalPrice > 0 && !_isLoading
    ? _saveToSupabase
    : null,
```

Existem **dois problemas independentes** que mantêm o botão desabilitado:

---

#### Problema 2A — `effectiveBarberId` é `null` para barbeiros comuns (consequência do Bug #1)

Como demonstrado no Bug #1, `effectiveBarberId` permanece `null` para um barbeiro não-líder porque `_selectedBarber` nunca é definido. Mesmo que o usuário selecione horário e serviços, a condição `effectiveBarberId != null` falha, mantendo o botão cinza.

**A correção do Bug #1 já resolve parcialmente este problema.**

---

#### Problema 2B — Incompatibilidade de campos na inserção do `order_items`

Dentro de `_saveToSupabase()`, os `order_items` são inseridos com campos que **não batem com o schema do banco**:

**Código atual (incorreto):**
```dart
orderItemsToInsert.add({
  'order_id': orderId,
  'service_id': serviceId,       // ← campo não existe no schema!
  'service_name': service['name'], // ← campo não existe no schema!
  'price': (service['price'] as num).toDouble(), // ← campo não existe no schema!
  'quantity': 1,
});
```

**Schema real da tabela `order_items` (Supabase):**
```sql
CREATE TABLE public.order_items (
  id uuid,
  order_id uuid NOT NULL,
  item_type USER-DEFINED NOT NULL,  -- ← OBRIGATÓRIO
  reference_id uuid NOT NULL,        -- ← OBRIGATÓRIO
  name character varying NOT NULL,   -- ← OBRIGATÓRIO
  quantity integer DEFAULT 1,
  unit_price numeric NOT NULL,       -- ← OBRIGATÓRIO
  commission_pct numeric NOT NULL,   -- ← OBRIGATÓRIO
  commission_value numeric NOT NULL  -- ← OBRIGATÓRIO
);
```

O insert vai falhar silenciosamente (ou lançar exceção) porque:
- `item_type` (NOT NULL) não está sendo enviado.
- `reference_id` (NOT NULL) não está sendo enviado.
- `name` é o campo correto, mas o código envia `service_name`.
- `unit_price` é o campo correto, mas o código envia `price`.
- `commission_pct` e `commission_value` (NOT NULL) não estão sendo enviados.

O `catch(e)` captura o erro e exibe no SnackBar, mas como a inserção de `order_items` ocorre **após** a inserção da `order` (que pode ter sido bem-sucedida), o usuário pode estar vendo a navegação fechar sem o agendamento ter sido realmente completado, ou recebendo um erro vermelho.

---

### ✅ Como Corrigir

**Arquivo:** `lib/features/orders/presentation/create_appointment_screen.dart`

**Passo 1 — Corrija os campos do insert de `order_items`:**

Localize o trecho que monta `orderItemsToInsert` e substitua pelo código correto abaixo:

**Antes:**
```dart
orderItemsToInsert.add({
  'order_id': orderId,
  'service_id': serviceId,
  'service_name': service['name'],
  'price': (service['price'] as num).toDouble(),
  'quantity': 1,
});
```

**Depois:**
```dart
final servicePrice = (service['price'] as num).toDouble();
final commissionPct = (service['commission_pct'] as num?)?.toDouble() ?? 40.0;
final commissionValue = servicePrice * (commissionPct / 100);

orderItemsToInsert.add({
  'order_id': orderId,
  'item_type': 'service',          // tipo enum do banco
  'reference_id': serviceId,       // referência ao ID do serviço
  'name': service['name'],         // campo correto no schema
  'quantity': 1,
  'unit_price': servicePrice,      // campo correto no schema
  'commission_pct': commissionPct,
  'commission_value': commissionValue,
});
```

**Passo 2 — Aplique também a correção do Bug #1** (mudar `_selectedBarber != null` para `effectiveBarberId != null` na condição da grade), pois sem isso o `effectiveBarberId` continuará nulo para barbeiros comuns e o botão permanecerá desabilitado.

---

#### Verificação adicional: `userProfileProvider` retorna `barber_id` corretamente?

O provider busca o `barber_id` assim:

```dart
// lib/core/supabase/providers.dart
final barberData = await supabase
    .from('barbers')
    .select('id, category')
    .eq('user_id', user.id)
    .maybeSingle();

return {
  ...userData,
  'barber_id': barberData?['id'],
  'category': barberData?['category'] ?? userData['role'] ?? 'Gestor',
};
```

Isso depende de **existir um registro em `barbers` com `user_id` igual ao `id` do usuário logado**. Se o cadastro do barbeiro na tabela `barbers` estiver sem o campo `user_id` preenchido, o `barber_id` virá como `null` e o botão continuará desabilitado mesmo após as outras correções. Verifique no Supabase se todos os barbeiros têm o `user_id` preenchido corretamente.

---

## BUG #3 — Usuários "Barbeiro Líder" não recebem acesso total ao sistema

### 🔍 Diagnóstico

A lógica de permissão (`isLeader`) é verificada em dois lugares principais:

```dart
// lib/core/presentation/main_navigation.dart
final isLeader = user['category'] == 'Barbeiro Líder' || user['role'] == 'admin';

// lib/features/orders/presentation/create_appointment_screen.dart
final bool isLeader = userProfileAsync.maybeWhen(
  data: (user) => user['category'] == 'Barbeiro Líder' || user['role'] == 'admin',
  orElse: () => false,
);
```

O sistema espera que `user['category']` seja exatamente a string `'Barbeiro Líder'`. O valor vem da seguinte query no `userProfileProvider`:

```dart
final barberData = await supabase
    .from('barbers')
    .select('id, category')
    .eq('user_id', user.id)
    .maybeSingle();

return {
  ...userData,
  'category': barberData?['category'] ?? userData['role'] ?? 'Gestor',
};
```

Ao analisar o schema do banco de dados fornecido:

```sql
CREATE TABLE public.barbers (
  id uuid NOT NULL,
  user_id uuid,           -- ← PODE SER NULL
  category text NOT NULL,
  ...
);

CREATE TABLE public.users (
  id uuid NOT NULL,
  role USER-DEFINED NOT NULL,
  ...
);
```

Existem **três causas possíveis** para o acesso total não funcionar:

---

#### Causa 3A — `user_id` não está preenchido na tabela `barbers`

O campo `user_id` em `barbers` **permite NULL** (`user_id uuid` sem `NOT NULL`). Se o registro do Barbeiro Líder foi criado sem associar o `user_id`, a query `.eq('user_id', user.id).maybeSingle()` retornará `null`, e `category` cairá para o fallback `userData['role']`, que provavelmente não é `'Barbeiro Líder'`.

**Como verificar no Supabase:**
```sql
-- Execute no SQL Editor do Supabase
SELECT b.id, b.category, b.user_id, u.email, u.role
FROM barbers b
LEFT JOIN users u ON b.user_id = u.id
WHERE b.category = 'Barbeiro Líder';
```

Se a coluna `user_id` aparecer como `null` para algum registro, esse é o problema.

**Como corrigir no Supabase:**
```sql
-- Associe o user_id correto ao barbeiro líder
-- Substitua os valores pelos IDs reais
UPDATE barbers
SET user_id = '<uuid-do-usuario-na-tabela-users>'
WHERE id = '<uuid-do-barbeiro-lider>';
```

---

#### Causa 3B — Divergência no valor do campo `category` (capitalização ou espaço)

O sistema compara com `'Barbeiro Líder'` (com acento e letra maiúscula). Se o valor no banco foi cadastrado como `'barbeiro líder'`, `'Barbeiro Lider'` (sem acento), `'Barbeiro Líder '` (com espaço no final) ou qualquer variação, a comparação vai falhar.

**Como verificar:**
```sql
-- Veja os valores exatos cadastrados
SELECT DISTINCT category FROM barbers;
```

**Como corrigir (se houver divergência):**
```sql
-- Padronize todos os registros para o valor exato esperado pelo app
UPDATE barbers
SET category = 'Barbeiro Líder'
WHERE category ILIKE '%lider%' OR category ILIKE '%líder%';
```

---

#### Causa 3C — RLS (Row Level Security) bloqueando a leitura da tabela `barbers`

O repositório contém um arquivo `supabase_rls_fix.sql`, indicando que problemas de RLS já foram identificados antes. Se a política RLS da tabela `barbers` não permitir que um usuário leia seu próprio registro, a query retornará `null` e `category` não será preenchida.

**Como verificar no Supabase Dashboard:**
- Acesse **Authentication > Policies** e verifique as políticas da tabela `barbers`.
- Garanta que existe uma política `SELECT` que permita ao usuário ler o próprio registro.

**Política RLS recomendada para `barbers`:**
```sql
-- Permite que cada usuário leia seus próprios dados de barbeiro
CREATE POLICY "barbers_select_own"
ON public.barbers
FOR SELECT
USING (user_id = auth.uid());

-- Permite que admins leiam todos os registros
CREATE POLICY "barbers_select_admin"
ON public.barbers
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

---

### ✅ Resumo da Correção para o Bug #3

Execute os passos na seguinte ordem:

1. **Verificar valores no banco** — Rode o SQL de diagnóstico para confirmar qual das causas se aplica.
2. **Preencher `user_id` ausentes** — Associe corretamente os usuários aos seus registros em `barbers`.
3. **Padronizar o campo `category`** — Garanta que o valor seja exatamente `'Barbeiro Líder'`.
4. **Revisar políticas RLS** — Certifique-se de que a tabela `barbers` tem política `SELECT` ativa para o próprio usuário.
5. **Testar no app** — Faça logout e login novamente para forçar a recarga do `userProfileProvider` (que usa `autoDispose`).

---

## 📋 Resumo Executivo

| # | Bug | Arquivo Principal | Causa Raiz |
|---|-----|-------------------|-----------|
| 1 | Grade de horários não aparece | `create_appointment_screen.dart` | Condição `if (_selectedBarber != null)` ignora barbeiros não-líderes |
| 2 | Botão salvar não funciona | `create_appointment_screen.dart` | `effectiveBarberId` nulo (consequência do Bug #1) + campos errados no insert de `order_items` |
| 3 | Barbeiro Líder sem acesso total | Tabela `barbers` no Supabase | `user_id` nulo, `category` com valor divergente ou RLS bloqueando leitura |

---

## 🔗 Arquivos a Modificar

```
lib/
├── features/
│   └── orders/
│       └── presentation/
│           └── create_appointment_screen.dart  ← Bugs #1 e #2
Supabase SQL Editor                              ← Bug #3
```
