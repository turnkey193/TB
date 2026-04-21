-- Mirror of migration applied to Supabase (version: 20260415070401)
-- Source of truth: supabase_migrations.schema_migrations on project obgobetnlecbmypvfnsq
-- Purpose: create tb_case_notes for per-case free-text annotations

CREATE TABLE IF NOT EXISTS tb_case_notes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  region text NOT NULL,
  case_id text NOT NULL,
  note text DEFAULT '',
  updated_at timestamptz DEFAULT now(),
  UNIQUE(region, case_id)
);
ALTER TABLE tb_case_notes DISABLE ROW LEVEL SECURITY;
