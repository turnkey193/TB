-- Mirror of migration applied to Supabase (version: 20260421041537)
-- Phase 2: 取代 tb_users.region 的逗號分隔字串，改用中間表

CREATE TABLE IF NOT EXISTS tb_user_regions (
  user_id uuid NOT NULL REFERENCES tb_users(id) ON DELETE CASCADE,
  region_id uuid NOT NULL REFERENCES tb_regions(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, region_id)
);

CREATE INDEX IF NOT EXISTS idx_user_regions_region_id ON tb_user_regions(region_id);
ALTER TABLE tb_user_regions ENABLE ROW LEVEL SECURITY;

-- 套用完後跑 backfill（從 tb_users.region 的逗號分隔字串拆入中間表）：
--   INSERT INTO tb_user_regions (user_id, region_id)
--   SELECT u.id, r.id
--   FROM tb_users u
--   CROSS JOIN LATERAL unnest(string_to_array(u.region, ',')) AS raw_name
--   JOIN tb_regions r ON r.name = btrim(raw_name)
--   WHERE u.region IS NOT NULL AND btrim(u.region) <> ''
--   ON CONFLICT DO NOTHING;
