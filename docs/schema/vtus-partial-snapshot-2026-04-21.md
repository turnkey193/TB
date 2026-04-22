# vtus (vtusdydfjfvipgdrgrlo) 局部快照 — 2026-04-21

> 在使用者刪除舊 project 之前，透過 Supabase MCP 查到的**局部**資料。
> 這**不是完整備份** —— customers / cases / construction_projects / construction_daily_logs / holidays 的**資料列內容沒有抓**，只有筆數。

## Tables & 筆數（刪除前）

| Table | RLS | Rows |
|---|---|---:|
| public.branches | enabled | 7 |
| public.users | enabled | 54 |
| public.customers | enabled | 3,013 |
| public.cases | enabled | 3,013 |
| public.holidays | enabled | 31 |
| public.construction_projects | enabled | 1,139 |
| public.designer_performance | enabled | 0 |
| public.surveycake_submissions | enabled | 0 |
| public.construction_daily_logs | enabled | 4,247 |
| public.tb_weekly_items | enabled | 0 |

## Schema（只抓了這三個）

### public.branches
- id (uuid)
- name (varchar)
- region (varchar)
- is_active (boolean)
- created_at (timestamptz)

### public.users
- id (uuid)
- name (varchar)
- role (varchar)
- branch_id (uuid) — FK → branches
- is_active (boolean)
- created_at (timestamptz)

### public.tb_weekly_items (空 table)
- id (uuid)
- branch_id (uuid)
- category (text)
- report_month (text)
- content (text)
- target (text)
- support_type (text)
- status (text)
- notes (text)
- created_at (timestamptz)
- updated_at (timestamptz)

## branches 完整資料（7 筆）

| name | region | is_active |
|---|---|---|
| 台中 | 台中 | true |
| 台中水湳店 | 台中 | true |
| 台北 | 台北 | true |
| 新竹 | 新竹 | true |
| 桃園 | 桃園 | true |
| 桃園2店 | 桃園 | true |
| 框框 | (null) | true |

## users 完整資料（54 筆，按分店排）

### 台中（13）
77, DILL, Johnny, 劉培柔, 婉儒, 施旻諭, 李忠修, 李忠修, 楊詠寗, 洪慈英, 設計師, 許哲維, 黃柏凱
（role 全為 designer，is_active=true）

### 台北（14）
博文, 名妤, 外-呂育泰, 外-李國和, 外-林郁家, 外-桂淂瑢, 宇聖, 宏達, 小耿, 揮乾, 聖傑, 阿契, 阿豪, 靜麒
（role 全為 designer，is_active=true）

### 新竹（2）
建誠, 陳思翰

### 桃園（13）
吳伃庭, 周郁智, 徐楷東, 李冠霖, 林靖容, 江欣芳, 沈婷, 蘇乙瑞, 陳俊佑, 陳建誠, 陳有田, 馬妍芃, 黃彥博

### 桃園2店（2）
劉佩靈, 徐楚涵

### 框框（9）
Denzel, Ivan, Juliata, Kelly, Rick, Yumi, 專案C, 專案L, 專案O

### 無分店（1）
管理員（role=admin）

## Migrations

- 20260414005130 — add_weekly_items_and_expected_contract（唯一一筆）

主要 schema 應該不是用 Supabase migration 建的（3013 筆 customers 但只有 1 筆 migration），可能是手動 SQL 或更早期 squash 過。

## 本次沒有抓到的內容

- customers (3,013 rows) — **沒有資料列**
- cases (3,013 rows) — **沒有資料列**
- construction_projects (1,139 rows) — **沒有資料列**
- construction_daily_logs (4,247 rows) — **沒有資料列**
- holidays (31 rows) — **沒有資料列**
- Edge Functions — 沒列
- 其他 schema (auth, storage 等) — 沒查

## 刪除後狀態（2026-04-21 確認）

- `get_project_url` 仍回應 → project ref 還在 Supabase 註冊表
- `list_tables` connection timeout → DB 無法連線
- 很可能是 Paused 或 Deleted grace period 中
- 要救資料：dashboard 看 restore 選項，或 7 天內寄信 support@supabase.com
