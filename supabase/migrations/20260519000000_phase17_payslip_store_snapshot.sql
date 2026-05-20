-- Phase 17: payslips 加 store_id snapshot 欄位 — 結算當下凍結員工主店
-- 用途：分店維度的薪資查詢、報表、結算過濾，且員工日後轉店不會影響歷史薪資條歸屬

ALTER TABLE hr.payslips
  ADD COLUMN IF NOT EXISTS store_id bigint REFERENCES hr.stores_geo(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_payslips_store ON hr.payslips (store_id);
CREATE INDEX IF NOT EXISTS idx_payslips_period_store ON hr.payslips (period_id, store_id);

-- Backfill 既有 payslip：用該員工目前的 home_store_id 補上
-- （之前未來轉店不會 retro 改寫，所以一次性 backfill 即可）
UPDATE hr.payslips ps
  SET store_id = e.home_store_id
  FROM hr.employees e
  WHERE ps.employee_id = e.id
    AND ps.store_id IS NULL
    AND e.home_store_id IS NOT NULL;

COMMENT ON COLUMN hr.payslips.store_id IS '結算當下員工主店 snapshot（home_store_id）。員工轉店後此欄位不會跟著改，保留歷史歸屬。';
