-- tb-cases Phase 1.1.4: 案件主表
-- 設計依據: DECISIONS §5

CREATE TABLE cases.cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- 編號
  case_no text UNIQUE,                                    -- '<store_code>-<YYYYMM>-<###>', 派發後生成
  case_no_legacy text,                                    -- 舊資料原始項次/編號保留

  -- 來自 SurveyCake / 案件總表（20 欄）
  fill_date date NOT NULL,                                -- 「填單時間」
  region_id uuid REFERENCES public.tb_regions(id),        -- 派發後填入；初始為 null
  region_hint text,                                       -- SurveyCake 原始「區域」字串
  measurement_fee text,                                   -- 「丈量費」
  customer_name text NOT NULL,                            -- 「姓名」
  customer_gender text,                                   -- 「性別」
  customer_phone text NOT NULL,                           -- 「手機」
  customer_line text,                                     -- 「LINE」
  customer_role text,                                     -- 「角色」
  property_condition text,                                -- 「屋況」
  property_age text,                                      -- 「屋齡」
  preferred_appointment text,                             -- 「預約時段」
  preferred_contact_time text,                            -- 「聯繫時段」
  property_size text,                                     -- 「坪數」
  customer_status_raw text,                               -- 「進度」（raw text，DECISIONS Q9 不結構化）
  budget text,                                            -- 「預算」
  address text NOT NULL,                                  -- 「地址」
  intake_form_code text REFERENCES cases.intake_sources(code),
  invalid_form boolean NOT NULL DEFAULT false,            -- 「無效填單」
  invalid_reason text,                                    -- 「無效情況」
  intake_notes text NOT NULL DEFAULT '',                  -- 「接洽備註」

  -- 狀態機（DECISIONS §6）
  status text NOT NULL DEFAULT 'pending_screening',

  -- 派發
  assigned_employee_id bigint REFERENCES hr.employees(id),
  assigned_employee_name_legacy text,                     -- 舊資料對不到員工時保留字串
  assigned_at timestamptz,
  dispatched_by_employee_id bigint REFERENCES hr.employees(id),
  dispatched_at timestamptz,

  -- 客服篩選
  screened_by_employee_id bigint REFERENCES hr.employees(id),
  screening_called_at timestamptz,
  screening_outcome text,                                 -- '未接' | '已聯繫' | '客戶拒絕' | '轉派'
  screening_notes text NOT NULL DEFAULT '',

  -- 節點日期（DECISIONS §5.4）
  measure_date date,
  frame_date date,
  plan_date date,
  quote_date date,
  sign_date date,
  quote_amount integer NOT NULL DEFAULT 0,
  contract_amount integer NOT NULL DEFAULT 0,

  -- 元欄位
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  -- check constraints
  CONSTRAINT cases_status_check CHECK (status IN (
    'pending_screening', 'pending_dispatch', 'in_progress', 'signed', 'lost', 'paused'
  )),
  CONSTRAINT cases_screening_outcome_check CHECK (
    screening_outcome IS NULL OR screening_outcome IN ('未接', '已聯繫', '客戶拒絕', '轉派')
  ),
  CONSTRAINT cases_invalid_reason_check CHECK (
    invalid_reason IS NULL OR invalid_reason IN ('局部裝修', '預算不足', '重複填單', '非服務區域')
  )
);

-- 索引（依常用查詢）
CREATE INDEX idx_cases_status ON cases.cases (status, updated_at DESC);
CREATE INDEX idx_cases_assigned ON cases.cases (assigned_employee_id, status) WHERE assigned_employee_id IS NOT NULL;
CREATE INDEX idx_cases_region ON cases.cases (region_id, status) WHERE region_id IS NOT NULL;
CREATE INDEX idx_cases_fill_date ON cases.cases (fill_date DESC);
CREATE INDEX idx_cases_phone ON cases.cases (customer_phone);
CREATE INDEX idx_cases_case_no_legacy ON cases.cases (case_no_legacy) WHERE case_no_legacy IS NOT NULL;
CREATE INDEX idx_cases_intake_form ON cases.cases (intake_form_code);

CREATE TRIGGER set_cases_updated_at
  BEFORE UPDATE ON cases.cases
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE cases.cases ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.cases IS '案件主表: SurveyCake → tb-cases POST /api/intake 寫入。狀態機見 DECISIONS §6';
COMMENT ON COLUMN cases.cases.customer_status_raw IS '客戶現況勾選原始文字（沒設計圖 / 沒報價單 / 沒丈量過 / 沒施工）；不結構化（DECISIONS Q9）';
COMMENT ON COLUMN cases.cases.case_no IS '正式編號 <store_code>-<YYYYMM>-<###>，派發後生成；待篩選期暫為 null 或 HQ- 前綴';
COMMENT ON COLUMN cases.cases.region_hint IS 'SurveyCake 原始「區域」字串（例「新北市 New taipei」），給客服派發 UI 預設候選用';
