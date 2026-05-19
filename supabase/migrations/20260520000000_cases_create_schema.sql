-- tb-cases Phase 1.1.1: schema 與基礎設定
-- 設計依據: 行銷-案件資料/DECISIONS_2026-05-19.md
--
-- - 沿用 public.set_updated_at() 既有 trigger function
-- - 全表 enable RLS、不建任何政策 → anon/authenticated 預設拒絕、service_role 繞過
-- - 詳見 docs/schema/decisions/0002-rls-backend-only.md

CREATE SCHEMA IF NOT EXISTS cases;
COMMENT ON SCHEMA cases IS 'tb-cases 子系統: 線上案件追蹤表（取代 Google Sheet 工作流）';
