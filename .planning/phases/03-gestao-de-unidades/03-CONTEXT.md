# Phase 3: Gestão de Unidades - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** User requirements via /gsd-plan-phase

<domain>
## Phase Boundary

Implementar CRUD completo de unidades com responsável automático por hierarquia de barbeiros, visualização financeira por unidade (Barbeiro Líder), e controle de acesso a agendamentos baseado no perfil.

</domain>

<decisions>
## Implementation Decisions

### UN-01: Cadastro de Unidades
- CRUD completo: criar, editar, excluir unidades
- Campos: localização (endereço), telefone, responsável (automático via lógica de hierarquia)
- Responsável NÃO é campo editável — é calculado automaticamente pela hierarquia

### UN-02: Hierarquia de Responsável
- O barbeiro de MAIOR cargo na unidade é o responsável
- Ordem hierárquica: Barbeiro Líder > Barbeiro Pro Max > Barbeiro Pro > Barbeiro
- O campo `responsável` na unidade é um campo computed/exibição — não editing direto
- Se não há barbeiros na unidade, responsável fica vazio/null

### UN-03: Visualização Financeira por Unidade
- Barbeiro Líder acessa cada unidade individualmente
- Ver métricas financeiras: faturamento, comissões, comandas fechadas/abertas
- Não-líderes só veem dados da unidade que estão atribuídos

### UN-04: Controle de Agendamentos por Perfil
- Barbeiro Líder: vê TODOS os agendamentos da unidade
- Barbeiros não-líderes: veem apenas OS PROPRIOS agendamentos
- Implementado via filtro no provider/supabase query

### UN-05: Tela de Detalhes da Unidade
- Lista de unidades na tela de gestão
- Ao clicar em uma unidade, abre tela de detalhes
- Mostra: info da unidade, métricas financeiras, lista de agendamentos (filtrado por perfil)

</decisions>

<canonical_refs>
## Canonical References

### Existing Code
- `lib/features/settings/unit_settings_screen.dart` — configurações de unidade existentes
- `lib/features/dashboard/providers/dashboard_provider.dart` — lógica de filtragem por unidade e perfil
- `lib/core/supabase/providers.dart` — providers de autenticação e dados
- `lib/features/orders/presentation/create_appointment_screen.dart` — criação de agendamentos

### Database
- Tabela `units` já existe
- Tabela `barbers` com campo `category` (hierarquia)
- Tabela `orders` com `unit_id` e `barber_id`

</canonical_refs>

<specifics>
## Specific Ideas

### UI/UX
- Grid de unidades na tela principal de gestão
- Cada card de unidade mostra: nome, localização, telefone, responsável atual
- Indicador visual de qual unidade está selecionada
- Tela de detalhes com tabs: Info | Financeiro | Agendamentos

### Hierarquia de Cargos
```
Barbeiro Líder      (maior)
Barbeiro Pro Max
Barbeiro Pro
Barbeiro            (menor)
```

### Filtros por Perfil
- Query de orders já tem `isLeader` check
- Implementar filtro `unit_id` para限制 acesso
- Barbeiros não-líderes: `eq('barber_id', userProfile['barber_id'])`
- Barbeiros líderes: sem filtro de barber_id (veem todos)

</specifics>

<deferred>
## Deferred Ideas

- Histórico financeiro por período (dia/semana/mês) por unidade
- Comparativo entre unidades

---

*Phase: 03-gestao-de-unidades*
*Context gathered: 2026-04-15 via user requirements*