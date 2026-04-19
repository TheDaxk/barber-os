# Phase 2: Ordem de Serviço Completa

**Wave:** 1
**Depends on:** None
**Files modified:** lib/features/orders/, lib/core/supabase/

## Context

This phase implements complete service order control with line items, products, and extras. Currently orders only have a flat total - this phase adds itemized tracking.

---

## Tasks

### OS-01: Order Items Table & Provider

<read_first>
- lib/features/orders/presentation/create_appointment_screen.dart
- lib/features/orders/presentation/checkout_screen.dart
- lib/core/supabase/providers.dart
- supabase_rls_fix.sql
</read_first>

<action>
1. Criar tabela `order_items` no Supabase:
   ```sql
   CREATE TABLE order_items (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
     service_id UUID REFERENCES services(id),
     product_id UUID, -- reservado para futuro
     service_name TEXT NOT NULL,
     product_name TEXT,
     price DECIMAL(10,2) NOT NULL,
     quantity INTEGER DEFAULT 1,
     created_at TIMESTAMPTZ DEFAULT now()
   );
   ```

2. Adicionar RLS policy para order_items (mesma unidade da order)

3. Criar provider `orderItemsProvider` em `lib/features/orders/providers/order_items_provider.dart`:
   - fetchOrderItems(orderId)
   - addOrderItem(orderId, serviceId, serviceName, price, quantity)
   - removeOrderItem(itemId)
   - Função helper: calculateOrderTotal(orderId)

4. Modificar `create_appointment_screen.dart`:
   - Ao criar comanda, criar order_items para cada serviço selecionado
   - Passar order items para o checkout
</action>

<acceptance_criteria>
- [ ] Tabela order_items criada no Supabase
- [ ] RLS policy configurada
- [ ] orderItemsProvider implementado com CRUD
- [ ] order_items criados automaticamente na criação da comanda
</acceptance_criteria>

---

### OS-02: Produtos/Extras no Checkout

<read_first>
- lib/features/orders/presentation/checkout_screen.dart
- lib/features/orders/providers/order_items_provider.dart (se criado em OS-01)
- lib/features/services/presentation/create_service_screen.dart
</read_first>

<action>
1. Adicionar botão "Adicionar Produto" no checkout_screen.dart
2. Criar bottom sheet com lista de serviços do tipo 'product' ou criar query de produtos
3. Ao selecionar produto, criar order_item com tipo 'product'
4. Atualizar total em tempo real
5. Permitir remover itens com swipe ou botão X

6. Atualizar `checkout_screen.dart` para:
   - Mostrar lista de order_items (serviços e produtos)
   - Calcular total da soma dos items
   - Permitir adicionar/remover itens
</action>

<acceptance_criteria>
- [ ] Botão "Adicionar Produto" visível no checkout
- [ ] Lista de produtos disponível em bottom sheet
- [ ] Produtos adicionados como order_items
- [ ] Total atualizado em tempo real
- [ ] Itens podem ser removidos
</acceptance_criteria>

---

### OS-03: Adicionais Avulsos

<read_first>
- lib/features/orders/presentation/checkout_screen.dart
</read_first>

<action>
1. Adicionar seção "Adicionar Extra" no checkout
2. Input para nome do extra e valor
3. Ao confirmar, criar order_item com service_name = nome do extra, price = valor
4. Mostrar extras na lista de itens

5. Adicionar em checkout_screen.dart:
   - Campo texto para nome do adicional
   - Campo numérico para valor
   - Botão "Adicionar"
   - Validação de campos obrigatórios
</action>

<acceptance_criteria>
- [ ] Seção de adicionais visível no checkout
- [ ] Nome e valor do adicional podem ser inseridos
- [ ] Adicional adicionado à lista de items
- [ ] Total inclui adicionais
</acceptance_criteria>

---

### OS-04: Painel ADM de Produtos (CRUD Completo)

<read_first>
- lib/features/services/presentation/create_service_screen.dart
- lib/features/settings/menu_screen.dart
- lib/core/supabase/providers.dart
</read_first>

<action>
1. Criar tabela `products` no Supabase:
   ```sql
   CREATE TABLE products (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     unit_id UUID NOT NULL REFERENCES units(id),
     name TEXT NOT NULL,
     price DECIMAL(10,2) NOT NULL,
     stock INTEGER DEFAULT 0,
     created_at TIMESTAMPTZ DEFAULT now(),
     updated_at TIMESTAMPTZ DEFAULT now()
   );
   ```

2. Adicionar RLS policies para products (mesma unidade)

3. Criar provider `productsProvider` em `lib/features/products/providers/products_provider.dart`:
   - fetchProducts()
   - addProduct(name, price, stock)
   - updateProduct(id, name, price, stock)
   - deleteProduct(id)
   - decrementStock(productId, quantity)

4. Criar `ProductsManagementScreen` em `lib/features/products/presentation/products_management_screen.dart`:
   - Lista de produtos com nome, preço, estoque
   - Botão para adicionar novo produto
   - Botão para editar produto existente
   - Swipe para deletar
   - Indicador visual de estoque baixo (menos de 5 unidades)

5. Adicionar link no menu de ADM (settings/menu_screen.dart):
   - Seção "Gestão de Produtos"
   - Navegar para ProductsManagementScreen
</action>

<acceptance_criteria>
- [ ] Tabela products criada no Supabase com RLS
- [ ] Provider productsProvider implementado
- [ ] ProductsManagementScreen funcional com CRUD completo
- [ ] Link no menu de ADM
- [ ] Indicador visual de estoque baixo
</acceptance_criteria>

---

### OS-05: Ícone VIP na Tela de Agendamento

<read_first>
- lib/features/orders/presentation/schedule_screen.dart
- lib/features/clients/ (verificar estrutura de clientes)
</read_first>

<action>
1. Verificar se existe campo `is_vip` ou similar na tabela de clientes
   - Se não existir, adicionar coluna `is_vip BOOLEAN DEFAULT false` na tabela clients

2. Modificar schedule_screen.dart:
   - Na lista de clientes/agendamentos, verificar campo `is_vip`
   - Se cliente for VIP, mostrar ícone de coroa (Icons.workspace_premium ou Icons.star) ao lado do nome
   - Coroa em dourado/amarelo para destacar

3. Exemplo de implementação:
   ```dart
   Row(
     children: [
       Text(clientName),
       if (client['is_vip'] == true) ...[
         SizedBox(width: 4),
         Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
       ],
     ],
   )
   ```
</action>

<acceptance_criteria>
- [ ] Campo is_vip existe na tabela clients
- [ ] Clientes VIP mostram ícone de coroa na schedule_screen
- [ ] Coroa visível e destacada (dourada)
</acceptance_criteria>

---

### OS-06: Botão Voltar na Tela de Novo Agendamento

<read_first>
- lib/features/orders/presentation/create_appointment_screen.dart
- lib/features/orders/presentation/schedule_screen.dart
</read_first>

<action>
1. Abrir `create_appointment_screen.dart`

2. Adicionar AppBar com botão de voltar:
   ```dart
   AppBar(
     title: Text('Novo Agendamento'),
     leading: IconButton(
       icon: Icon(Icons.arrow_back),
       onPressed: () => Navigator.pop(context),
     ),
   )
   ```

3. OU adicionar botão "Cancelar" ou "Voltar" no final do formulário

4. Verificar se todas as navegações para esta tela usam Navigator.push
</action>

<acceptance_criteria>
- [ ] Usuário pode voltar da tela de novo agendamento
- [ ] AppBar com botão voltar visível
- [ ] Botão funcional (navega para tela anterior)
</acceptance_criteria>

---

## Verification

### must_haves (Goal Backward)
1. ✅ Comandas têm itens individualizados (não só total flat)
2. ✅ Produtos podem ser adicionados na comanda
3. ✅ Extras avulsos podem ser cobrados
4. ✅ Total calculado corretamente a partir dos items
5. ✅ Checkout mostra breakdown de todos os itens
6. ✅ Painel ADM de produtos com estoque e valores
7. ✅ Clientes VIP mostram coroa na agenda
8. ✅ Tela de agendamento tem botão voltar
