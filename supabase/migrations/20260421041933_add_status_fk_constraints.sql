-- Mirror of migration applied to Supabase (version: 20260421041933)
-- Phase 3: 對狀態欄位加 FK，確保只能寫入 tb_statuses.code 裡的值

ALTER TABLE tb_weekly_notes
  ADD CONSTRAINT fk_weekly_notes_status
  FOREIGN KEY (status) REFERENCES tb_statuses(code);

ALTER TABLE tb_payment_records
  ADD CONSTRAINT fk_payment_contract_status
  FOREIGN KEY (contract_status) REFERENCES tb_statuses(code);

ALTER TABLE tb_payment_records
  ADD CONSTRAINT fk_payment_additional_status
  FOREIGN KEY (additional_status) REFERENCES tb_statuses(code);
