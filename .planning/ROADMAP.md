# BarberOS Roadmap

## Phase 1: Implementar Funcionalidades Faltantes

**Goal:** Implementar todas as telas e funcionalidades marked as "em desenvolvimento" ou "em breve"

**Phase requirement IDs:** FE-01, FE-02, FE-03, FE-04, FE-05, FE-06, FE-07, FE-08

### FE-01: Nova Comanda
Criar nova comanda a partir do dashboard
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/orders/`
- **Priority:** alta

### FE-02: Agendamento de Clientes
Sistema de agenda para agendar clientes
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/orders/presentation/schedule_screen.dart`
- **Priority:** alta

### FE-03: Lista de Espera
Gerenciar clientes em espera
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/orders/presentation/waiting_list_screen.dart`
- **Priority:** média

### FE-04: Relatório Rápido
Geração rápida de relatórios do dia
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/reports/presentation/quick_report_screen.dart`
- **Priority:** média

### FE-05: Configurações da Unidade
Horário de funcionamento e configurações da barbearia
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/settings/unit_settings_screen.dart`
- **Priority:** baixa

### FE-06: Reset de Senha
Fluxo de recuperação de senha
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/auth/presentation/forgot_password_screen.dart`
- **Priority:** média

### FE-07: Top Serviços
Ranking dos serviços mais prestados por barbeiro
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/features/team/providers/barber_metrics_provider.dart`
- **Priority:** baixa

### FE-08: Sistema de Notificações
Notificações push para lembretes
- **Status:** ✅ Done (Phase 1)
- **Files:** `lib/core/services/notification_service.dart`
- **Priority:** baixa

## Phase 2: Ordem de Serviço Completa

**Goal:** Implementar controle completo de ordem de serviço com itens, produtos e adicionais

**Phase requirement IDs:** OS-01, OS-02, OS-03, OS-04, OS-05, OS-06

### OS-01: Order Items
Implementar tabela order_items e provider para rastrear cada serviço realizado
- **Status:** Planned

### OS-02: Produtos/Extras
Permitir adicionar produtos e extras na comanda durante checkout
- **Status:** Planned

### OS-03: Adicionais Avulsos
Cobrar adicionais avulsos no checkout
- **Status:** Planned

### OS-04: Painel ADM de Produtos
CRUD completo de produtos com nome, preço e estoque. Indicador de estoque baixo.
- **Status:** Planned

### OS-05: Ícone VIP na Agenda
Mostrar coroa para clientes VIP na tela de agendamento
- **Status:** Planned

### OS-06: Botão Voltar
Adicionar botão voltar na tela de novo agendamento
- **Status:** Planned

## Phase 3: Gestão de Unidades

**Goal:** Implementar CRUD de unidades com responsável automático por hierarquia, visualização financeira individual e controle de acesso por perfil

**Phase requirement IDs:** UN-01, UN-02, UN-03, UN-04, UN-05

### UN-01: Cadastro de Unidades
Tela de CRUD completo de unidades (criar, editar, excluir). Campos: localização, telefone, responsável automático.
- **Status:** Planned
- **Priority:** alta

### UN-02: Responsável Automático por Hierarquia
Lógica automática: o barbeiro de maior cargo na unidade é o responsável. Hierarquia: Barbeiro Líder > Barbeiro Pro Max > Barbeiro Pro > Barbeiro
- **Status:** Planned
- **Priority:** alta

### UN-03: Visualização Financeira por Unidade (Barbeiro Líder)
Barbeiro Líder vê dados financeiros de cada unidade individualmente
- **Status:** Planned
- **Priority:** alta

### UN-04: Controle de Agendamentos por Perfil
Barbeiro Líder vê todos os agendamentos da unidade. Não-líderes veem apenas os próprios.
- **Status:** Planned
- **Priority:** alta

### UN-05: Tela de Detalhes da Unidade
Tela individual da unidade com métricas, agendamentos e configuração
- **Status:** Planned
- **Priority:** média
