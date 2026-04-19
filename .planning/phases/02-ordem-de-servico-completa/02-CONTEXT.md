# Phase 2: Ordem de Serviço Completa - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** ROADMAP.md + codebase analysis

<domain>
## Phase Boundary

Implementar controle completo de ordem de serviço com:
1. **Itens da comanda** - rastrear cada serviço realizado com preço individual
2. **Produtos/Extras** - vender produtos (bebidas, pomadas, etc.) na mesma comanda
3. **Adicionais** - cobrar adicionais (extração, barba mais, etc.)

</domain>

<decisions>
## Implementation Decisions

### Data Model
- Criar tabela `order_items` com: id, order_id, service_id (nullable), product_id (nullable), service_name, product_name, price, quantity, created_at
- Não criar tabela separada de produtos ainda - usar `services` com type='product'
- Updates no checkout para calcular total a partir dos items

### Fluxo
1. Na criação da comanda, selecionar serviços da lista
2. Cada serviço vira um order_item
3. No checkout, adicionar produtos/extras
4. Total calculado da soma dos order_items

</decisions>

<canonical_refs>
## Canonical References

### Existing Code
- `lib/features/orders/presentation/checkout_screen.dart` — checkout atual, atualizar
- `lib/features/orders/presentation/create_appointment_screen.dart` — criação de comanda
- `lib/features/services/presentation/create_service_screen.dart` — serviços existentes
- `lib/core/supabase/providers.dart` — provedores

### Database
- `supabase_rls_fix.sql` — RLS policies (atualizar para order_items)
- Tabelas existentes: orders, services, barbers, users

</canonical_refs>

<specifics>
## Specific Ideas

### OS-01: Order Items
- Criar tabela `order_items` no Supabase
- Criar provider `orderItemsProvider`
- Modificar create_appointment_screen para criar order_items ao criar comanda
- Modificar checkout_screen para mostrar items individuais

### OS-02: Produtos/Extras
- Usar services com tipo 'product' ou criar tabela products
- No checkout, permitir adicionar produtos à comanda
- Atualizar total calculado

### OS-03: Adicionais Avulsos
- No checkout, permitir cobrar adicionais com nome e valor customizado
- Criar order_item com tipo 'extra'

### OS-04: Painel ADM de Produtos (CRUD)
- Criar tabela products com: id, unit_id, name, price, stock
- Provider productsProvider com CRUD completo
- ProductsManagementScreen com lista, adicionar, editar, deletar
- Indicador visual de estoque baixo (menos de 5)
- Link no menu de ADM

### OS-05: Ícone VIP na Agenda
- Verificar/adicionar campo is_vip na tabela clients
- Mostrar ícone coroa (Icons.workspace_premium) na schedule_screen para clientes VIP
- Coroa em dourado para destacar

### OS-06: Botão Voltar
- Adicionar AppBar com botão voltar na create_appointment_screen.dart
- Permitir usuário voltar para tela anterior

</specifics>

<deferred>
## Deferred Ideas

- Histórico de compra por cliente

</deferred>

---

*Phase: 02-ordem-de-servico-completa*
*Context gathered: 2026-04-15 via roadmap + codebase analysis*
