-- 註冊 tb-cases 子系統到 hr.portal_subsystems
-- tb-portal 從這張表動態載入磚塊清單（5 分鐘快取）

INSERT INTO hr.portal_subsystems (id, name, description, icon, color, url_env_key, sort_order, is_active)
VALUES
  ('tb-cases', '案件管理', 'SurveyCake / N8N → 線上案件追蹤、客服派發、業務跟進、SLA 異常監控', '🗂️', '#1A2B4B', 'SUBSYS_TB_CASES', 7, true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  color = EXCLUDED.color,
  url_env_key = EXCLUDED.url_env_key,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = now();
