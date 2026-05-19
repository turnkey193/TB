-- tb-cases Phase 1.1.2: tb_regions 加 code 欄位（給 case_no 用）
-- 設計依據: DECISIONS §4

ALTER TABLE public.tb_regions
  ADD COLUMN IF NOT EXISTS code text;

-- 寫入 8 個分店 code（依分店名英譯首字母）
UPDATE public.tb_regions SET code = 'WG' WHERE name = '五股' AND code IS NULL;
UPDATE public.tb_regions SET code = 'BC' WHERE name = '板橋' AND code IS NULL;
UPDATE public.tb_regions SET code = 'DM' WHERE name = '東門' AND code IS NULL;
UPDATE public.tb_regions SET code = 'TY' WHERE name = '桃園' AND code IS NULL;
UPDATE public.tb_regions SET code = 'GS' WHERE name = '龜山' AND code IS NULL;
UPDATE public.tb_regions SET code = 'HC' WHERE name = '新竹' AND code IS NULL;
UPDATE public.tb_regions SET code = 'WR' WHERE name = '烏日' AND code IS NULL;
UPDATE public.tb_regions SET code = 'SN' WHERE name = '水湳' AND code IS NULL;

-- 確認 8 個都有設到（如果未來加新分店、要先設 code 才能 NOT NULL）
-- 不在這版加 NOT NULL constraint，避免未來新增區域時 migration 卡住
-- 但加 UNIQUE constraint
ALTER TABLE public.tb_regions
  ADD CONSTRAINT tb_regions_code_unique UNIQUE (code);

COMMENT ON COLUMN public.tb_regions.code IS '分店代碼，用於案件編號 case_no 前綴（WG/BC/DM/TY/GS/HC/WR/SN）';
