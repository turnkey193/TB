# 移交說明：tb-meeting 接入 portal SSO（2026-05-19/20）

> 這份是給未來的你（或其他 AI session）接手 SSO 後續工作用的快照。
> 詳細設計另見：
> - `docs/schema/COORDINATION_tb_meeting_sso_phase1_2026-05-19.md`（協調備忘）
> - `tb-meeting/CLAUDE.md`（子專案說明）
> - memory: `tb_subsystem_deployment_and_sso_roadmap`、`tb-portal-access-matrix`

---

## 一句話總結

**tb-meeting 已接 portal SSO，員工可從 portal 統一登入；admin 在 portal 勾「週會管理」會自動建 tb_user，然後在 tb-meeting 帳號管理頁設 region。舊帳密登入仍可用，後端 API 暫未強制驗身份（Phase 3b 待做）。**

---

## 已完成（Phase 1 ~ 3a-sync）

| 層級 | 改動 | 位置 |
|---|---|---|
| Schema | `hr.employees.employment_status` (internal/external/store_shared) | migration `20260519000000` |
| Schema | `public.tb_users.employee_id` + `last_sso_login_at` | 同上 |
| Schema | 15 個 tb_users 對應到 hr.employees（聖傑、逸昇高信心，其餘建 external 佔位） | migration `20260519000100` |
| Schema | DB trigger `hr.provision_tb_user_on_access()` — portal 勾就自動建 tb_user | migration `20260519010000` |
| Backend | tb-meeting `/auth/exchange` + `/auth/me` + `/auth/logout` + SSO_ENABLED gate | `tb-meeting/server.js` commit `d9f6ce1` |
| Backend | `/auth/exchange` 有 auto-provision fallback | commit `096ec70` |
| Frontend | App mount 打 /auth/me 載 cookie 身份 / logout 清 cookie / LoginPage 加 portal 按鈕 | commit `cebbe86` |
| Env | tb-meeting Zeabur 加 `JWT_SECRET`、`COOKIE_NAME=tbm_sess`、`SESSION_DAYS=30` | Zeabur Dashboard |
| Docs | 跨專案協調備忘、tb-meeting CLAUDE.md、tb-portal README 整合狀態更新 | `docs/schema/COORDINATION_tb_meeting_sso_phase1...` 等 |

---

## 2026-05-20 補丁（critical 漏洞修補）

跨專案審計後追加的最小幅度補洞：

| 項目 | 改動 |
|---|---|
| `tb-meeting/server.js` | `/api/admin/*` (10 個 endpoint) 全套 `requireAuth + requireAdmin`；`/api/login` 成功後也 `setSessionCookie`（legacy 登入也產生 cookie）；移除多餘的 `SUPABASE_KEY` 依賴 |
| `tb-meeting/Dockerfile` | 加 `ENV NODE_ENV=production`（讓 cookie `secure=true`）|
| `tb-meeting/src/main.jsx` | 加 fetch monkey-patch：same-origin fetch 自動帶 cookie，省去後續 Phase 3b 改 frontend |
| `tb-meeting/.env.example` | 移除 `SUPABASE_KEY` 註解 |

業務 `/api/*` 仍然沒套 requireAuth（仍是 Phase 3b 範圍），但 monkey-patch 把 frontend 端準備好，Phase 3b 只剩後端逐個套 middleware。

新建：[`docs/schema/SSO_EXCHANGE_CONTRACT.md`](schema/SSO_EXCHANGE_CONTRACT.md) — 給未來新子系統（tb-quotation/tb-cases）SSO 接入用的合約規範。

## 新發現的子系統（不在原 SSO roadmap 內）

| 資料夾 | GitHub | 部署狀態 | Schema |
|---|---|---|---|
| `工作管理表小工具/` | `17310a3-png/TB-gantt` | ✅ Zeabur `tb-gantt` 已部署 | （未確認）|
| `線上報價單/` | `17310a3-png/tb-quotation` | ❌ 未部署 | `quotation`（476 品項已建）|
| `行銷-案件資料/` | `17310a3-png/tb-cases`（空 repo） | ❌ 未部署 | `cases`（schema 已建、0 筆資料）|
| `人資薪資打卡系統/` | `17310a3-png/...` | ✅ Zeabur `tb-hr` 已部署 | `hr.*` |

之前 HANDOFF / memory 寫的「tb-gantt 子專案尚未存在」是錯的 — 它就是「工作管理表小工具」。
之前母 CLAUDE.md 寫的「人資薪資打卡系統 = 空資料夾」也是錯的 — 它就是 tb-hr。

## 未完成（Phase 3b、4、5）

### Phase 3b：業務 routes 套 requireAuth（高風險）

**為什麼是隱患**：tb-meeting 後端所有 `/api/*` 目前不檢查身份，懂技術的人知道網址就能繞登入撈資料。

**要動的範圍**：
1. `tb-meeting/server.js`（1005 行）：每個業務 route 加 `requireAuth`
2. `/api/login`：成功後也要 `setSessionCookie`（讓 legacy login 也產生 cookie）
3. `tb-meeting/src/App.jsx`（1500+ 行）：所有 `fetch('/api/...')` 加 `credentials: 'include'`
4. 必要的兼容性處理：legacy 用戶第一次重新登入會跨過渡

**何時做**：等 tb-meeting 流程穩定使用一段時間、想正式收緊安全時。

### Phase 4：過渡監控

audit log 表 + admin 儀表板顯示「SSO 登入 vs 帳密登入比例」。
要等 Phase 3b 做完才有意義（Phase 3b 之前帳密用戶根本不會產生 cookie）。

### Phase 5：砍 legacy login

監控比例 SSO > 95% 才執行。刪 `/api/login`、`bcrypt` 相關 import、`/api/account/password`。

---

## 常見操作 SOP（給總部 admin）

### 加新員工到 tb-meeting

1. 確認 `hr.employees` 已有該員工 row（HR 系統那邊建好）
2. 去 `https://tb-portal.zeabur.app` 權限管理頁，勾該員工的「週會管理」
3. **DB trigger 自動建 tb_user**（username = employee_code 小寫、role=admin、region=null）
4. 進 tb-meeting → 右上角齒輪 ⚙ 帳號管理 → 找到新員工 → 設定他的 region
5. 通知該員工：以後從 portal 點「週會管理」按鈕就能進

### 取消某員工的 tb-meeting 權限

- portal 取消勾選只阻止他「下次從 portal 進入」
- **不會自動刪掉** tb_users 那邊的帳號（避免破壞歷史紀錄）
- 要徹底斷他用 → 進 tb-meeting 帳號管理 ⚙ → 刪除他的帳號

### Debug SSO 失敗

員工從 portal 點按鈕進不去 tb-meeting，看瀏覽器網址 `?login_failed=XXX`：

| 錯誤代碼 | 意思 | 怎麼修 |
|---|---|---|
| `sso_disabled` | tb-meeting 沒設 JWT_SECRET 或 < 32 字元 | 檢查 Zeabur env vars |
| `invalid_or_expired` | JWT_SECRET 不一致或 token 過期（5 分鐘） | 確認 tb-portal/tb-meeting JWT_SECRET 同值 |
| `no_access` | portal access matrix 沒勾這個員工 tb-meeting | 去 portal 勾起來 |
| `no_tb_user` | 員工沒對應 tb_user（很罕見，trigger + auto-provision 應該擋掉） | 手動 INSERT 或檢查 trigger |
| `no_token` | URL 沒帶 token | 確認 portal 端的 redirect 邏輯 |

### 看 SSO 用了幾次

```sql
SELECT u.username, u.name, u.last_sso_login_at
FROM public.tb_users u
WHERE u.last_sso_login_at IS NOT NULL
ORDER BY u.last_sso_login_at DESC;
```

---

## 給其他開發者 / AI session 的提醒

### 改 hr.employees 要看 employment_status

```sql
-- 薪資/勞健保查詢應該 filter
WHERE employment_status = 'internal'
```

external 員工的 `apply_payroll / apply_*_insurance` 全 false，正常邏輯應該自然 skip，但建議顯式 filter。

### 改 tb_users 要保 employee_id 對應

`tb_users.employee_id` 是 SSO 流程的關鍵 — 任何手動改 tb_users 要保持這欄不被弄壞。

### 在 portal 勾選 = INSERT `hr.employee_subsystem_access`

DB trigger 會在 INSERT 時跑，subsystem='tb-meeting' 才會建 tb_user。如果未來加新子系統要類似機制，要寫對應的 trigger 或改邏輯。

### JWT_SECRET 要四邊一致

tb-portal / tb-hr / tb-org-dashboard / tb-meeting 共用 `btk6...0qJ`（在 Zeabur 各 service 的 env vars）。任何子系統改 JWT_SECRET 會打破 SSO 互信。

### tb-meeting 是獨立子專案

- GitHub: `17310a3-png/TB-meeting`（不是母 repo）
- Zeabur project: `tb-meeting`
- 本地路徑: `Desktop/TB project/tb-meeting/`（母 .gitignore 已排除）
- commit + push 要在 `tb-meeting/` 目錄底下做（無 auto-push hook，要手動 `git push origin main`）

---

## 重要關鍵字索引

- **portal 統一登入入口** — `https://tb-portal.zeabur.app`
- **portal access matrix** — `hr.employee_subsystem_access` 表 + portal admin UI
- **DB trigger 自動建 tb_user** — `hr.provision_tb_user_on_access()`
- **tb-meeting auth middleware** — `tb-meeting/server.js` `/auth/exchange`、`/auth/me`、`/auth/logout`
- **tb-meeting 帳號管理 UI** — App.jsx 內 view='accounts'，右上角齒輪 ⚙
- **SSO cookie 名稱** — `tbm_sess`（tb-meeting）、`tborg_sess`（tb-org-dashboard）等
- **共用 hr.employees 員工總名冊** — 39 → 51（之後可能還會增加）
- **共用 tb_regions 分店主表** — 8 家分店
- **2026-05-14 region_groups 衝突** — 已協調恢復，見另一份 COORDINATION doc

---

## 重要 commit 索引（按時序）

- `ab9cd8e` feat(sso-1cd): Phase 1c+1d — employment_status + tb_users SSO 欄 + external 佔位
- `ca6752d` docs(schema): tb-meeting SSO Phase 1 跨專案協調備忘
- `33856bb` (tb-meeting) docs: tb-meeting 子專案 CLAUDE.md
- `d9f6ce1` (tb-meeting) feat(sso): Phase 2 — /auth/exchange + middleware
- `cebbe86` (tb-meeting) feat(sso-3a): 前端 SSO 認知 + Portal 登入按鈕
- `096ec70` (tb-meeting) feat(sso-3a-fix): /auth/exchange auto-provision
- `40cf3c8` feat(sso-3): DB trigger — portal 勾 tb-meeting → 自動建 tb_user

---

**最後更新**：2026-05-20
**作者**：Claude（Opus 4.7）+ 用戶
