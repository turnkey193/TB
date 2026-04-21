-- Mirror of migration applied to Supabase (version: 20260421041323)
-- Phase 1: password_hash 已回填完畢且 server.js 已切換到 bcrypt.compare，
--         此 migration 正式刪除明碼 password 欄位。

ALTER TABLE tb_users DROP COLUMN password;
