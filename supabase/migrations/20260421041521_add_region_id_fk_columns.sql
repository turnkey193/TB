-- Mirror of migration applied to Supabase (version: 20260421041521)
-- Phase 2: 為 6 張業務表加 region_id 欄位，FK 指向 tb_regions(id)
-- 先允許 NULL，回填完成後再加 NOT NULL

ALTER TABLE tb_weekly_notes    ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES tb_regions(id);
ALTER TABLE tb_payment_records ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES tb_regions(id);
ALTER TABLE tb_expected_signs  ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES tb_regions(id);
ALTER TABLE tb_project_notes   ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES tb_regions(id);
ALTER TABLE tb_case_notes      ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES tb_regions(id);
ALTER TABLE tb_annual_targets  ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES tb_regions(id);

CREATE INDEX IF NOT EXISTS idx_weekly_notes_region_id    ON tb_weekly_notes(region_id);
CREATE INDEX IF NOT EXISTS idx_payment_records_region_id ON tb_payment_records(region_id);
CREATE INDEX IF NOT EXISTS idx_expected_signs_region_id  ON tb_expected_signs(region_id);
CREATE INDEX IF NOT EXISTS idx_project_notes_region_id   ON tb_project_notes(region_id);
CREATE INDEX IF NOT EXISTS idx_case_notes_region_id      ON tb_case_notes(region_id);
CREATE INDEX IF NOT EXISTS idx_annual_targets_region_id  ON tb_annual_targets(region_id);

-- 套用完此 migration 後，立刻用 execute_sql 跑以下 backfill：
--   UPDATE tb_weekly_notes w    SET region_id = r.id FROM tb_regions r WHERE w.region = r.name AND w.region_id IS NULL;
--   UPDATE tb_payment_records p SET region_id = r.id FROM tb_regions r WHERE p.region = r.name AND p.region_id IS NULL;
--   UPDATE tb_expected_signs  e SET region_id = r.id FROM tb_regions r WHERE e.region = r.name AND e.region_id IS NULL;
--   UPDATE tb_project_notes   n SET region_id = r.id FROM tb_regions r WHERE n.region = r.name AND n.region_id IS NULL;
--   UPDATE tb_case_notes      c SET region_id = r.id FROM tb_regions r WHERE c.region = r.name AND c.region_id IS NULL;
--   UPDATE tb_annual_targets  t SET region_id = r.id FROM tb_regions r WHERE t.region = r.name AND t.region_id IS NULL;
-- 確認 null_cnt 都為 0 後再套 enforce_region_id_not_null 這個 migration。
