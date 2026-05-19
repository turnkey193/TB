-- tb-cases Phase 1.1.3: 表單來源主檔 + seed
-- 設計依據: DECISIONS §7

CREATE TABLE cases.intake_sources (
  code text PRIMARY KEY,                    -- 'A', 'B', 'C', ...
  name text NOT NULL,                       -- '石總監（行銷公司）'
  channel text NOT NULL,                    -- 'agency' | 'inhouse'
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intake_sources_channel_check CHECK (channel IN ('agency', 'inhouse'))
);

CREATE TRIGGER set_intake_sources_updated_at
  BEFORE UPDATE ON cases.intake_sources
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE cases.intake_sources ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.intake_sources IS '案件來源主檔: SurveyCake 不同表單對應的行銷源（agency=行銷公司 / inhouse=自己行銷）';

-- 種子資料
INSERT INTO cases.intake_sources (code, name, channel, sort_order) VALUES
  ('A', '石總監（行銷公司）', 'agency',  10),
  ('B', '桃園（星創）',       'inhouse', 20),
  ('C', '台中與自控（CK）',   'inhouse', 30)
ON CONFLICT (code) DO NOTHING;
