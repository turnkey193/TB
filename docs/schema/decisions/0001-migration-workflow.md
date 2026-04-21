# ADR-0001: Migration 工作流程用 MCP + 本地鏡像

**日期**：2026-04-21
**Phase**：0
**狀態**：採用

## Context

Supabase 專案已有 4 個 migration 追蹤在 `supabase_migrations.schema_migrations`，但本地 repo 沒有對應的 `.sql` 檔案。未來所有 schema 改動都該有版本控制，才能 code review、rollback、協作。

## Decision

- **真實來源**：Supabase 的 `supabase_migrations.schema_migrations` 資料表
- **執行工具**：Claude Code + Supabase MCP (`mcp__supabase-tb__apply_migration`)
- **本地鏡像**：`supabase/migrations/<version>_<name>.sql` — 人工同步，用於 git 版本控制
- **不用 Supabase CLI**：避免需要本地安裝 Docker 和額外的驗證環境

## 為什麼不用 Supabase CLI

- 使用者用 Windows + VSCode，CLI 環境較複雜
- Supabase MCP 已經整合在 Claude Code 裡，apply + list + query 都一條龍
- Migration 數量目前很少（< 10），人工鏡像成本低

## 為什麼本地要有鏡像

- Git 才能 review 改動
- 本地可以搜 `grep` 歷史變更
- 若 Supabase 資料清空、或要部署到新專案，本地鏡像就是重建腳本

## 規則

1. 新增 migration：先寫 SQL → `apply_migration` → `list_migrations` 拿 version → 建本地 `.sql` 檔
2. 檔名：`YYYYMMDDHHMMSS_snake_case_name.sql`
3. 頂部註解寫：來源、版本、用途
4. Git commit 裡 `.sql` 檔是唯一來源，審查看這個

## Trade-offs

- ❌ 人工同步可能漏掉（mitigation: Phase 0 結束列了所有已知 migration；之後每次 apply 要立刻寫檔）
- ❌ 若有 DB drift（有人直接在 Dashboard 改），鏡像會失準（mitigation: 禁止 Dashboard 手動改 DDL，所有變更走 migration）
