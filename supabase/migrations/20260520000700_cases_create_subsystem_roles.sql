-- tb-cases Phase 1.1.8: 子系統角色表（不動 hr.employees.role）
-- 設計依據: DECISIONS §8.1（避免影響 tb-hr / tb-payroll）

CREATE TABLE cases.subsystem_roles (
  employee_id bigint NOT NULL REFERENCES hr.employees(id) ON DELETE CASCADE,
  role_code text NOT NULL,
  region_id uuid REFERENCES public.tb_regions(id),
  granted_at timestamptz NOT NULL DEFAULT now(),
  granted_by bigint REFERENCES hr.employees(id),
  notes text NOT NULL DEFAULT '',

  -- 同員工 + 同角色 + 同 region 不可重複
  -- region_id 為 null 時也視為 unique key 的一部分（用 COALESCE 解 NULL）
  PRIMARY KEY (employee_id, role_code, region_id),

  CONSTRAINT subsystem_roles_role_check CHECK (role_code IN ('support', 'region_lead', 'agent'))
);

CREATE INDEX idx_subsystem_roles_employee ON cases.subsystem_roles (employee_id);
CREATE INDEX idx_subsystem_roles_role ON cases.subsystem_roles (role_code);
CREATE INDEX idx_subsystem_roles_region ON cases.subsystem_roles (region_id) WHERE region_id IS NOT NULL;

ALTER TABLE cases.subsystem_roles ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.subsystem_roles IS 'tb-cases 內部角色（support 客服 / region_lead 區主管 / agent 業務）。hr.employees.role=admin 自動繼承總部 admin、不需在此表';
COMMENT ON COLUMN cases.subsystem_roles.region_id IS 'region_lead / agent 角色需指定區；support 通常 region_id = null（看全區待篩選池）';
