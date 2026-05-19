-- ===== Phase 6: 排班 + 假別 + 行事曆 =====

CREATE TABLE hr.national_holidays (
  date date PRIMARY KEY,
  name text NOT NULL,
  is_makeup boolean DEFAULT false,
  notes text
);

CREATE TABLE hr.shift_templates (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  break_minutes int NOT NULL DEFAULT 60,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE hr.shifts (
  id bigserial PRIMARY KEY,
  employee_id bigint NOT NULL REFERENCES hr.employees(id) ON DELETE CASCADE,
  work_date date NOT NULL,
  shift_template_id bigint REFERENCES hr.shift_templates(id),
  store_id bigint REFERENCES hr.stores_geo(id),
  planned_start time,
  planned_end time,
  planned_break_minutes int DEFAULT 60,
  day_type text NOT NULL DEFAULT 'workday'
    CHECK (day_type IN ('workday', 'rest_day', 'regular_off', 'national_holiday')),
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (employee_id, work_date)
);
CREATE INDEX idx_shifts_date ON hr.shifts (work_date, employee_id);

CREATE TABLE hr.leave_types (
  code text PRIMARY KEY,
  name text NOT NULL,
  paid_ratio numeric(3,2) NOT NULL DEFAULT 1.0,
  max_days_per_year numeric(5,1),
  max_days_total numeric(5,1),
  max_days_per_event numeric(5,1),
  requires_attachment boolean DEFAULT false,
  is_active boolean DEFAULT true,
  notes text,
  sort_order int DEFAULT 0
);

CREATE TABLE hr.annual_leave_balances (
  id bigserial PRIMARY KEY,
  employee_id bigint NOT NULL REFERENCES hr.employees(id) ON DELETE CASCADE,
  year int NOT NULL,
  entitled_days numeric(5,1) NOT NULL,
  carried_over_days numeric(5,1) DEFAULT 0,
  used_days numeric(5,1) DEFAULT 0,
  expired_days numeric(5,1) DEFAULT 0,
  notes text,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (employee_id, year)
);

CREATE TABLE hr.leave_requests (
  id bigserial PRIMARY KEY,
  employee_id bigint NOT NULL REFERENCES hr.employees(id),
  leave_type_code text NOT NULL REFERENCES hr.leave_types(code),
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  total_hours numeric(6,2) NOT NULL,
  reason text,
  attachment_url text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'withdrawn')),
  reviewed_by bigint REFERENCES hr.employees(id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX idx_leave_employee_time ON hr.leave_requests (employee_id, start_at DESC);
CREATE INDEX idx_leave_pending ON hr.leave_requests (status) WHERE status = 'pending';

-- ===== Phase 7: 薪資結算 =====

CREATE TABLE hr.payroll_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  effective_from date NOT NULL,
  notes text,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE hr.payroll_periods (
  id bigserial PRIMARY KEY,
  period_label text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'finalized', 'paid')),
  finalized_by bigint REFERENCES hr.employees(id),
  finalized_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  UNIQUE (period_label)
);

CREATE TABLE hr.payslips (
  id bigserial PRIMARY KEY,
  period_id bigint NOT NULL REFERENCES hr.payroll_periods(id) ON DELETE CASCADE,
  employee_id bigint NOT NULL REFERENCES hr.employees(id),
  regular_hours numeric(6,2) DEFAULT 0,
  rest_day_hours numeric(6,2) DEFAULT 0,
  ot_134_hours numeric(6,2) DEFAULT 0,
  ot_167_hours numeric(6,2) DEFAULT 0,
  ot_267_hours numeric(6,2) DEFAULT 0,
  leave_paid_hours numeric(6,2) DEFAULT 0,
  leave_half_paid_hours numeric(6,2) DEFAULT 0,
  leave_unpaid_hours numeric(6,2) DEFAULT 0,
  base_salary numeric(10,2) DEFAULT 0,
  overtime_pay numeric(10,2) DEFAULT 0,
  allowances jsonb DEFAULT '[]'::jsonb,
  deductions jsonb DEFAULT '[]'::jsonb,
  labor_insurance_employee numeric(10,2) DEFAULT 0,
  health_insurance_employee numeric(10,2) DEFAULT 0,
  labor_pension_voluntary numeric(10,2) DEFAULT 0,
  income_tax_withheld numeric(10,2) DEFAULT 0,
  supplementary_health_premium numeric(10,2) DEFAULT 0,
  gross_pay numeric(10,2) DEFAULT 0,
  total_deductions numeric(10,2) DEFAULT 0,
  net_pay numeric(10,2) DEFAULT 0,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (period_id, employee_id)
);
CREATE INDEX idx_payslips_employee ON hr.payslips (employee_id);

-- ===== Phase 8: 勞健保 + 所得稅 =====

CREATE TABLE hr.insurance_grades (
  id bigserial PRIMARY KEY,
  effective_year int NOT NULL,
  scheme text NOT NULL CHECK (scheme IN ('labor', 'health')),
  grade int NOT NULL,
  monthly_salary_min numeric(10,2) NOT NULL,
  monthly_salary_max numeric(10,2) NOT NULL,
  insured_amount numeric(10,2) NOT NULL,
  notes text,
  UNIQUE (effective_year, scheme, grade)
);
CREATE INDEX idx_insurance_lookup ON hr.insurance_grades (effective_year, scheme, monthly_salary_min);

ALTER TABLE hr.employees
  ADD COLUMN insured_amount_labor numeric(10,2),
  ADD COLUMN insured_amount_health numeric(10,2),
  ADD COLUMN dependents_count int DEFAULT 0;

CREATE TABLE hr.insurance_filings (
  id bigserial PRIMARY KEY,
  period_label text NOT NULL,
  employee_id bigint NOT NULL REFERENCES hr.employees(id),
  insured_amount_labor numeric(10,2),
  insured_amount_health numeric(10,2),
  labor_employer numeric(10,2),
  labor_employee numeric(10,2),
  labor_government numeric(10,2),
  unemployment_employer numeric(10,2),
  unemployment_employee numeric(10,2),
  health_employer numeric(10,2),
  health_employee numeric(10,2),
  health_government numeric(10,2),
  pension_employer numeric(10,2),
  pension_voluntary numeric(10,2),
  filed_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  UNIQUE (period_label, employee_id)
);

CREATE TABLE hr.tax_withholdings (
  id bigserial PRIMARY KEY,
  year int NOT NULL,
  employee_id bigint NOT NULL REFERENCES hr.employees(id),
  total_paid numeric(12,2) DEFAULT 0,
  total_withheld numeric(10,2) DEFAULT 0,
  bonus_50_total numeric(12,2) DEFAULT 0,
  filed_at timestamptz,
  filing_pdf_url text,
  created_at timestamptz DEFAULT now(),
  UNIQUE (year, employee_id)
);

CREATE TRIGGER trg_shift_templates_updated_at BEFORE UPDATE ON hr.shift_templates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_shifts_updated_at BEFORE UPDATE ON hr.shifts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_leave_requests_updated_at BEFORE UPDATE ON hr.leave_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_payslips_updated_at BEFORE UPDATE ON hr.payslips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE hr.national_holidays       ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.shift_templates         ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.shifts                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.leave_types             ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.annual_leave_balances   ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.leave_requests          ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.payroll_settings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.payroll_periods         ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.payslips                ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.insurance_grades        ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.insurance_filings       ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.tax_withholdings        ENABLE ROW LEVEL SECURITY;

CREATE POLICY svc_all ON hr.national_holidays     FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.shift_templates       FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.shifts                FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.leave_types           FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.annual_leave_balances FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.leave_requests        FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.payroll_settings      FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.payroll_periods       FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.payslips              FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.insurance_grades      FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.insurance_filings     FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY svc_all ON hr.tax_withholdings      FOR ALL TO service_role USING (true) WITH CHECK (true);
