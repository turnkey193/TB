-- Mirror of migration applied to Supabase (version: 20260420041543)
-- Source of truth: supabase_migrations.schema_migrations on project obgobetnlecbmypvfnsq
-- Purpose: create tb_regions (region master table) and seed initial 8 regions with Google Sheet IDs

CREATE TABLE tb_regions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  case_sheet text,
  work_sheet text,
  case_tab text DEFAULT '進度統計',
  sort_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE tb_regions DISABLE ROW LEVEL SECURITY;

INSERT INTO tb_regions (name, case_sheet, work_sheet, case_tab, sort_order) VALUES
('台北', '125VgLseiFPJGEpNa_9YtkDHbccI83SfoURDP9o0jCT8', '1opyfWp6KtDmTtjoXTU0QtBi9BsP4xlOs5uYeR41zspA', '進度統計', 1),
('台中', '14br_f5FdfPdArlmqKQw8h6FlpAPVglBZ4FN4T6bMyb4', '1vNB-JtXW65WLP7LcEyo6JFHBPZ4S7M18O5VBAC4Id6I', '案件追蹤表', 2),
('桃園', '1E1G4qnmS4-VVJaPwWoHXVuXlPadWl5DFZ6J_MhQwD-U', '1G55jJSUY6eaAP1MtOBTm9xyiJY-NlI_CmjEq6FSHZX8', '進度統計', 3),
('新竹', '1Bf8tEYeyUDUL2caynb5NLF85_1J5H7tv4TxtMvznnxY', '1--Txe1YbdOHkN3hbqA4VRtWvGQpr_bidfvMA1lJ1aqI', '進度統計', 4),
('龜山', '1VbvliGjs3x4_dwbc4nD6yJJcz0S-ULakgCnj3WiAuqc', '1UfH1GLJsbrYOg0WuE8OMJulmUrMPc6rLdnCa0OV9c4Y', '進度統計', 5),
('框框', '1MLXs8Y5fbV6tbxlFTDxdM5pbovyiMKmxXh6f0UXaVRo', '1YJ7g1fNq3xp-vsP4x7OtKlW6ICtxxBzHXVdjogStx-Q', '進度統計', 6),
('板橋', null, '1JDC69yUIvXcu-MCO8bQ2MxoUZmxM6YBtTMrPjYd_7HM', null, 7),
('水湳', '1TAkax9fp3QtEvUkZIhfYSr_cxXM_Lc-0mOt8sn9P6F0', '1Bnkz8_YOPEDlcdI2swV8x8BQ7CoxKW46U4OsanCTYtY', '進度統計', 8);
