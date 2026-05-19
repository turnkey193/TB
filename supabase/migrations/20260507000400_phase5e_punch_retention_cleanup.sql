-- Phase 5e: 5 年保存 + 自動清理（勞基法保存期限）
-- 設計：DB 端排程刪老 punch + 排隊老照片路徑供之後清 Storage
-- 不直接刪 storage.objects（Supabase Storage 物理檔案需 API 處理，避免 orphan）

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 紀錄需要清的 Storage 物件路徑（之後 Edge Function 跑批刪）
CREATE TABLE hr.orphan_photos (
  id bigserial PRIMARY KEY,
  bucket_id text NOT NULL DEFAULT 'hr-punch-photos',
  path text NOT NULL,
  reason text,
  detected_at timestamptz DEFAULT now(),
  cleaned_at timestamptz
);
CREATE INDEX idx_orphan_uncleaned ON hr.orphan_photos (detected_at) WHERE cleaned_at IS NULL;

ALTER TABLE hr.orphan_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY svc_all ON hr.orphan_photos FOR ALL TO service_role USING (true) WITH CHECK (true);
GRANT ALL ON hr.orphan_photos TO service_role;
GRANT ALL ON SEQUENCE hr.orphan_photos_id_seq TO service_role;

CREATE OR REPLACE FUNCTION hr.cleanup_old_punches()
RETURNS TABLE (deleted_punches int, orphan_photos_recorded int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hr, public
AS $$
DECLARE
  cutoff timestamptz := now() - interval '5 years';
  d_count int;
  o_count int;
BEGIN
  WITH old AS (
    SELECT id, selfie_url, site_photo_url
    FROM hr.punches
    WHERE punched_at < cutoff
  ),
  inserted AS (
    INSERT INTO hr.orphan_photos (path, reason)
    SELECT path, 'punch_retention_5y'
    FROM old
    CROSS JOIN LATERAL (
      VALUES (selfie_url), (site_photo_url)
    ) AS t(path)
    WHERE path IS NOT NULL
    RETURNING 1
  )
  SELECT COUNT(*) INTO o_count FROM inserted;

  DELETE FROM hr.punch_reviews
  WHERE punch_id IN (SELECT id FROM hr.punches WHERE punched_at < cutoff);

  DELETE FROM hr.punches WHERE punched_at < cutoff;
  GET DIAGNOSTICS d_count = ROW_COUNT;

  RETURN QUERY SELECT d_count, o_count;
END;
$$;

REVOKE ALL ON FUNCTION hr.cleanup_old_punches() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION hr.cleanup_old_punches() TO service_role;

-- 每天凌晨 3 點台北時間（= UTC 19:00）跑一次
SELECT cron.schedule(
  'hr-cleanup-old-punches',
  '0 19 * * *',
  $job$ SELECT hr.cleanup_old_punches() $job$
);

COMMENT ON TABLE hr.orphan_photos IS
  'Storage 物件清單，等待 Edge Function 批次從 hr-punch-photos bucket 刪除。cleaned_at 為 NULL 代表尚未清。';
