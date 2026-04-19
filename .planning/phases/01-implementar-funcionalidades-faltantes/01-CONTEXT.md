# Phase 1: Implementar Funcionalidades Faltantes - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Codebase analysis + GSD workflow

<domain>
## Phase Boundary

Implementar todas as funcionalidades que estão marcadas como "em desenvolvimento" ou "em breve" no código atual:

1. **Nova Comanda** - Navegação e criação de nova comanda a partir do dashboard
2. **Agendar Cliente** - Sistema de agendamento com agenda
3. **Ver Espera** - Lista de clientes em espera
4. **Relatório Rápido** - Geração de relatórios direto do dashboard
5. **Configurações da Unidade** - Horário de funcionamento
6. **Reset de Senha** - Recuperação de senha via email
7. **Top Serviços** - Ranking de serviços por barbeiro
8. **Notificações** - Sistema de notificações push

</domain>

<decisions>
## Implementation Decisions

### Dashboard Quick Actions
- Nova Comanda deve abrir form para criar comanda com cliente, barbeiro, serviços
- Agendar Cliente deve abrir tela de agenda com horários disponíveis
- Ver Espera deve mostrar lista de clientes aguardando
- Relatório Rápido deve gerar PDF/print do dia

### Autenticação
- Reset de senha via Supabase Auth (email)
- Template de email de reset

### Configurações
- Horário de funcionamento salvo em tabela `units`
- Dias da semana com horários de abertura/fechamento

### Métricas
- Top serviços calculado a partir de `order_items`
- Necessário verificar se `order_items` existe no schema

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Patterns
- `lib/features/orders/presentation/create_order_screen.dart` — existente, usar como base para nova comanda
- `lib/features/auth/presentation/login_screen.dart` — padrão de auth
- `lib/features/dashboard/presentation/home_screen.dart` — local dos TODOs
- `lib/features/settings/menu_screen.dart` — configurações existentes
- `lib/features/team/presentation/employee_details_screen.dart` — métricas de barbeiro
- `lib/features/reports/presentation/financial_screen.dart` — relatórios existentes

### Database
- `supabase_rls_fix.sql` — schema do banco, tabelas `orders`, `order_items`, `users`, `barbers`, `units`

### Config
- `lib/core/supabase/providers.dart` — provedores Supabase

</canonical_refs>

<specifics>
## Specific Ideas

### Nova Comanda (FE-01)
- Criar screen `CreateOrderScreen` se não existir
- Navegar de `home_screen.dart` -> `CreateOrderScreen`
- Campos: cliente (nome/telefone), barbeiro (dropdown), serviços (multi-select), observações
- Após criar, redirecionar para tela da comanda

### Agendar Cliente (FE-02)
- Criar screen `ScheduleScreen` com calendário
- Mostrar horários disponíveis por barbeiro
- Integração com `orders` com `start_time` e `status`

### Ver Espera (FE-03)
- Criar screen `WaitingListScreen`
- Lista de clientes aguardando atendimento
- Botão para chamar próximo da fila

### Relatório Rápido (FE-04)
- Gerar resumo do dia: faturamento, comandas, comissões
- Opção de imprimir ou compartilhar

### Configurações da Unidade (FE-05)
- Criar `UnitSettingsScreen`
- Editar horários de funcionamento por dia da semana
- Salvar em `units` table

### Reset de Senha (FE-06)
- Link "Esqueci minha senha" na tela de login
- Enviar email via Supabase Auth
- Screen para novo password

### Top Serviços (FE-07)
- Query aggregation em `order_items`
- Agrupar por `service_id`, contar, ordenar desc
- Mostrar top 3 por barbeiro no `EmployeeDetailsScreen`

### Sistema de Notificações (FE-08)
- Firebase Cloud Messaging ou local notifications
- Lembretes de agendamento

</specifics>

<deferred>
## Deferred Ideas

- Notificações push (FE-08) requer Firebase setup
- Sistema de espera completo pode esperar Phase 2

</deferred>

---

*Phase: 01-implementar-funcionalidades-faltantes*
*Context gathered: 2026-04-15 via codebase analysis*
