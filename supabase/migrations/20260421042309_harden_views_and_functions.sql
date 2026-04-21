-- Mirror of migration applied to Supabase (version: 20260421042309)
-- Phase 4 補強：修 Supabase security advisor 抓到的 2 個真實問題
-- 1) 所有 v_tb_* view 從 SECURITY DEFINER 改為 SECURITY INVOKER
--    → view 使用呼叫者的身分執行，RLS 正常生效，anon 不會繞過
-- 2) set_updated_at() 鎖定 search_path，避免 search_path 攻擊

ALTER VIEW v_tb_weekly_notes       SET (security_invoker = true);
ALTER VIEW v_tb_payment_records    SET (security_invoker = true);
ALTER VIEW v_tb_expected_signs     SET (security_invoker = true);
ALTER VIEW v_tb_project_notes      SET (security_invoker = true);
ALTER VIEW v_tb_case_notes         SET (security_invoker = true);
ALTER VIEW v_tb_annual_targets     SET (security_invoker = true);
ALTER VIEW v_tb_users_with_regions SET (security_invoker = true);

ALTER FUNCTION public.set_updated_at() SET search_path = pg_catalog, public;
