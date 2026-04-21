-- Mirror of migration applied to Supabase (version: 20260421041128)
-- Phase 1: 新增 bcrypt hash 欄位，準備取代明碼 password
-- 套用後要跑 scripts/hash-existing-passwords.mjs 把現有明碼 hash 進來

ALTER TABLE tb_users ADD COLUMN IF NOT EXISTS password_hash text;
