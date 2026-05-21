-- Phase 19: 補打卡 + 管理員編輯打卡

-- 1. 新增欄位
ALTER TABLE hr.punches
  ADD COLUMN IF NOT EXISTS is_retroactive boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS retro_reason text,
  ADD COLUMN IF NOT EXISTS edited_by bigint REFERENCES hr.employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS edited_at timestamptz;

-- 2. 放寬 GPS 欄位 NOT NULL（補打卡通常沒 GPS）
ALTER TABLE hr.punches
  ALTER COLUMN client_lat DROP NOT NULL,
  ALTER COLUMN client_lng DROP NOT NULL;

-- 3. 補一個 index 給之後管理員查詢補打卡用
CREATE INDEX IF NOT EXISTS idx_punches_retroactive ON hr.punches (is_retroactive, review_status)
  WHERE is_retroactive = true;

COMMENT ON COLUMN hr.punches.is_retroactive IS '是否為員工事後補打卡（需主管審核）';
COMMENT ON COLUMN hr.punches.retro_reason IS '補打卡原因（員工自填）';
COMMENT ON COLUMN hr.punches.edited_by IS '最後一次被管理員編輯的人 (employees.id)';
COMMENT ON COLUMN hr.punches.edited_at IS '最後一次被管理員編輯的時間';
