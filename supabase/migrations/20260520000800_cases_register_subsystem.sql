-- tb-cases Phase 1.1.9: 註冊到 tb-portal SSO 子系統清單 + service_role grants
-- 設計依據: DECISIONS §16，對齊 quotation register pattern

-- 1. 更新 hr.employee_subsystem_access 的 subsystem_id 字串清單註解
COMMENT ON TABLE hr.employee_subsystem_access IS
  '員工子系統 access。subsystem_id 字串列舉: tb-hr / tb-org / tb-meeting / tb-gantt / tb-drive / tb-quotation / tb-cases';

-- 2. service_role grants
GRANT USAGE ON SCHEMA cases TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA cases TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA cases TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cases TO service_role;

-- 之後新增的物件預設給 service_role
ALTER DEFAULT PRIVILEGES IN SCHEMA cases
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA cases
  GRANT USAGE, SELECT ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA cases
  GRANT EXECUTE ON FUNCTIONS TO service_role;
