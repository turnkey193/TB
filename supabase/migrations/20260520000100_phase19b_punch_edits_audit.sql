-- Phase 19b: 打卡編輯完整 audit log

CREATE TABLE IF NOT EXISTS hr.punch_edits (
  id bigserial PRIMARY KEY,
  punch_id bigint NOT NULL REFERENCES hr.punches(id) ON DELETE CASCADE,
  editor_id bigint NOT NULL REFERENCES hr.employees(id),
  edited_at timestamptz NOT NULL DEFAULT now(),
  changes jsonb NOT NULL,  -- { field_name: { old: ..., new: ... }, ... }
  note text
);

CREATE INDEX IF NOT EXISTS idx_punch_edits_punch ON hr.punch_edits (punch_id, edited_at DESC);
CREATE INDEX IF NOT EXISTS idx_punch_edits_editor ON hr.punch_edits (editor_id, edited_at DESC);

ALTER TABLE hr.punch_edits ENABLE ROW LEVEL SECURITY;
CREATE POLICY svc_all ON hr.punch_edits FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMENT ON TABLE hr.punch_edits IS '打卡編輯歷史 — 每次 PATCH /api/punches/:id 寫一筆';
COMMENT ON COLUMN hr.punch_edits.changes IS 'JSON diff: { punched_at: {old:"...", new:"..."}, ... }';
