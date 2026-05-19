-- ─────────────────────────────────────────────────────────────
-- Portal access matrix: per-employee × per-subsystem allowlist
-- See memory: tb_portal_access_matrix_design.md
--
-- Design decisions:
--   Q1. 預設全不給：新員工不會自動有 row（admin 手動開）
--   Q2. role='admin' 自動繞過：code 層判斷，DB 不為 admin 配對
--   Q3. portal exchange token 塞 sys[]，子系統二次驗證
-- ─────────────────────────────────────────────────────────────

create table if not exists hr.employee_subsystem_access (
  employee_id  bigint not null references hr.employees(id) on delete cascade,
  subsystem_id text   not null,
  granted_at   timestamptz not null default now(),
  granted_by   bigint references hr.employees(id) on delete set null,
  primary key (employee_id, subsystem_id),
  constraint employee_subsystem_access_subsystem_check
    check (subsystem_id in ('tb-hr', 'tb-org', 'tb-meeting', 'tb-gantt', 'tb-drive'))
);

comment on table hr.employee_subsystem_access is
  'Portal SSO 權限矩陣：哪個員工能進哪個子系統。role=admin 自動繞過此表（code 端判斷）。';

create index if not exists employee_subsystem_access_subsystem_idx
  on hr.employee_subsystem_access (subsystem_id);

-- 預設不開 RLS，portal/各子系統用 service_role key 直連繞過 RLS
-- 將來若要前端直連 supabase 才需要加 policy
