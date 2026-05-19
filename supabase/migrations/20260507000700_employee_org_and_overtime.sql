-- 員工增加組織/薪資欄位（Google Sheet 員工基本資料對齊）
ALTER TABLE hr.employees
  ADD COLUMN department text,
  ADD COLUMN position text,
  ADD COLUMN grade int,
  ADD COLUMN id_number text,
  ADD COLUMN birth_date date,
  ADD COLUMN address text,
  ADD COLUMN bank_account_name text,
  ADD COLUMN pension_grade_amount numeric(10,2),
  ADD COLUMN apply_payroll boolean NOT NULL DEFAULT true,
  ADD COLUMN apply_labor_insurance boolean NOT NULL DEFAULT true,
  ADD COLUMN apply_health_insurance boolean NOT NULL DEFAULT true,
  ADD COLUMN apply_unemployment_insurance boolean NOT NULL DEFAULT true,
  ADD COLUMN apply_pension boolean NOT NULL DEFAULT true,
  ADD COLUMN pension_voluntary_rate numeric(4,3) DEFAULT 0;

-- 加班預先申請（依用戶要求）
CREATE TABLE hr.overtime_requests (
  id bigserial PRIMARY KEY,
  employee_id bigint NOT NULL REFERENCES hr.employees(id),
  work_date date NOT NULL,
  planned_start timestamptz NOT NULL,
  planned_end timestamptz NOT NULL,
  planned_hours numeric(4,1) NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'withdrawn', 'cancelled')),
  reviewed_by bigint REFERENCES hr.employees(id),
  reviewed_at timestamptz,
  review_note text,
  actual_end timestamptz,
  actual_hours numeric(4,1),
  extension_reason text,
  extension_status text DEFAULT 'not_requested'
    CHECK (extension_status IN ('not_requested', 'pending', 'approved', 'rejected')),
  extension_reviewed_by bigint REFERENCES hr.employees(id),
  extension_reviewed_at timestamptz,
  extension_review_note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX idx_ot_employee_date ON hr.overtime_requests (employee_id, work_date);
CREATE INDEX idx_ot_pending ON hr.overtime_requests (status) WHERE status = 'pending';
CREATE INDEX idx_ot_extension_pending ON hr.overtime_requests (extension_status) WHERE extension_status = 'pending';

CREATE TRIGGER trg_ot_updated_at BEFORE UPDATE ON hr.overtime_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE hr.overtime_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY svc_all ON hr.overtime_requests FOR ALL TO service_role USING (true) WITH CHECK (true);
