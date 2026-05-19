-- Phase 5c: 員工角色（用於主管審核打卡、後台管理）
-- 預設 employee；manager 可審核打卡；admin 可改員工資料

ALTER TABLE hr.employees
  ADD COLUMN role text NOT NULL DEFAULT 'employee'
  CHECK (role IN ('employee', 'manager', 'admin'));

CREATE INDEX idx_employees_role ON hr.employees (role) WHERE role <> 'employee';
