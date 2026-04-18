-- ============================================================
-- BARBER OS - Solução Definitiva para RLS (v2)
-- Rode este script inteiro no Supabase Dashboard > SQL Editor
-- ============================================================

-- =========================
-- PASSO 1: Remover TODAS as policies existentes
-- (busca dinâmica, não importa o nome)
-- =========================
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    -- Drop ALL policies on users
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'users' LOOP
        EXECUTE format('DROP POLICY %I ON users', pol.policyname);
    END LOOP;
    
    -- Drop ALL policies on barbers
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'barbers' LOOP
        EXECUTE format('DROP POLICY %I ON barbers', pol.policyname);
    END LOOP;
    
    -- Drop ALL policies on orders
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'orders' LOOP
        EXECUTE format('DROP POLICY %I ON orders', pol.policyname);
    END LOOP;
    
    -- Drop ALL policies on services
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'services' LOOP
        EXECUTE format('DROP POLICY %I ON services', pol.policyname);
    END LOOP;
END $$;

-- =========================
-- PASSO 2: Garantir que RLS está ativo
-- =========================
ALTER TABLE users    ENABLE ROW LEVEL SECURITY;
ALTER TABLE barbers  ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders   ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- =========================
-- PASSO 3: Funções SECURITY DEFINER
-- Rodam com permissões elevadas = NÃO acionam o RLS
-- =========================
CREATE OR REPLACE FUNCTION auth_user_unit_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT unit_id FROM users WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION auth_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM users WHERE id = auth.uid();
$$;

-- =========================
-- PASSO 4: Policies novas e seguras
-- Nenhuma policy faz SELECT direto em users!
-- =========================

-- USERS: Todos da mesma unidade podem se ver
-- (necessário para o join barbers → users(name) funcionar)
-- Usa auth_user_unit_id() = SECURITY DEFINER = sem recursão!
CREATE POLICY "users_select" ON users
  FOR SELECT TO authenticated
  USING (unit_id = auth_user_unit_id());

CREATE POLICY "users_update" ON users
  FOR UPDATE TO authenticated
  USING (id = auth.uid());

-- BARBERS: Qualquer autenticado pode ler
CREATE POLICY "barbers_select" ON barbers
  FOR SELECT TO authenticated
  USING (true);

-- ORDERS: Mesma unidade pode ler, inserir e atualizar
CREATE POLICY "orders_select" ON orders
  FOR SELECT TO authenticated
  USING (unit_id = auth_user_unit_id());

CREATE POLICY "orders_insert" ON orders
  FOR INSERT TO authenticated
  WITH CHECK (unit_id = auth_user_unit_id());

CREATE POLICY "orders_update" ON orders
  FOR UPDATE TO authenticated
  USING (unit_id = auth_user_unit_id());

-- SERVICES: Qualquer autenticado pode ler
CREATE POLICY "services_select" ON services
  FOR SELECT TO authenticated
  USING (true);

-- ============================================================
-- PRONTO! Hot restart no Flutter e teste a Agenda.
-- ============================================================
