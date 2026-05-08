-- Phase 11d: codex 第三輪 P0/P1 修補
-- 主要 server.js 側的 timezone fix 不需 migration；這裡只放 trigger

-- payslip 刪除後 orphan bonus_event 自動把 status='paid' 重置為 pending
CREATE OR REPLACE FUNCTION hr.reset_orphan_bonus_event() RETURNS trigger AS $$
BEGIN
  IF NEW.payslip_id IS NULL AND OLD.payslip_id IS NOT NULL AND OLD.status = 'paid' THEN
    NEW.status := 'pending';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orphan_bonus_event ON hr.bonus_events;
CREATE TRIGGER trg_orphan_bonus_event BEFORE UPDATE OF payslip_id ON hr.bonus_events
  FOR EACH ROW EXECUTE FUNCTION hr.reset_orphan_bonus_event();

COMMENT ON FUNCTION hr.reset_orphan_bonus_event() IS 'Phase 11d: payslip 被刪 → bonus_event.status 從 paid 重置為 pending，避免 ledger desync';
