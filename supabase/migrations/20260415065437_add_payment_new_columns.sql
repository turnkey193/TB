-- Mirror of migration applied to Supabase (version: 20260415065437)
-- Source of truth: supabase_migrations.schema_migrations on project obgobetnlecbmypvfnsq
-- Purpose: extend tb_payment_records with contract/additional amount & status columns

ALTER TABLE tb_payment_records
  ADD COLUMN IF NOT EXISTS contract_amount integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS contract_status text DEFAULT '時間未到',
  ADD COLUMN IF NOT EXISTS additional_amount integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS additional_status text DEFAULT '時間未到',
  ADD COLUMN IF NOT EXISTS abnormal_note text DEFAULT '';
