-- Mirror of migration applied to Supabase (version: 20260421042140)
-- Phase 4: 全表啟用 RLS
-- 不建立任何政策 = anon 與 authenticated 預設全部拒絕
-- service_role 自動繞過 RLS，後端 (Express 用 service_role key) 不受影響

ALTER TABLE tb_regions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_weekly_notes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_payment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_expected_signs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_project_notes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_case_notes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_annual_targets  ENABLE ROW LEVEL SECURITY;
-- tb_users / tb_user_regions / tb_statuses 已在先前的 migration 啟用
