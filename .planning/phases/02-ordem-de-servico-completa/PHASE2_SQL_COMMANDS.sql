-- ============================================================
-- PHASE 2: ORDEM DE SERVIÇO COMPLETA
-- Execute these commands in Supabase Dashboard > SQL Editor
-- ============================================================

-- ============================================================
-- OS-01: Order Items Table & RLS Policy
-- ============================================================

-- Criar tabela order_items
CREATE TABLE order_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  service_id UUID REFERENCES services(id),
  product_id UUID, -- reservado para futuro uso
  service_name TEXT NOT NULL,
  product_name TEXT,
  price DECIMAL(10,2) NOT NULL,
  quantity INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Policy para order_items (acesso pela mesma unidade da order)
CREATE POLICY "order_items_select" ON order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.unit_id = auth_user_unit_id()
    )
  );

CREATE POLICY "order_items_insert" ON order_items
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.unit_id = auth_user_unit_id()
    )
  );

CREATE POLICY "order_items_update" ON order_items
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.unit_id = auth_user_unit_id()
    )
  );

CREATE POLICY "order_items_delete" ON order_items
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.unit_id = auth_user_unit_id()
    )
  );

-- ============================================================
-- OS-04: Products Table & RLS Policy
-- ============================================================

-- Criar tabela products
CREATE TABLE products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  unit_id UUID NOT NULL REFERENCES units(id),
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  stock INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Policy para products (mesma unidade)
CREATE POLICY "products_select" ON products
  FOR SELECT TO authenticated
  USING (unit_id = auth_user_unit_id());

CREATE POLICY "products_insert" ON products
  FOR INSERT TO authenticated
  WITH CHECK (unit_id = auth_user_unit_id());

CREATE POLICY "products_update" ON products
  FOR UPDATE TO authenticated
  USING (unit_id = auth_user_unit_id());

CREATE POLICY "products_delete" ON products
  FOR DELETE TO authenticated
  USING (unit_id = auth_user_unit_id());

-- ============================================================
-- OS-05: Add is_vip column to clients table (if not exists)
-- ============================================================

-- Verificar se a coluna já existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'clients' AND column_name = 'is_vip'
  ) THEN
    ALTER TABLE clients ADD COLUMN is_vip BOOLEAN DEFAULT false;
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'Table clients does not exist';
END $$;

-- ============================================================
-- Verify tables were created
-- ============================================================
 SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('order_items', 'products');