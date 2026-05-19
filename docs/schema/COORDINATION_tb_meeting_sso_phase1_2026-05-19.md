# 跨專案協調備忘 — tb-meeting 接入 portal SSO（Phase 1 完成）

**日期**：2026-05-19
**影響系統**：tb-meeting + tb-portal + hr.employees + public.tb_users
**狀態**：Phase 1（資料對應準備）✅ 完成；Phase 2（tb-meeting backend SSO middleware）規劃完成、待實作

---

## 為什麼做這個

tb-meeting 是 TB 三個子系統裡**唯一還沒接 portal SSO 的**：

- tb-hr ✅ 已接 JWT
- tb-org-dashboard ✅ 已接 JWT
- tb-portal ✅ 上線並簽發 JWT（含 `sys[]` defense-in-depth）
- **tb-meeting ❌** 仍是 `public.tb_users` + bcrypt session

這次工作目標：把 tb-meeting 接進 SSO 體系。

---

## 困難點：兩本帳號名冊對不起來

| 名冊 | 用途 | 筆數 |
|---|---|---|
| `hr.employees` | 公司員工資料 source of truth（薪資、保險、職稱） | 26（皆 internal） |
| `public.tb_users` | tb-meeting 的登入帳號 | 15 |

兩本之間**完全沒對應關係**：
- `hr.employees.tb_user_id` 全部 NULL（0/26）
- tb-meeting 的「用戶」多半是**加盟商/分店主管**，不是 TB 公司員工
- 內部員工跟 tb_users 高信心對應只有 2 個（聖傑、逸昇）

如果不解決對應問題，portal 簽出來的 token 帶的是 `hr.employees.id`，tb-meeting 不知道要對應到哪個 tb_user → SSO 無法運作。

---

## Phase 1 做的事（已落地、已 commit）

### 1. `hr.employees` 加 `employment_status` 欄位

```sql
ALTER TABLE hr.employees
  ADD COLUMN employment_status text NOT NULL DEFAULT 'internal'
    CHECK (employment_status IN ('internal', 'external', 'store_shared'));
```

三種值的意思：
- **`internal`**（26 筆）— 正式員工，照原樣處理薪資/保險
- **`external`**（12 筆）— 加盟商 / 分店主管 / 暗名 admin。**資料未齊全的暫時佔位**，未來補資料時改 `internal`，不搬表
- **`store_shared`**（1 筆）— 分店共用帳號（如「烏日分店」），非自然人

⚠️ **跨系統影響**：薪資/勞保/健保相關查詢若不希望含 external，要加 `WHERE employment_status = 'internal'`。external 的 `apply_payroll / apply_labor_insurance / apply_health_insurance / apply_unemployment_insurance / apply_pension` 全部設成 `false`，正常薪資模組應該自然忽略。

### 2. `public.tb_users` 加 SSO 對應欄位

```sql
ALTER TABLE public.tb_users
  ADD COLUMN employee_id bigint REFERENCES hr.employees(id) ON DELETE SET NULL,
  ADD COLUMN last_sso_login_at timestamptz;
```

- `employee_id` 是 tb-meeting → hr 的雙向對應（hr 端用 `tb_user_id` 反指）
- `last_sso_login_at` 給 Phase 4 監控覆蓋率用

### 3. 對應回填（15/15 = 100%）

| tb_user | hr.employees | 處理 |
|---|---|---|
| 聖傑 (jason19790115) | id=6 王聖傑（設計主管） | 高信心 UPDATE |
| 逸昇 (p780120134) | id=7 陳逸昇（行銷主管） | 高信心 UPDATE |
| 其他 13 個 | 新建 id=31~43 | external/store_shared 佔位 row |

13 個新建的 row 使用 `EXT-<username>` 編碼，方便辨識，notes 欄位標註「SSO Phase 1: external 佔位」。

### 4. Migration 檔案

- `supabase/migrations/20260519000000_sso_phase1c_employee_status_and_tb_users_mapping.sql`
- `supabase/migrations/20260519000100_sso_phase1d_create_external_partner_rows.sql`

git commit: `ab9cd8e`（已 push 到 `17310a3-png/TB`）

---

## Phase 2 即將做的事（規劃完成）

動 `tb-meeting/server.js`（獨立 repo `17310a3-png/TB-meeting`）：

1. 加 `jsonwebtoken` + `cookie-parser` 依賴
2. 寫 `signSession / readSession / requireAuth`（複用 tb-org-dashboard `server.js:96-119` 的模式）
3. 寫 `/auth/exchange` endpoint：
   - 驗 portal 簽的 JWT
   - 驗 `payload.sys.includes('tb-meeting')`（defense-in-depth）
   - 用 `payload.tb_user_id` 找 `tb_users` row（fallback: `payload.sub` 對 `tb_users.employee_id`）
   - set cookie 並 redirect 回首頁
4. 寫 `resolveTbUser(payload)` helper
5. **不**掛 `requireAuth` 在現有 routes（避免 break 線上用戶）
6. `/api/login` 保留並存

---

## 對其他子系統的影響

| 子系統 | 影響 | 要做什麼 |
|---|---|---|
| **tb-hr / 人資打卡系統** | 看薪資/保險查詢有沒有過濾掉 `employment_status != 'internal'`。external 的 apply_* 都是 false，正常邏輯應該自然 skip 但建議顯式 filter | 確認薪資結算/勞健保查詢有 `WHERE employment_status = 'internal'` |
| **tb-org-dashboard** | 員工列表現在會多出 13 筆 external — 組織儀表板顯示員工時要決定要不要顯示 | 確認 `org_employees_view` 或前端列表是否要 filter `employment_status = 'internal'` |
| **tb-portal** | 已經 OK（portal_subsystems 表已註冊 tb-meeting，access matrix 已配 4 人） | Phase 2 完成後 portal `/api/exchange?to=tb-meeting` 會直接生效 |
| **tb-meeting** | Phase 2 動 server.js，Phase 3 套 requireAuth | 等 Phase 2/3 |

---

## 給未來 session 的注意事項

1. **不要把 external 當「假員工」刪掉** — 他們未來會變正式員工（用戶明確說過），刪了就要重建
2. **看到 `EXT-` 前綴的 employee_code 不是異常** — 是 SSO Phase 1 故意建的佔位
3. **薪資/保險/打卡等敏感操作要 filter `employment_status = 'internal'`**（除非有理由含 external）
4. **Phase 1d 的 13 個 employee_code 命名規則**：`EXT-<tb_users.username>` 或 `EXT-store-<region>`（分店帳號用後者）
5. 未來補齊資料 → external 轉 internal 的 SOP：
   ```sql
   UPDATE hr.employees
      SET employment_status = 'internal',
          id_number = ?, phone = ?, hire_date = ?, ...,
          apply_payroll = true, apply_labor_insurance = true, ...,
          notes = '原 SSO Phase 1 external 佔位，於 YYYY-MM-DD 補齊'
    WHERE employee_code = 'EXT-...';
   ```

---

## 關聯文件

- 設計 plan（5 個 phase 完整版）：本文件 + memory `tb_subsystem_deployment_and_sso_roadmap`
- portal access matrix 設計：memory `tb-portal-access-matrix`
- 上次跨專案協調（region_groups）：`docs/schema/COORDINATION_region_groups_2026-05-14.md`
