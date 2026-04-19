# Agent Task File — BarberOS / Ian
# Tasks independentes prontas para execução

> Este arquivo foi escrito para ser consumido diretamente por um agente de IA (Claude Code, Cursor, etc.).
> Cada task é autossuficiente: contém contexto, localização exata, o que mudar, como mudar e como validar.
> Execute uma task por vez. Não pule etapas de validação.

---

## CONVENÇÕES DO PROJETO (leia antes de qualquer task)

- **Framework:** Flutter + Riverpod + Supabase
- **Padrão de widget com provider:** `ConsumerStatefulWidget` / `ConsumerWidget`
- **Padrão de leitura de provider:** `ref.watch(provider)` no build, `ref.read(provider)` em callbacks
- **Padrão de estado assíncrono:** sempre usar `.when(loading, error, data)` ou `.maybeWhen`
- **Cores do tema (usar estas, não inventar outras):**
  - Background card: `Colors.grey[900]` ou `const Color(0xFF1A1A1A)`
  - Background elevated: `const Color(0xFF242424)`
  - Border sutil: `Colors.white10`
  - Texto primário: `Colors.white` / `const Color(0xFFF5F5F5)`
  - Texto secundário: `Colors.grey[400]` / `const Color(0xFF888888)`
  - Accent success: `Colors.greenAccent`
  - Accent danger: `Colors.redAccent`
  - Accent warning: `Colors.orangeAccent`
  - Accent info: `Colors.blueAccent`
  - Accent dourado: `const Color(0xFFD4AF37)`
- **Border radius padrão:** `BorderRadius.circular(16)` para cards, `BorderRadius.circular(12)` para inputs e chips
- **Não usar `Colors.green` diretamente em KPIs** — usar `Colors.greenAccent`
- **Imports:** nunca usar import com caminho absoluto de pacote interno; usar caminhos relativos

---

## TASK I-05 — Ajustar cartões da tela de Unidades

### Contexto
A `UnitsListScreen` exibe unidades em um `GridView` com `childAspectRatio: 0.85`, que gera cards altos demais. O objetivo é tornar os cards mais compactos para caber mais conteúdo sem scroll excessivo.

### Arquivo alvo
```
lib/features/units/presentation/units_list_screen.dart
```

### Localização exata da mudança
Dentro da classe `UnitsListScreen`, no método `build`, no bloco `data: (units)`, há um `GridView.builder`. O delegate atual é:

```dart
// CÓDIGO ATUAL — localizar exatamente isto:
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 0.85,
),
```

### O que substituir

```dart
// SUBSTITUIR POR:
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 1.15,
),
```

### Segunda mudança — padding interno do _UnitCard
Na classe `_UnitCard`, no método `build`, há um `Padding` com `padding: const EdgeInsets.all(12)`. Manter este valor — ele já está adequado para o novo tamanho.

### Terceira mudança — ícone do card
Ainda em `_UnitCard`, o `Container` do ícone tem `padding: const EdgeInsets.all(8)` e `size: 20`. Reduzir o ícone para deixar o card mais leve:

```dart
// CÓDIGO ATUAL:
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.green.withOpacity(0.2),
    borderRadius: BorderRadius.circular(8),
  ),
  child: const Icon(Icons.business, color: Colors.green, size: 20),
),

// SUBSTITUIR POR:
Container(
  padding: const EdgeInsets.all(6),
  decoration: BoxDecoration(
    color: Colors.green.withOpacity(0.15),
    borderRadius: BorderRadius.circular(8),
  ),
  child: const Icon(Icons.business, color: Colors.green, size: 18),
),
```

### Não mexer
- Lógica de `barbersAsync` e exibição do responsável
- Navegação (`Navigator.push` para `UnitDetailScreen`)
- `FloatingActionButton`
- Verificação de `isLeader`

### Validação esperada
- [ ] Hot reload após a mudança — cards devem aparecer visivelmente menores em altura
- [ ] Com 2 unidades cadastradas: ambos os cards devem aparecer sem precisar rolar a tela em dispositivo com 375px de largura
- [ ] O nome da unidade não pode fazer overflow — já tem `maxLines: 1, overflow: TextOverflow.ellipsis`, confirmar que permanece
- [ ] Não deve haver `RenderFlex overflowed` no console

---

## TASK I-03 — Adicionar filtro de categoria nas despesas

### Contexto
A `FinancialScreen` já exibe uma lista de despesas do mês usando `monthlyExpensesProvider`. Cada despesa tem um campo `category` (string) com valores como `'Aluguel'`, `'Produtos'`, `'Energia'`, etc. A lista `_expenseCategories` já existe na classe com ícones e cores para cada categoria. O objetivo é adicionar chips de filtro acima da lista de despesas para o usuário filtrar por categoria.

### Arquivo alvo
```
lib/features/reports/presentation/financial_screen.dart
```

### Passo 1 — Adicionar variável de estado

Na classe `_FinancialScreenState`, adicionar a variável de filtro logo após as declarações existentes de `_monthNames` e `_expenseCategories`:

```dart
// ADICIONAR após a declaração de _expenseCategories:
String? _selectedExpenseCategory; // null = sem filtro (exibe todas)
```

### Passo 2 — Localizar o bloco de despesas no build

No método `build` da classe `_FinancialScreenState`, localizar este trecho exato:

```dart
// LOCALIZAR:
const SizedBox(height: 32),
const Text('Despesas do Mês', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 12),
expensesAsync.when(
```

### Passo 3 — Inserir os chips de filtro

Substituir o bloco localizado no Passo 2 por:

```dart
const SizedBox(height: 32),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text('Despesas do Mês', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    if (_selectedExpenseCategory != null)
      TextButton(
        onPressed: () => setState(() => _selectedExpenseCategory = null),
        child: const Text('Limpar filtro', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
  ],
),
const SizedBox(height: 10),
SizedBox(
  height: 36,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _expenseCategories.length,
    separatorBuilder: (_, __) => const SizedBox(width: 8),
    itemBuilder: (context, index) {
      final cat = _expenseCategories[index];
      final isSelected = _selectedExpenseCategory == cat['id'];
      final catColor = Color(cat['color'] as int);
      return GestureDetector(
        onTap: () => setState(() {
          _selectedExpenseCategory = isSelected ? null : cat['id'] as String;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? catColor.withOpacity(0.2) : Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? catColor : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(cat['icon'] as IconData, size: 13, color: isSelected ? catColor : Colors.grey),
              const SizedBox(width: 5),
              Text(
                cat['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? catColor : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
),
const SizedBox(height: 12),
expensesAsync.when(
```

### Passo 4 — Aplicar o filtro na lista de despesas

Dentro do bloco `expensesAsync.when`, na callback `data: (expenses)`, localizar:

```dart
// LOCALIZAR (início do data callback):
data: (expenses) {
  if (expenses.isEmpty) {
```

Substituir por:

```dart
data: (expenses) {
  // Aplicar filtro por categoria se selecionado
  final filteredExpenses = _selectedExpenseCategory == null
      ? expenses
      : expenses.where((e) => e['category']?.toString() == _selectedExpenseCategory).toList();

  if (filteredExpenses.isEmpty) {
```

Em seguida, **em todo o restante do `data` callback**, substituir todas as referências a `expenses` por `filteredExpenses`. As ocorrências são:

1. `if (expenses.isEmpty)` → já substituído acima para `filteredExpenses.isEmpty`
2. `itemCount: expenses.length,` → `itemCount: filteredExpenses.length,`
3. `final exp = expenses[index];` → `final exp = filteredExpenses[index];`

### Não mexer
- A lógica de cálculo de `despesas` (total) no início do `build` — ela deve continuar usando a lista completa sem filtro, para o KPI de Despesas não ser afetado pelo filtro visual
- O bottom sheet de nova despesa (`_showExpenseBottomSheet`)
- Os outros providers (`monthlyRevenueProvider`)

### Validação esperada
- [ ] Chips de categoria aparecem em scroll horizontal acima da lista de despesas
- [ ] Tocar em "Aluguel" → lista mostra apenas despesas com `category == 'Aluguel'`
- [ ] Tocar no mesmo chip novamente → filtro limpa, todas as despesas voltam
- [ ] Botão "Limpar filtro" aparece no header apenas quando alguma categoria está selecionada; ao tocar, limpa o filtro
- [ ] O card de KPI "Despesas" no topo da tela **não muda** ao filtrar — ele sempre mostra o total real
- [ ] Com filtro ativo e nenhuma despesa naquela categoria: exibe a mensagem de "Nenhuma despesa lançada neste mês"
- [ ] Não há erros de `setState called after dispose` no console

---

## TASK I-02 — Redesenhar os cartões KPI do Financeiro

### Contexto
A `FinancialScreen` tem 4 KPI cards gerados pelo método `_buildSmallCard`. Atualmente são containers simples com título e valor. O objetivo é torná-los mais informativos: adicionar ícone representativo, manter título e valor, e adicionar uma linha de cor lateral (accent bar) para diferenciar visualmente cada card.

Os valores calculados já existem no `build`:
- `faturamento` (double)
- `comissoes` (double) — calculada como `faturamento * 0.40`
- `despesas` (double)
- `ticketMedio` (double)

### Arquivo alvo
```
lib/features/reports/presentation/financial_screen.dart
```

### Passo 1 — Localizar a chamada dos cards no build

No método `build`, localizar o `GridView.count` que chama `_buildSmallCard`:

```dart
// LOCALIZAR:
GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 1.8,
  children: [
    _buildSmallCard('Faturamento', faturamento, Colors.greenAccent),
    _buildSmallCard('Comissões (40%)', comissoes, Colors.orangeAccent),
    _buildSmallCard('Despesas', despesas, Colors.redAccent),
    _buildSmallCard('Ticket Médio', ticketMedio, Colors.blueAccent),
  ],
),
```

### Passo 2 — Substituir pelo novo GridView com ícones

```dart
// SUBSTITUIR POR:
GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 1.6,
  children: [
    _buildKpiCard(
      title: 'Faturamento',
      value: faturamento,
      icon: Icons.trending_up_rounded,
      accentColor: Colors.greenAccent,
    ),
    _buildKpiCard(
      title: 'Comissões (40%)',
      value: comissoes,
      icon: Icons.handshake_outlined,
      accentColor: Colors.orangeAccent,
    ),
    _buildKpiCard(
      title: 'Despesas',
      value: despesas,
      icon: Icons.receipt_long_outlined,
      accentColor: Colors.redAccent,
    ),
    _buildKpiCard(
      title: 'Ticket Médio',
      value: ticketMedio,
      icon: Icons.confirmation_number_outlined,
      accentColor: Colors.blueAccent,
    ),
  ],
),
```

### Passo 3 — Adicionar o novo método _buildKpiCard

Localizar o método `_buildSmallCard` existente:

```dart
// LOCALIZAR:
Widget _buildSmallCard(String title, double amount, Color accentColor) {
  return Container(
    padding: const EdgeInsets.all(16),
    ...
  );
}
```

**Manter o `_buildSmallCard` existente** (pode ser que ainda seja usado em outro lugar ou em testes futuros). Adicionar o novo método **logo acima** de `_buildSmallCard`:

```dart
Widget _buildKpiCard({
  required String title,
  required double value,
  required IconData icon,
  required Color accentColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10),
    ),
    child: Stack(
      children: [
        // Barra de accent lateral
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
        ),
        // Conteúdo
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                'R\$ ${value.toStringAsFixed(2)}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

### Não mexer
- O método `_buildMainCard` (card grande de Lucro Estimado)
- A lógica de cálculo de `faturamento`, `comissoes`, `despesas`, `ticketMedio`
- O seletor de mês
- O `FloatingActionButton`
- Os providers

### Validação esperada
- [ ] 4 cards aparecem no grid com ícone + título + valor formatado em R$
- [ ] Cada card tem uma barra colorida fina no lado esquerdo com a cor correspondente
- [ ] Nenhum card faz overflow de texto (testar com valor grande como `R$ 99999.99`)
- [ ] Em tela de 375px de largura, os 4 cards cabem no grid sem distorção
- [ ] Os valores dos cards batem com o card principal de Lucro Estimado (faturamento - comissoes - despesas)
- [ ] Sem erros de compilação ou warnings de tipo no `flutter analyze`

---

## TASK I-04 — Lista de receitas na aba Financeiro

### Contexto
A `FinancialScreen` mostra KPIs de faturamento mas não exibe as ordens individuais. O `monthlyRevenueProvider` já retorna todas as ordens fechadas do mês com os campos necessários. O objetivo é adicionar uma seção "Receitas do Mês" abaixo da seção de despesas, listando cada ordem com: data, nome do cliente, forma de pagamento, barbeiro que executou e valor.

### Estrutura de dados disponível
O `monthlyRevenueProvider` retorna `List<Map<String, dynamic>>` onde cada item tem:
```
order['id']               → String (UUID)
order['total']            → num (double)
order['closed_at']        → String (ISO 8601, ex: "2025-06-15T14:32:00")
order['client_name']      → String
order['payment_method']   → String (ex: 'pix', 'credit_card', 'debit_card', 'cash')
order['barbers']          → Map — resultado do join
order['barbers']['users'] → Map — resultado do join aninhado
order['barbers']['users']['name'] → String — nome do barbeiro
```

**Atenção ao acesso aninhado:** o join do Supabase retorna `barbers` como um Map (não uma List), porque é uma relação `many-to-one`. Acessar assim:
```dart
final barberName = (order['barbers']?['users']?['name'] as String?) ?? 'Não informado';
```

### Mapeamento de `payment_method` para label legível
Usar esta função auxiliar (adicionar no arquivo):
```dart
String _paymentLabel(String? method) {
  switch (method) {
    case 'pix': return 'Pix';
    case 'credit_card': return 'Cartão de Crédito';
    case 'debit_card': return 'Cartão de Débito';
    case 'cash': return 'Dinheiro';
    default: return method ?? 'Não informado';
  }
}
```

### Arquivo alvo
```
lib/features/reports/presentation/financial_screen.dart
```

### Passo 1 — Adicionar o método auxiliar

Adicionar o método `_paymentLabel` dentro da classe `_FinancialScreenState`, logo antes do método `build`:

```dart
String _paymentLabel(String? method) {
  switch (method) {
    case 'pix': return 'Pix';
    case 'credit_card': return 'Cartão de Crédito';
    case 'debit_card': return 'Cartão de Débito';
    case 'cash': return 'Dinheiro';
    default: return method ?? 'Não informado';
  }
}
```

### Passo 2 — Localizar o fim da seção de despesas no build

No método `build`, localizar este trecho **no final** da lista de widgets do `SingleChildScrollView`:

```dart
// LOCALIZAR:
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
```

### Passo 3 — Inserir a seção de receitas antes do SizedBox(height: 80)

Substituir o trecho localizado por:

```dart
              // ---- SEÇÃO DE RECEITAS ----
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Receitas do Mês', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (revenueAsync.hasValue)
                    Text(
                      '${revenueAsync.value!.length} atendimento(s)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              revenueAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Erro: $err', style: const TextStyle(color: Colors.red)),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text(
                        'Nenhum atendimento registrado neste mês.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  // Ordenar do mais recente para o mais antigo
                  final sortedOrders = [...orders]..sort((a, b) {
                    final dateA = DateTime.tryParse(a['closed_at']?.toString() ?? '') ?? DateTime(2000);
                    final dateB = DateTime.tryParse(b['closed_at']?.toString() ?? '') ?? DateTime(2000);
                    return dateB.compareTo(dateA);
                  });

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedOrders.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Colors.white10,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final order = sortedOrders[index];

                        final total = (order['total'] as num?)?.toDouble() ?? 0.0;
                        final clientName = order['client_name']?.toString() ?? 'Cliente';
                        final paymentMethod = _paymentLabel(order['payment_method']?.toString());
                        final barberName = (order['barbers']?['users']?['name'] as String?) ?? 'Não informado';

                        String dateStr = '';
                        if (order['closed_at'] != null) {
                          final dt = DateTime.tryParse(order['closed_at'].toString())?.toLocal();
                          if (dt != null) {
                            dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          }
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.attach_money, color: Colors.greenAccent, size: 20),
                          ),
                          title: Text(
                            clientName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '✂️ $barberName',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$paymentMethod • $dateStr',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            'R\$ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              // ---- FIM DA SEÇÃO DE RECEITAS ----
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
```

### Não mexer
- Os KPI cards no topo
- A seção de despesas (incluindo filtro de I-03, se já implementado)
- O `_buildMainCard` de Lucro Estimado
- Os providers — não alterar `monthlyRevenueProvider`
- O `FloatingActionButton`

### Validação esperada
- [ ] Seção "Receitas do Mês" aparece abaixo da seção de despesas
- [ ] Cada linha mostra: nome do cliente, nome do barbeiro com ✂️, forma de pagamento legível, data formatada, e valor em verde
- [ ] Ordens ordenadas da mais recente para a mais antiga
- [ ] Mês sem ordens fechadas → mensagem "Nenhum atendimento registrado neste mês."
- [ ] Ao navegar para um mês diferente (setas de navegação), a lista atualiza corretamente
- [ ] `flutter analyze` sem erros de tipo
- [ ] Verificar acesso `order['barbers']?['users']?['name']` — se retornar null para alguma ordem, deve exibir "Não informado" sem quebrar

---

## ORDEM RECOMENDADA DE EXECUÇÃO

```
1. I-05  →  units_list_screen.dart   (mudança cirúrgica, baixo risco, valida o setup)
2. I-03  →  financial_screen.dart    (adiciona estado + chips, não altera lógica existente)
3. I-02  →  financial_screen.dart    (redesign dos KPIs, mesmo arquivo de I-03)
4. I-04  →  financial_screen.dart    (adiciona seção nova, integra com provider já existente)
```

Fazer I-03 antes de I-02 é mais seguro: ambas mexem no mesmo arquivo, mas I-03 é uma adição limpa enquanto I-02 mexe nos métodos existentes. Assim o risco de conflito de edição é menor.

---

## CHECKLIST DE ENTREGA FINAL

Antes de considerar as 4 tasks concluídas:

- [ ] `flutter analyze lib/` sem erros
- [ ] `flutter run --debug` sobe sem crash
- [ ] Testar `FinancialScreen` em dispositivo/emulador 375px largura (iPhone SE)
- [ ] Testar `UnitsListScreen` com ao menos 2 unidades cadastradas
- [ ] Navegar entre meses no Financeiro e verificar que filtro de despesas reseta (ou mantém — definir comportamento desejado)
- [ ] Nenhum `setState called after dispose` no console
- [ ] Nenhum `RenderFlex overflowed` nos novos cards
