-- Phase 15a: 特休週年制 schema 改造

-- 1. annual_leave_balances 加期間欄位 + 過期折發追蹤
ALTER TABLE hr.annual_leave_balances
  ADD COLUMN IF NOT EXISTS period_start date,
  ADD COLUMN IF NOT EXISTS period_end date,
  ADD COLUMN IF NOT EXISTS payout_amount numeric(10,2),
  ADD COLUMN IF NOT EXISTS payout_payslip_id bigint REFERENCES hr.payslips(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS last_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS expire_at date GENERATED ALWAYS AS (period_end + INTERVAL '1 year') STORED;

-- 移除舊的 year UNIQUE（之前曆年制用）
ALTER TABLE hr.annual_leave_balances
  DROP CONSTRAINT IF EXISTS annual_leave_balances_employee_id_year_key;

-- 新的唯一鍵：員工 + period_start
CREATE UNIQUE INDEX IF NOT EXISTS uniq_emp_period_start
  ON hr.annual_leave_balances (employee_id, period_start)
  WHERE period_start IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_alb_expire_lookup
  ON hr.annual_leave_balances (expire_at)
  WHERE payout_payslip_id IS NULL AND period_end IS NOT NULL;

-- 2. 員工通知 queue（過期前 120 天 + 其他系統通知）
CREATE TABLE IF NOT EXISTS hr.notifications (
  id bigserial PRIMARY KEY,
  employee_id bigint NOT NULL REFERENCES hr.employees(id) ON DELETE CASCADE,
  kind text NOT NULL,  -- 'annual_leave_expiring' / ...
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  channel text NOT NULL DEFAULT 'line',  -- 'line' / 'in_app'
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','dismissed')),
  sent_at timestamptz,
  read_at timestamptz,
  error text,
  -- dedup key (避免一天推同一封)
  dedup_key text,
  created_at timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_notif_dedup ON hr.notifications (employee_id, dedup_key) WHERE dedup_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notif_pending ON hr.notifications (status, created_at) WHERE status = 'pending';

ALTER TABLE hr.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY svc_all ON hr.notifications FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMENT ON TABLE hr.notifications IS '系統通知 queue（特休到期、薪資結算等）';
COMMENT ON COLUMN hr.annual_leave_balances.period_start IS '此特休期間起算（通常是 hire_date 的週年或半年）';
COMMENT ON COLUMN hr.annual_leave_balances.period_end IS '此特休期間結束（下一週年的前一天）';
COMMENT ON COLUMN hr.annual_leave_balances.expire_at IS 'period_end + 1 年（法定可遞延 1 年，過期則折發）';
