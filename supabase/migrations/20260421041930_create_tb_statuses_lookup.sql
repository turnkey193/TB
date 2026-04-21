-- Mirror of migration applied to Supabase (version: 20260421041930)
-- Phase 3: 狀態 lookup table，取代先前散落的自由文字狀態值
-- 採用 code 為 PK（全域唯一），domain 作為分類（note / payment）

CREATE TABLE IF NOT EXISTS tb_statuses (
  code text PRIMARY KEY,
  domain text NOT NULL,
  label text NOT NULL,
  sort_order int DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_statuses_domain ON tb_statuses(domain);
ALTER TABLE tb_statuses ENABLE ROW LEVEL SECURITY;

INSERT INTO tb_statuses (code, domain, label, sort_order) VALUES
('未處理', 'note', '未處理', 1),
('處理中', 'note', '處理中', 2),
('已處理', 'note', '已處理', 3),
('時間未到', 'payment', '時間未到', 1),
('已收款', 'payment', '已收款', 2),
('收款異常', 'payment', '收款異常', 3)
ON CONFLICT (code) DO NOTHING;
