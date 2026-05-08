-- Phase 11a: Codex 第二輪 P0 修補

-- P0#3 簽約獎金 tier 邊界（4990001 → 5000000 對齊「500萬」）
UPDATE hr.bonus_rules SET config = '{
  "type":"tier_by_monthly_total","unit":"contract_excl_tax","tiers":[
    {"min":0,        "max":4999999,  "rate":0.005, "label":"0~499萬"},
    {"min":5000000,  "max":7999999,  "rate":0.010, "label":"500~799萬"},
    {"min":8000000,  "max":9999999,  "rate":0.015, "label":"800~999萬"},
    {"min":10000000, "max":null,     "rate":0.020, "label":"1000萬以上"}
  ]
}'::jsonb
WHERE rule_code = 'designer_signing';

-- P0#4 工程完工 gp_rate 19.00-19.99 死區（18.99 → 19.99）
UPDATE hr.bonus_rules SET config = '{
  "type":"tier_by_gross_profit_rate","tiers":[
    {"gp_rate_min":null, "gp_rate_max":19.99, "base":"contract_excl_tax", "rate":0.005, "label":"毛利率<20%"},
    {"gp_rate_min":20.00,"gp_rate_max":24.99, "base":"gross_profit",      "rate":0.030, "label":"毛利率20~24%"},
    {"gp_rate_min":25.00,"gp_rate_max":null,  "base":"gross_profit",      "rate":0.050, "label":"毛利率≥25%"}
  ]
}'::jsonb
WHERE rule_code = 'engineering_completion';

-- 勞保 / 就業保險費率走 settings（拿掉 hardcoded）
INSERT INTO hr.payroll_settings (key, value, effective_from, notes) VALUES
  ('labor_insurance_rate', '0.115'::jsonb, '2025-01-01', '勞保費率（114年）'),
  ('labor_insurance_employee_share', '0.20'::jsonb, '2025-01-01', '勞保員工負擔比例'),
  ('unemployment_insurance_rate', '0.01'::jsonb, '2025-01-01', '就業保險費率'),
  ('unemployment_insurance_employee_share', '0.20'::jsonb, '2025-01-01', '就業保險員工負擔比例')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, notes = EXCLUDED.notes, updated_at = now();
