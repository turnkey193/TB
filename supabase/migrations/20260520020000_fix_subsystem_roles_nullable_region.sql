-- cases.subsystem_roles：support 角色 region_id 須能為 NULL
--
-- 原本 PK = (employee_id, role_code, region_id)，PK 隱含 NOT NULL → support 沒法存
-- 改為：bigserial id PK + UNIQUE NULLS NOT DISTINCT (employee_id, role_code, region_id)
-- 需要 PostgreSQL ≥ 15

ALTER TABLE cases.subsystem_roles
  DROP CONSTRAINT subsystem_roles_pkey;

ALTER TABLE cases.subsystem_roles
  ADD COLUMN id bigserial PRIMARY KEY;

-- drop PK 不會自動拿掉 column 本身的 NOT NULL，需顯式
ALTER TABLE cases.subsystem_roles
  ALTER COLUMN region_id DROP NOT NULL;

ALTER TABLE cases.subsystem_roles
  ADD CONSTRAINT subsystem_roles_employee_role_region_uniq
  UNIQUE NULLS NOT DISTINCT (employee_id, role_code, region_id);
