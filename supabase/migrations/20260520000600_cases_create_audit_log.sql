-- tb-cases Phase 1.1.7: audit log
-- 設計依據: DECISIONS §12

CREATE TABLE cases.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid REFERENCES cases.cases(id) ON DELETE CASCADE,
  actor_employee_id bigint REFERENCES hr.employees(id),
  action text NOT NULL,
  before jsonb,
  after jsonb,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT audit_log_action_check CHECK (action IN (
    'create', 'screening', 'dispatch', 'reassign', 'edit', 'status_change', 'delete', 'intake_source_update', 'role_grant', 'role_revoke'
  ))
);

CREATE INDEX idx_audit_log_case ON cases.audit_log (case_id, created_at DESC);
CREATE INDEX idx_audit_log_actor ON cases.audit_log (actor_employee_id, created_at DESC);
CREATE INDEX idx_audit_log_action ON cases.audit_log (action, created_at DESC);

ALTER TABLE cases.audit_log ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.audit_log IS '所有寫入動作的審計記錄。永久保留（DECISIONS §12）';
