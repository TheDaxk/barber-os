# BarberOS - Sistema de Barbearia

**Last updated:** 2026-04-15 after initialization

## What This Is

BarberOS é um sistema de gestão para barbearias construído com Flutter e Supabase. Gerencia comandas, agendamentos, clientes, equipe, serviços e relatórios financeiros.

## Core Value

Sistema completo de gestão operacional para barbearias com foco em:
- Acompanhamento em tempo real de comandas
- Gestão de equipe e comissões
- Relatórios financeiros
- Interface mobile-first para uso no salão

## Requirements

### Validated

- ✓ Autenticação com Supabase Auth - existente
- ✓ Dashboard com KPIs operacionais - existente
- ✓ Gestão de profissionais (CRUD) - existente
- ✓ Gestión de servicios - existente
- ✓ Comandas (abrir/fechar) - existente
- ✓ Tela de login - existente

### Active

- [ ] Nova Comanda - implementar navegação e criação
- [ ] Agendamento de clientes - implementar sistema de agenda
- [ ] Lista de espera - implementar gerenciamento de clientes em espera
- [ ] Relatório rápido - implementar geração de relatórios
- [ ] Configurações da unidade - horário de funcionamento
- [ ] Reset de senha - implementar fluxo de recuperação
- [ ] Top Serviços por barbeiro - implementar cálculo e exibição
- [ ] Sistema de notificações - implementar notificações push

### Out of Scope

- [App multi-unidade] — Uma unidade por vez
- [Delivery/Pickup] — Não aplicável a barbearias
- [Inventário de produtos] — Apenas serviços

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter + Supabase | Stack atual | Mantido |
| Riverpod | State management | Mantido |
| Portuguese (BR) | Idioma do negócio | Mantido |
| Dark theme | Preferência visual | Mantido |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
