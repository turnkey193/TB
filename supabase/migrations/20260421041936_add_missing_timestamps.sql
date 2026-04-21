-- Mirror of migration applied to Supabase (version: 20260421041936)
-- Phase 3: 補齊缺少的 timestamps

-- created_at 只加不存在的
ALTER TABLE tb_payment_records ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE tb_project_notes   ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE tb_case_notes      ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE tb_annual_targets  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- updated_at 只加不存在的
ALTER TABLE tb_regions        ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE tb_users          ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE tb_weekly_notes   ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE tb_expected_signs ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
