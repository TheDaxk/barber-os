# Phase 3: Gestão de Unidades - Research

**Research Date:** 2026-04-15

---

## Database Structure

### Tabela `units`
- Já existe e é usada para configurações de horário
- Campos atuais: `id`, `name`, `location`, `phone`, `created_at`, e horários por dia (`segunda_open`, `segunda_close`, etc.)
- Não tem campo `responsável` - será necessário adicionar ou computar na hora

### Tabela `barbers`
- Campos: `id`, `user_id`, `unit_id`, `category`, `commission_rate`
- `category` contém a hierarquia: `'Barbeiro Líder'`, `'Barbeiro Pro Max'`, `'Barbeiro Pro'`, `'Barbeiro'`
- `user_id` associa o barbeiro ao usuário autenticado

### Tabela `orders`
- Campos: `id`, `unit_id`, `barber_id`, `client_id`, `client_name`, `start_time`, `end_time`, `status`, `total`
- `unit_id` permite filtrar agendamentos por unidade

---

## Key Findings

### 1. Responsável Automático por Hierarquia

**Problema:** A unidade não tem campo `responsável` - o responsável precisa ser COMPUTADO da seguinte forma:
1. Buscar todos os barbeiros da unidade
2. Ordenar por categoria/hierarquia
3. O primeiro da lista é o responsável

**Hierarquia (maior para menor):**
```
Barbeiro Líder > Barbeiro Pro Max > Barbeiro Pro > Barbeiro
```

**Query SQL para obter responsável:**
```sql
SELECT b.*, u.name as user_name
FROM barbers b
JOIN users u ON b.user_id = u.id
WHERE b.unit_id = $unitId
ORDER BY
  CASE b.category
    WHEN 'Barbeiro Líder' THEN 1
    WHEN 'Barbeiro Pro Max' THEN 2
    WHEN 'Barbeiro Pro' THEN 3
    WHEN 'Barbeiro' THEN 4
    ELSE 5
  END
LIMIT 1;
```

### 2. Controle de Acesso a Agendamentos

**Lógica existente** (dashboard_provider.dart):
```dart
final isLeader = userProfile['category'] == 'Barbeiro Líder' || userProfile['role'] == 'admin';

if (!isLeader && userProfile['barber_id'] != null) {
  query = query.eq('barber_id', userProfile['barber_id']);
}
```

**Reutilizar esta lógica** para filtrar agendamentos na tela de detalhes da unidade.

### 3. Visualização Financeira por Unidade

- Barbeiro Líder seleciona unidade e vê métricas dela
- Não-líderes veem apenas dados da própria unidade (via `userProfile['unit_id']`)
- Métricas: faturamento, comissões, comandas fechadas/abertas, ranking de barbeiros

### 4. CRUD de Unidades

**Tela existente** (`unit_settings_screen.dart`):
- Apenas editing de horários
- Precisará ser expandida para CRUD completo
- Adicionar campos: `location`, `phone`

**Operações:**
- Criar: INSERT em `units`
- Editar: UPDATE em `units`
- Excluir: DELETE em `units` (com cuidado de não perder dados)
- Listar: SELECT de todas as unidades (apenas Barbeiro Líder)

### 5. SQL Necessário

```sql
-- Adicionar campos à tabela units (se não existirem)
ALTER TABLE units ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE units ADD COLUMN IF NOT EXISTS phone TEXT;

-- Não adicionar 'responsável' como coluna - computar na query
-- Mas se quiser cache, pode adicionar:
ALTER TABLE units ADD COLUMN IF NOT EXISTS responsible_id UUID REFERENCES barbers(id);
```

---

## Implementation Approach

### Telas a Criar/Modificar

1. **`units_list_screen.dart`** (NOVA) - Lista todas as unidades (Barbeiro Líder)
2. **`unit_detail_screen.dart`** (NOVA) - Detalhes da unidade selecionada
3. **`unit_form_screen.dart`** (NOVA) - CRUD de unidade (criar/editar)
4. **`unit_settings_screen.dart`** (MODIFICAR) - Integrar na nova estrutura

### Providers a Criar

1. **`units_provider.dart`** - Lista todas as unidades (Barbeiro Líder)
2. **`unit_detail_provider.dart`** - Dados de uma unidade específica
3. **`unit_barbers_provider.dart`** - Barbeiros da unidade para computar responsável
4. **`unit_orders_provider.dart`** - Pedidos da unidade filtrados por perfil

### Fluxo de Navegação

```
Home (Barbeiro Líder)
  └── Units List (grid de unidades)
        ├── Unit Detail (métricas + agendamentos)
        │     └── Order Detail
        └── Create/Edit Unit Form
```

---

## Risks & Considerations

1. **Exclusão de unidade:** Que fazer com orders/barbeiros da unidade? Manter histórico, apenas marcar inativa?
2. **Múltiplas unidades para mesmo usuário:** currently o `user.unit_id` é único - se Barbeiro Líder控 múltiplas unidades, precisa de tabela intermedia
3. **Concorrência:** Responsável calculado em runtime - se categoria mudar, responsável muda automaticamente (pode ser desejado ou não)
