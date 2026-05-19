-- Phase 16: 合併「標準工時」+「班表」— is_default 旗標
ALTER TABLE hr.shift_templates ADD COLUMN IF NOT EXISTS is_default boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_default_shift_template
  ON hr.shift_templates (is_default) WHERE is_default = true;

DO $mig$
DECLARE
  swh jsonb;
  existing_count int;
  start_t text;
  end_t text;
  brk int;
BEGIN
  SELECT COUNT(*) INTO existing_count FROM hr.shift_templates WHERE is_default = true;
  IF existing_count > 0 THEN RETURN; END IF;

  SELECT value INTO swh FROM hr.payroll_settings WHERE key = 'standard_work_hours';
  swh := COALESCE(swh, '{}'::jsonb);
  start_t := COALESCE(swh->>'start_time', swh->>'start', '08:00');
  end_t := COALESCE(swh->>'end_time', swh->>'end', '17:00');
  brk := COALESCE((swh->>'break_minutes')::int, 60);

  IF EXISTS (SELECT 1 FROM hr.shift_templates WHERE name = '預設班') THEN
    UPDATE hr.shift_templates SET is_default = true WHERE name = '預設班';
  ELSE
    INSERT INTO hr.shift_templates (name, start_time, end_time, break_minutes, is_default, is_active)
    VALUES ('預設班', start_t::time, end_t::time, brk, true, true);
  END IF;
END $mig$;

COMMENT ON COLUMN hr.shift_templates.is_default IS '預設班表（每公司最多一筆）— 員工未指派班表時自動套用';
