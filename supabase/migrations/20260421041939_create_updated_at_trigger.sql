-- Mirror of migration applied to Supabase (version: 20260421041939)
-- Phase 3: updated_at 自動更新觸發器，每張有 updated_at 的表都掛上

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN
    SELECT unnest(ARRAY[
      'tb_regions', 'tb_users', 'tb_weekly_notes', 'tb_payment_records',
      'tb_expected_signs', 'tb_project_notes', 'tb_case_notes',
      'tb_annual_targets', 'tb_statuses'
    ])
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', tbl, tbl);
    EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', tbl, tbl);
  END LOOP;
END $$;
