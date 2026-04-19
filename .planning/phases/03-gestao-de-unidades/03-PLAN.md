---
name: "03-Gestão de Unidades"
type: "execute"
wave: 1
depends_on: ""
requirements_addressed: ["UN-01", "UN-02", "UN-03", "UN-04", "UN-05"]
files_modified:
  - "lib/features/units/presentation/units_list_screen.dart"
  - "lib/features/units/presentation/unit_detail_screen.dart"
  - "lib/features/units/presentation/unit_form_screen.dart"
  - "lib/features/units/providers/units_provider.dart"
  - "lib/features/units/providers/unit_detail_provider.dart"
  - "lib/features/dashboard/providers/dashboard_provider.dart"
  - "lib/core/presentation/main_navigation.dart"
autonomous: true
---

<objective>
Implementar gestão completa de unidades com CRUD, responsável automático, visualização financeira e controle de acesso por perfil
</objective>

## Tarefas

### Tarefa 1: SQL de suporte às unidades
<read_first>
- .planning/phases/03-gestao-de-unidades/03-RESEARCH.md
</read_first>

Criar/adicionar em `supabase/migrations/` arquivo SQL com:
```sql
-- Adicionar colunas location e phone à tabela units
ALTER TABLE units ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE units ADD COLUMN IF NOT EXISTS phone TEXT;
```

<action>
Criar arquivo `supabase/migrations/003_add_unit_fields.sql` com:
- `ALTER TABLE units ADD COLUMN IF NOT EXISTS location TEXT;`
- `ALTER TABLE units ADD COLUMN IF NOT EXISTS phone TEXT;`
</action>

<acceptance_criteria>
- [ ] Arquivo `supabase/migrations/003_add_unit_fields.sql` existe
- [ ] Contém ALTER TABLE para location e phone
- [ ] Usa IF NOT EXISTS para evitar erro em re-run
</acceptance_criteria>

---

### Tarefa 2: Provider de lista de unidades
<read_first>
- lib/core/supabase/providers.dart
- lib/features/dashboard/providers/dashboard_provider.dart
</read_first>

Criar `lib/features/units/providers/units_provider.dart`:
```dart
final unitsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('units').select('*').order('name');
  return List<Map<String, dynamic>>.from(response);
});

final unitBarbersProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
    .from('barbers')
    .select('*, users(name)')
    .eq('unit_id', unitId)
    .order('category', options: const OrderingOptions(ascending: false)); // Order by hierarchy
  return List<Map<String, dynamic>>.from(response);
});
```

<action>
- Criar diretório `lib/features/units/providers/`
- Criar `lib/features/units/providers/units_provider.dart` com:
  - `unitsProvider` - busca todas as unidades
  - `unitBarbersProvider(unitId)` - busca barbeiros da unidade ordenados por hierarquia
</action>

<acceptance_criteria>
- [ ] `unitsProvider` definido e exportado
- [ ] `unitBarbersProvider(unitId)` definido com ordenação por category
- [ ] Arquivo compila sem erros
</acceptance_criteria>

---

### Tarefa 3: Units List Screen (grid de unidades)
<read_first>
- lib/features/dashboard/presentation/home_screen.dart (como referência de grid)
- lib/features/settings/unit_settings_screen.dart (padrão de screen)
</read_first>

Criar `lib/features/units/presentation/units_list_screen.dart`:
- AppBar: "Unidades" com botão de adicionar (+)
- GridView com Cards de unidades
- Cada Card mostra: nome, localização, telefone, responsável (computed)
- Ao clicar abre `UnitDetailScreen`
- FAB para criar nova unidade
- Apenas Barbeiro Líder vê esta tela (checar `isLeader`)

<action>
Criar `lib/features/units/presentation/units_list_screen.dart`:
- Scaffold com AppBar "Unidades" e action de adicionar
- GridView.count (crossAxisCount: 2) de Cards de unidades
- Cada Card: nome, location, phone, "Responsável: {nome}"
- onTap naviga para UnitDetailScreen
- Se não for líder, mostra SnackBar e retorna
</action>

<acceptance_criteria>
- [ ] AppBar com título "Unidades"
- [ ] Grid de Cards com dados das unidades
- [ ] Responsável mostrado via computed (barbeiro de maior hierarquia)
- [ ] FAB para adicionar nova unidade
- [ ] Verificação de isLeader (apenas líder acessa)
</acceptance_criteria>

---

### Tarefa 4: Unit Detail Screen (métricas + agendamentos)
<read_first>
- lib/features/dashboard/providers/dashboard_provider.dart (lógica de métricas)
- lib/features/orders/presentation/schedule_agenda_screen.dart (lista de agendamentos)
</read_first>

Criar `lib/features/units/presentation/unit_detail_screen.dart`:
- Recebe `unitId` como parâmetro
- Tabs: "Info" | "Financeiro" | "Agendamentos"

**Tab Info:**
- Nome da unidade
- Localização
- Telefone
- Responsável atual (computed)
- Horário de funcionamento

**Tab Financeiro:**
- Faturamento do dia
- Comissões
- Comandas fechadas/abertas
- Ranking de barbeiros da unidade

**Tab Agendamentos:**
- Lista de agendamentos filtrada por:
  - Barbeiro Líder = todos os agendamentos da unidade
  - Não-líder = apenas os próprios (`barber_id` do userProfile)

<action>
Criar `lib/features/units/presentation/unit_detail_screen.dart`:
- DefaultTabController com 3 tabs
- Tab Info: display de dados da unidade + responsável computed
- Tab Financeiro: KPIs usando lógica similar ao dashboard_provider
- Tab Agendamentos: lista usando padrão do schedule_agenda_screen com filtro por perfil
</action>

<acceptance_criteria>
- [ ] 3 tabs: Info, Financeiro, Agendamentos
- [ ] Tab Info mostra todos os dados da unidade
- [ ] Tab Financeiro mostra KPIs da unidade
- [ ] Tab Agendamentos filtra por perfil (líder vê todos, outros veem só seus)
- [ ] Navegação de volta funciona
</acceptance_criteria>

---

### Tarefa 5: Unit Form Screen (CRUD)
<read_first>
- lib/features/settings/unit_settings_screen.dart (padrão de form)
</read_first>

Criar `lib/features/units/presentation/unit_form_screen.dart`:
- Modo criar ou editar (parâmetro `unitId` nullable)
- Campos: Nome, Localização, Telefone
- Botão salvar (INSERT ou UPDATE)
- Confirmação ao excluir (DELETE)

<action>
Criar `lib/features/units/presentation/unit_form_screen.dart`:
- Construtor com `Unit? unit` opcional (null = criar)
- TextFields para: nome, localização, telefone
- Botões: Salvar, Excluir (se editando)
- Métodos: _createUnit, _updateUnit, _deleteUnit via Supabase
</action>

<acceptance_criteria>
- [ ] Funciona para criar nova unidade (INSERT)
- [ ] Funciona para editar unidade existente (UPDATE)
- [ ] Confirmação antes de excluir
- [ ]DELETE funciona
- [ ] Validação de campos obrigatórios
</acceptance_criteria>

---

### Tarefa 6: Integrar Units no menu de navegação
<read_first>
- lib/core/presentation/main_navigation.dart
</read_first>

Modificar `main_navigation.dart`:
- Adicionar nova Tab ou Item no menu para "Unidades"
- Condicionar visibilidade: apenas Barbeiro Líder
- Usar `isLeader` já existente no build()

<action>
No `main_navigation.dart`:
- Adicionar `UnitsListScreen` às tabs/ítens do menu
- Na BottomNavigationBar: novo item "Unidades" (icon: Icons.business)
- Condicionar: `if (isLeader)` para mostrar
</action>

<acceptance_criteria>
- [ ] Barbeiro Líder vê item "Unidades" no menu
- [ ] Não-líderes não veem o item
- [ ] Navegação para UnitsListScreen funciona
</acceptance_criteria>

---

## Verification

1. Barbeiro Líder acessa lista de unidades
2. Não-líder tenta acessar e vê mensagem de acesso negado
3. CRUD de unidade funciona (criar, editar, excluir)
4. Responsável é computado corretamente pela hierarquia
5. Visualização financeira da unidade funciona
6. Filtro de agendamentos funciona por perfil

## must_haves

- [ ] Units List Screen com grid de unidades
- [ ] Unit Detail Screen com tabs Info/Financeiro/Agendamentos
- [ ] Unit Form Screen para CRUD
- [ ] Responsável automático por hierarquia funcionando
- [ ] Filtro de agendamentos por perfil (líder vs não-líder)
- [ ] Navegação integrada no main_navigation
