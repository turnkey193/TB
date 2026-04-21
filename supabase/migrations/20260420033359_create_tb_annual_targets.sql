-- Mirror of migration applied to Supabase (version: 20260420033359)
-- Source of truth: supabase_migrations.schema_migrations on project obgobetnlecbmypvfnsq
-- Purpose: create tb_annual_targets for per-region yearly revenue/sign-rate milestones

CREATE TABLE tb_annual_targets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  region text NOT NULL,
  year integer NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::integer,
  milestone_revenue integer DEFAULT 0,
  milestone_sign_rate text DEFAULT '',
  updated_at timestamptz DEFAULT now(),
  UNIQUE(region, year)
);
ALTER TABLE tb_annual_targets DISABLE ROW LEVEL SECURITY;
