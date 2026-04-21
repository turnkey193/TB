-- Mirror of migration applied to Supabase (version: 20260421041534)
-- Phase 2: backfill 完成且驗證 0 nulls，啟用 NOT NULL 約束

ALTER TABLE tb_weekly_notes    ALTER COLUMN region_id SET NOT NULL;
ALTER TABLE tb_payment_records ALTER COLUMN region_id SET NOT NULL;
ALTER TABLE tb_expected_signs  ALTER COLUMN region_id SET NOT NULL;
ALTER TABLE tb_project_notes   ALTER COLUMN region_id SET NOT NULL;
ALTER TABLE tb_case_notes      ALTER COLUMN region_id SET NOT NULL;
ALTER TABLE tb_annual_targets  ALTER COLUMN region_id SET NOT NULL;
