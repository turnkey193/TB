-- tb-cases Phase 1.1.6: 案件子表（備註 / 工程筆記 / 請款記錄）
-- 設計依據: DECISIONS §3.1（全 uuid FK、從 public.tb_* 整批遷入）

-- 1. 案件備註（取代 public.tb_case_notes）
CREATE TABLE cases.case_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES cases.cases(id) ON DELETE CASCADE,
  note text NOT NULL DEFAULT '',
  author_employee_id bigint REFERENCES hr.employees(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_case_notes_case ON cases.case_notes (case_id, updated_at DESC);

CREATE TRIGGER set_case_notes_updated_at
  BEFORE UPDATE ON cases.case_notes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE cases.case_notes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.case_notes IS '案件備註: 從 public.tb_case_notes 遷入，改用 uuid FK';

-- 2. 工程筆記（取代 public.tb_project_notes）
CREATE TABLE cases.project_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES cases.cases(id) ON DELETE CASCADE,
  note text NOT NULL DEFAULT '',
  is_abnormal boolean NOT NULL DEFAULT false,
  author_employee_id bigint REFERENCES hr.employees(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_project_notes_case ON cases.project_notes (case_id, updated_at DESC);
CREATE INDEX idx_project_notes_abnormal ON cases.project_notes (case_id) WHERE is_abnormal = true;

CREATE TRIGGER set_project_notes_updated_at
  BEFORE UPDATE ON cases.project_notes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE cases.project_notes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.project_notes IS '工程筆記: 從 public.tb_project_notes 遷入，改用 uuid FK';

-- 3. 請款記錄（取代 public.tb_payment_records）
CREATE TABLE cases.payment_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES cases.cases(id) ON DELETE CASCADE,
  invoice_amount integer NOT NULL DEFAULT 0,
  received_amount integer NOT NULL DEFAULT 0,
  contract_amount integer NOT NULL DEFAULT 0,
  contract_status text NOT NULL DEFAULT '時間未到' REFERENCES public.tb_statuses(code),
  additional_amount integer NOT NULL DEFAULT 0,
  additional_status text NOT NULL DEFAULT '時間未到' REFERENCES public.tb_statuses(code),
  abnormal_note text NOT NULL DEFAULT '',
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_payment_records_case ON cases.payment_records (case_id, updated_at DESC);

CREATE TRIGGER set_payment_records_updated_at
  BEFORE UPDATE ON cases.payment_records
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE cases.payment_records ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.payment_records IS '請款記錄: 從 public.tb_payment_records 遷入，改用 uuid FK；contract_status / additional_status 仍接 public.tb_statuses';
