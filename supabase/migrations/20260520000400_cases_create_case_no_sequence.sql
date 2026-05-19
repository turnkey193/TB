-- tb-cases Phase 1.1.5: case_no 流水號管理
-- 設計依據: DECISIONS §4
--
-- 為每店每月獨立發號，建一張小型計數表（不用 sequence 因為要 partition by store+yyyymm）

CREATE TABLE cases.case_no_counters (
  store_code text NOT NULL,
  year_month text NOT NULL,                  -- 'YYYYMM'
  last_number integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (store_code, year_month)
);

ALTER TABLE cases.case_no_counters ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE cases.case_no_counters IS '案件編號流水號計數器：每店每月獨立。由 cases.next_case_no() 用 SELECT FOR UPDATE 鎖列發號';

-- 發號 helper function（atomic、上 row lock 防併發）
CREATE OR REPLACE FUNCTION cases.next_case_no(p_store_code text, p_fill_date date)
RETURNS text
LANGUAGE plpgsql
SET search_path = pg_catalog, cases
AS $$
DECLARE
  v_yyyymm text;
  v_num integer;
BEGIN
  IF p_store_code IS NULL OR p_store_code = '' THEN
    p_store_code := 'HQ';
  END IF;

  v_yyyymm := to_char(COALESCE(p_fill_date, CURRENT_DATE), 'YYYYMM');

  -- UPSERT 計數
  INSERT INTO cases.case_no_counters (store_code, year_month, last_number)
  VALUES (p_store_code, v_yyyymm, 1)
  ON CONFLICT (store_code, year_month)
  DO UPDATE SET
    last_number = cases.case_no_counters.last_number + 1,
    updated_at = now()
  RETURNING last_number INTO v_num;

  RETURN p_store_code || '-' || v_yyyymm || '-' || lpad(v_num::text, 3, '0');
END;
$$;

COMMENT ON FUNCTION cases.next_case_no(text, date) IS '發案件編號: cases.next_case_no(''WG'', ''2026-05-19'') → ''WG-202605-001''';
