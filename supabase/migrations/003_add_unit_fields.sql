-- Adicionar colunas location e phone à tabela units
ALTER TABLE units ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE units ADD COLUMN IF NOT EXISTS phone TEXT;