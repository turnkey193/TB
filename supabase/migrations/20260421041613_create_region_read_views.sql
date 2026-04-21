-- Mirror of migration applied to Supabase (version: 20260421041613)
-- Phase 2: 讀取端 views，把 region_id 和 region_name 一起曝露給前端
-- 未來前端切換為使用 region_id 後，仍可保留 region_name 用於顯示

CREATE OR REPLACE VIEW v_tb_weekly_notes AS
  SELECT w.*, r.name AS region_name
  FROM tb_weekly_notes w
  LEFT JOIN tb_regions r ON r.id = w.region_id;

CREATE OR REPLACE VIEW v_tb_payment_records AS
  SELECT p.*, r.name AS region_name
  FROM tb_payment_records p
  LEFT JOIN tb_regions r ON r.id = p.region_id;

CREATE OR REPLACE VIEW v_tb_expected_signs AS
  SELECT e.*, r.name AS region_name
  FROM tb_expected_signs e
  LEFT JOIN tb_regions r ON r.id = e.region_id;

CREATE OR REPLACE VIEW v_tb_project_notes AS
  SELECT n.*, r.name AS region_name
  FROM tb_project_notes n
  LEFT JOIN tb_regions r ON r.id = n.region_id;

CREATE OR REPLACE VIEW v_tb_case_notes AS
  SELECT c.*, r.name AS region_name
  FROM tb_case_notes c
  LEFT JOIN tb_regions r ON r.id = c.region_id;

CREATE OR REPLACE VIEW v_tb_annual_targets AS
  SELECT t.*, r.name AS region_name
  FROM tb_annual_targets t
  LEFT JOIN tb_regions r ON r.id = t.region_id;

-- 使用者 → 區域清單 view（從 tb_user_regions 中間表聚合，fallback 到 tb_users.region 字串）
CREATE OR REPLACE VIEW v_tb_users_with_regions AS
  SELECT
    u.id,
    u.username,
    u.role,
    u.name,
    u.created_at,
    COALESCE(
      (SELECT string_agg(r.name, ',' ORDER BY r.sort_order)
       FROM tb_user_regions ur
       JOIN tb_regions r ON r.id = ur.region_id
       WHERE ur.user_id = u.id),
      u.region
    ) AS regions_csv,
    COALESCE(
      (SELECT array_agg(ur.region_id ORDER BY r.sort_order)
       FROM tb_user_regions ur
       JOIN tb_regions r ON r.id = ur.region_id
       WHERE ur.user_id = u.id),
      ARRAY[]::uuid[]
    ) AS region_ids
  FROM tb_users u;
