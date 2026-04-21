# ADR-0002: RLS 採用 Backend-only 模式

**日期**：2026-04-21
**Phase**：4
**狀態**：採用

## Context

Supabase 全表啟用 RLS 後，需要決定授權模型。兩個選項：
- **Option A**：後端獨佔模式 — 前端永遠透過 Express 後端，後端用 `service_role` key 繞過 RLS
- **Option B**：Supabase Auth 模式 — 前端直接 call PostgREST，RLS 依 `auth.uid()` 與 `tb_user_regions` 寫 per-row 政策

## Decision

採用 **Option A（後端獨佔）**。

## Rationale

- **TB project 前端全部走 `fetch('/api/...')`**，沒有直接 call Supabase REST/Realtime 的程式碼
- **RLS 只需要「全擋」即可**：不建 anon/authenticated 政策，預設拒絕；`service_role` 自動繞過
- **最小攻擊面**：anon key 就算外洩也讀不到業務資料（只能打到幾個不存在的政策 → 空回應）
- **不用寫 per-row 政策**：實作複雜度大幅降低，也不用做 `auth.uid()` 對應 `tb_users.id` 的映射
- **未來仍可升級**：若之後要讓前端直連（即時訂閱、Realtime），再走 Option B 新增政策即可

## 實作

Migration：`20260421042140_enable_rls_on_all_public_tables.sql`

```sql
ALTER TABLE tb_regions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_weekly_notes    ENABLE ROW LEVEL SECURITY;
-- ... 共 7 張表
```

`tb_users` / `tb_user_regions` / `tb_statuses` 在先前 migration 已啟用，共 10 張表全覆蓋。

不建立任何政策 = anon 與 authenticated 全部拒絕。

## server.js 配套

把 `supaHeaders` 從 anon key 改成 `service_role` key：
- 前端只會 call `/api/*`（走 Express 後端）
- 後端以 service_role 身分讀寫 Supabase，不受 RLS 影響
- `SUPABASE_KEY`（anon）保留在 .env 中供未來 Supabase Auth 場景使用

## Trade-offs

| 優點 | 缺點 |
|---|---|
| 實作簡單、攻擊面最小 | 無法用 Supabase Realtime 直接訂閱 |
| 不用維護 per-row 政策 | Backend 是單點（掛了整個 app 就掛） |
| anon key 外洩影響有限 | 未來要支援多租戶需要重新設計 |

## 驗證

```bash
# 用 anon key call REST 應回空陣列（RLS 過濾）
curl -H "apikey: $ANON_KEY" "$SUPABASE_URL/rest/v1/tb_payment_records?select=id&limit=1"
# => []

# 用 service_role key 能正常讀
curl -H "apikey: $SERVICE_KEY" "$SUPABASE_URL/rest/v1/tb_payment_records?select=id&limit=1"
# => [{"id":"..."}]
```
