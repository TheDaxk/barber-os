# Phase 1: Implementar Funcionalidades Faltantes

**Wave:** 1
**Depends on:** None
**Files modified:** lib/features/dashboard/, lib/features/orders/, lib/features/settings/, lib/features/auth/, lib/features/team/

## Context

This phase implements all screens and features marked as "em desenvolvimento" or "em breve" in the codebase. Each task removes a placeholder SnackBar message and replaces it with functional navigation/screens.

---

## Tarefas

### FE-01: Nova Comanda

<read_first>
- lib/features/dashboard/presentation/home_screen.dart (linhas 248-293)
- lib/features/orders/presentation/create_order_screen.dart (se existir)
- lib/core/supabase/providers.dart
</read_first>

<action>
1. Verificar se `CreateOrderScreen` já existe em `lib/features/orders/presentation/`
2. Se existir: Modificar `_buildQuickActions()` em `home_screen.dart` para navegar para `CreateOrderScreen` ao invés de mostrar SnackBar
3. Se não existir: Criar `CreateOrderScreen` com campos:
   - Cliente (TextField para nome)
   - Barbeiro (DropdownButton de barbers)
   - Serviços (Checkboxes de services)
   - Botão "Abrir Comanda"
4. Após criar comanda, navegar para tela de detalhes da comanda
</action>

<acceptance_criteria>
- [ ] SnackBar "Funcionalidade em desenvolvimento" removido do item "Nova Comanda"
- [ ] Navegação para CreateOrderScreen funciona
- [ ] Nova comanda pode ser criada com cliente, barbeiro e serviços
</acceptance_criteria>

---

### FE-02: Agendar Cliente

<read_first>
- lib/features/dashboard/presentation/home_screen.dart (linhas 260-270)
- lib/features/orders/presentation/schedule_screen.dart (se existir)
</read_first>

<action>
1. Criar `ScheduleScreen` em `lib/features/orders/presentation/schedule_screen.dart`
2. Mostrar calendário/grid de horários do dia
3. Para cada barbeiro, mostrar horários disponíveis baseado em `barbers` e `orders`
4. Permitir selecionar barbeiro, data/hora e cliente
5. Criar `agendamento` (agendar no Supabase)
6. Modificar `_buildQuickActions()` em `home_screen.dart` para navegar para `ScheduleScreen`
</action>

<acceptance_criteria>
- [ ] SnackBar "Funcionalidade em desenvolvimento" removido do item "Agendar Cliente"
- [ ] ScheduleScreen exibida com calendário
- [ ] Horários disponíveis calculados corretamente
- [ ] Agendamento criado no banco de dados
</acceptance_criteria>

---

### FE-03: Ver Espera

<read_first>
- lib/features/dashboard/presentation/home_screen.dart (linhas 271-281)
- lib/features/orders/presentation/waiting_list_screen.dart (se existir)
</read_first>

<action>
1. Criar `WaitingListScreen` em `lib/features/orders/presentation/waiting_list_screen.dart`
2. Lista de clientes aguardando (status "waiting" em orders ou tabela separada)
3. Botão "Chamar Próximo" para remover da lista
4. Modificar `_buildQuickActions()` em `home_screen.dart` para navegar para `WaitingListScreen`
</action>

<acceptance_criteria>
- [ ] SnackBar "Funcionalidade em desenvolvimento" removido do item "Ver Espera"
- [ ] WaitingListScreen exibida com lista de clientes
- [ ] Funcionalidade de chamar próximo funciona
</acceptance_criteria>

---

### FE-04: Relatório Rápido

<read_first>
- lib/features/dashboard/presentation/home_screen.dart (linhas 282-292)
- lib/features/reports/presentation/financial_screen.dart
</read_first>

<action>
1. Criar `QuickReportScreen` em `lib/features/reports/presentation/quick_report_screen.dart`
2. Mostrar KPIs do dia: faturamento, comandas fechadas, comissões
3. Botão de imprimir/compartilhar (share_plus ou printing)
4. Modificar `_buildQuickActions()` em `home_screen.dart` para navegar para `QuickReportScreen`
</action>

<acceptance_criteria>
- [ ] SnackBar "Funcionalidade em desenvolvimento" removido do item "Relatório Rápido"
- [ ] QuickReportScreen exibe dados do dia
- [ ] Botão de compartilhar/imprimir funciona
</acceptance_criteria>

---

### FE-05: Configurações da Unidade

<read_first>
- lib/features/settings/menu_screen.dart (linha 135)
- supabase_rls_fix.sql (tabela units)
</read_first>

<action>
1. Criar `UnitSettingsScreen` em `lib/features/settings/unit_settings_screen.dart`
2. Listar dias da semana com horários de abertura/fechamento
3. Salvar em `units` table no Supabase
4. Modificar `menu_screen.dart` para navegar para `UnitSettingsScreen` ao invés de mostrar SnackBar "Em breve"
</action>

<acceptance_criteria>
- [ ] SnackBar "Em breve: Configurações da Unidade" removido
- [ ] UnitSettingsScreen permite editar horários
- [ ] Horários salvos no banco de dados
</acceptance_criteria>

---

### FE-06: Reset de Senha

<read_first>
- lib/features/auth/presentation/login_screen.dart (linha 141)
- lib/core/supabase/providers.dart
</read_first>

<action>
1. Adicionar link "Esqueci minha senha" na `LoginScreen`
2. Criar `ForgotPasswordScreen` em `lib/features/auth/presentation/forgot_password_screen.dart`
3. Campo email + botão "Enviar link de recuperação"
4. Usar `supabase.auth.resetPasswordForEmail()` do Supabase
5. Mostrar confirmação e opção de voltar ao login
</action>

<acceptance_criteria>
- [ ] TODO "Implementar reset de senha" removido de login_screen.dart
- [ ] Link "Esqueci minha senha" visível na LoginScreen
- [ ] ForgotPasswordScreen funcional
- [ ] Email de reset enviado pelo Supabase Auth
</acceptance_criteria>

---

### FE-07: Top Serviços

<read_first>
- lib/features/team/presentation/employee_details_screen.dart (linhas 151-170)
- lib/features/team/providers/barber_metrics_provider.dart (linha 37)
</read_first>

<action>
1. Modificar `barberMetricsProvider` para calcular top 3 serviços
2. Query em `order_items` agrupado por `service_id`
3. Contar frequência e ordenar desc
4. Exibir top serviços no `EmployeeDetailsScreen` substituindo o card placeholder
5. Se `order_items` não existir, implementar com dados de `orders`
</action>

<acceptance_criteria>
- [ ] Card placeholder "Top Serviços (Em Breve)" substituído por dados reais
- [ ] Top 3 serviços exibidos corretamente
- [ ] Dados atualizados conforme performasse do barbeiro
</acceptance_criteria>

---

### FE-08: Sistema de Notificações

<read_first>
- lib/core/presentation/main_navigation.dart (linha 61)
- pubspec.yaml (dependências existentes)
</read_first>

<action>
1. Adicionar `flutter_local_notifications` ou similar no pubspec.yaml
2. Criar `NotificationService` em `lib/core/services/notification_service.dart`
3. Configurar notificação local para lembretes
4. No main_navigation.dart, ao clicar no ícone de notificações, mostrar lista de notificações ou agendar novo lembrete
5. Para notificações push (Firebase), criar provider opcional
</action>

<acceptance_criteria>
- [ ] TODO "Abrir notificações" removido de main_navigation.dart
- [ ] Notificações locais funcionam
- [ ] Ícone de notificações responde ao clique
</acceptance_criteria>

---

## Verification

### must_haves (Goal Backward)
1. ✅ Zero SnackBars com "Funcionalidade em desenvolvimento" no dashboard
2. ✅ Zero placeholders "Em breve" no menu de configurações
3. ✅ Zero TODOs de funcionalidades pendentes nos arquivos modificados
4. ✅ Nova comanda pode ser criada e salva no Supabase
5. ✅ Agendamento pode ser criado
6. ✅ Reset de senha funcional via email

## Notas de Implementação

- Todas as telas devem seguir o padrão dark theme existente
- Usar Riverpod providers para estado
- Erros devem mostrar SnackBar com mensagem em português
- Loading states com CircularProgressIndicator
