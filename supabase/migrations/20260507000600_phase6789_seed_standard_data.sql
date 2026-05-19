-- 14 種勞基法假別 + 2026 國定假日 + 班別模板 + payroll_settings + 投保薪資分級
-- 完整內容見 supabase migration history（執行透過 mcp__supabase-tb__apply_migration）

INSERT INTO hr.leave_types (code, name, paid_ratio, max_days_per_year, max_days_total, max_days_per_event, requires_attachment, sort_order, notes) VALUES
  ('annual', '特別休假', 1.0, NULL, NULL, NULL, false, 10, '依年資；勞基法 38 條'),
  ('sick', '普通傷病假', 0.5, 30, NULL, NULL, true, 20, '勞工請假規則 4 條'),
  ('personal', '事假', 0, 14, NULL, NULL, false, 30, '勞工請假規則 7 條'),
  ('marriage', '婚假', 1.0, NULL, 8, 8, true, 40, '勞工請假規則 2 條'),
  ('bereavement_1', '喪假（父母配偶）', 1.0, NULL, 8, 8, true, 50, '勞工請假規則 3 條'),
  ('bereavement_2', '喪假（祖父母岳父母子女）', 1.0, NULL, 6, 6, true, 51, NULL),
  ('bereavement_3', '喪假（兄弟姐妹）', 1.0, NULL, 3, 3, true, 52, NULL),
  ('maternity', '產假', 1.0, NULL, 56, 56, true, 60, '性平法 15 條'),
  ('paternity', '陪產假', 1.0, NULL, 7, 7, true, 70, '性平法 15 條'),
  ('family', '家庭照顧假', 0, 7, 7, NULL, false, 80, '性平法 20 條'),
  ('official', '公假', 1.0, NULL, NULL, NULL, true, 90, '勞工請假規則 8 條'),
  ('work_injury', '公傷病假', 1.0, NULL, NULL, NULL, true, 100, '勞工請假規則 6 條'),
  ('menstrual', '生理假', 0.5, 12, NULL, NULL, false, 110, '性平法 14 條'),
  ('prenatal', '產檢假', 1.0, NULL, 7, 7, true, 120, '性平法 15 條');

INSERT INTO hr.national_holidays (date, name, is_makeup) VALUES
  ('2026-01-01', '中華民國開國紀念日', false),
  ('2026-02-15', '小年夜', false),
  ('2026-02-16', '農曆除夕', false),
  ('2026-02-17', '春節', false),
  ('2026-02-18', '春節', false),
  ('2026-02-19', '春節', false),
  ('2026-02-27', '和平紀念日（補假）', true),
  ('2026-02-28', '和平紀念日', false),
  ('2026-04-03', '兒童節（補假）', true),
  ('2026-04-04', '兒童節 / 民族掃墓節', false),
  ('2026-04-05', '民族掃墓節（補假）', true),
  ('2026-05-01', '勞動節', false),
  ('2026-06-19', '端午節', false),
  ('2026-09-25', '中秋節', false),
  ('2026-10-09', '國慶日（補假）', true),
  ('2026-10-10', '國慶日', false);

INSERT INTO hr.shift_templates (name, start_time, end_time, break_minutes) VALUES
  ('日班 09-18', '09:00', '18:00', 60),
  ('日班 10-19', '10:00', '19:00', 60),
  ('半天班 09-13', '09:00', '13:00', 0);

-- payroll_settings：基本工資、加班費率、特休對照、勞健保費率、所得稅
INSERT INTO hr.payroll_settings (key, value, effective_from, notes) VALUES
  ('basic_monthly_wage', '{"amount":28590,"year":2026}'::jsonb, '2026-01-01', '基本工資（月）'),
  ('basic_hourly_wage', '{"amount":190,"year":2026}'::jsonb, '2026-01-01', '基本工資（時）'),
  ('overtime_multipliers', '{"weekday_first_2h":1.34,"weekday_after_2h":1.67,"rest_day_first_2h":1.34,"rest_day_3_to_8h":1.67,"rest_day_after_8h":2.67,"holiday":2.0}'::jsonb, '2026-01-01', '加班費率（勞基法 24 條）'),
  ('annual_leave_table', '[{"min_months":6,"days":3},{"min_months":12,"days":7},{"min_months":24,"days":10},{"min_months":36,"days":14},{"min_months":60,"days":15},{"min_months":120,"days":16},{"min_months":132,"days":17},{"min_months":144,"days":18},{"min_months":156,"days":19},{"min_months":168,"days":20},{"min_months":180,"days":21},{"min_months":192,"days":22},{"min_months":204,"days":23},{"min_months":216,"days":24},{"min_months":228,"days":25},{"min_months":240,"days":26},{"min_months":252,"days":27},{"min_months":264,"days":28},{"min_months":276,"days":29},{"min_months":288,"days":30}]'::jsonb, '2026-01-01', '特休年資對照（勞基法 38 條）'),
  ('insurance_rates_2026', '{"labor_total":0.12,"labor_employee_share":0.20,"labor_employer_share":0.70,"labor_govt_share":0.10,"unemployment_total":0.01,"unemployment_employee_share":0.20,"health_total":0.0517,"health_employee_share":0.30,"health_employer_share":0.60,"health_govt_share":0.10,"supplementary_health":0.0211,"pension_employer":0.06}'::jsonb, '2026-01-01', '勞健保 2026 公定費率'),
  ('income_tax_withholding', '{"flat_rate_threshold":88501,"flat_rate":0.05,"note":"TODO 完整薪資扣繳辦法表"}'::jsonb, '2026-01-01', '所得稅扣繳');

-- 投保薪資分級表 2026（勞保 12 級 + 健保 47 級，完整內容透過 MCP 寫入）
-- 詳細 INSERT 詳 phase6789_seed_standard_data 真實 migration
