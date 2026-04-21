# Supabase Migrations

本資料夾是 Supabase 專案 `obgobetnlecbmypvfnsq` 的 migration 版本控制鏡像。

## 真實來源

Migration 的真實來源是 Supabase 的 `supabase_migrations.schema_migrations` 資料表。
本資料夾的 `.sql` 檔案是人為同步的鏡像，用於 git 版本控制和 code review。

## 執行方式

Migrations **不透過** Supabase CLI 執行，而是透過 **Claude Code + Supabase MCP**：

```
mcp__supabase-tb__apply_migration(name="my_migration_name", query="...")
```

執行完後，手動把 SQL 複製到本資料夾對應的檔案：
- 檔名格式：`YYYYMMDDHHMMSS_snake_case_name.sql`
- 時間戳用 `mcp__supabase-tb__list_migrations` 回傳的 version

## 檔名慣例

| 格式 | 範例 |
|---|---|
| `<version>_<name>.sql` | `20260420041543_create_tb_regions_and_seed.sql` |

version 就是 Supabase migration 系統產生的 UTC 時間戳（YYYYMMDDHHMMSS）。

## 既有 Migrations（截至 2026-04-21）

| Version | Name | 說明 |
|---|---|---|
| 20260415065437 | add_payment_new_columns | 擴充 `tb_payment_records` 合約金額/狀態欄位 |
| 20260415070401 | create_case_notes | 建立 `tb_case_notes` |
| 20260420033359 | create_tb_annual_targets | 建立 `tb_annual_targets` |
| 20260420041543 | create_tb_regions_and_seed | 建立 `tb_regions` 並塞 8 個區域種子資料 |

## 早期手動建立的表（**不在 migration 追蹤範圍內**）

以下表是在 migration 系統建立前手動從 Supabase Dashboard 建立的，**沒有對應的 migration 檔**：

- `tb_users` — 使用者帳號（15 rows）
- `tb_weekly_notes` — 週會筆記（0 rows）
- `tb_payment_records` — 請款紀錄（38 rows，欄位後來用 migration 擴充）
- `tb_expected_signs` — 預計簽約（0 rows）
- `tb_project_notes` — 工程筆記（8 rows）

這些表的當前結構可在 `docs/schema/public.md` 查到。Phase 1+ 的修改會以 migration 形式記錄。

## 之後的新增 migration

1. 先設計 SQL
2. 用 `mcp__supabase-tb__apply_migration(name, query)` 套用到 DB
3. 用 `mcp__supabase-tb__list_migrations` 拿到實際的 version 時間戳
4. 在本資料夾新增 `<version>_<name>.sql`，貼上同樣的 SQL 內容
5. Git commit
