# [協調] 組織儀表板 ↔ HR 系統的 region_groups schema 衝突已恢復

嗨，

我這邊在開發**組織儀表板（tb-org-dashboard）**，跟你們做的 HR 打卡系統共用同一個 Supabase。今天發現一些 schema 變動造成組織儀表板無法新增職位/規劃人力，已經盤點後恢復了。寫這封訊息：

- 一方面同步狀況、列我做了什麼
- 二方面有 **3 件事想請你確認**，避免我們未來再互相踩到

---

## 📋 發生什麼事

組織儀表板的「新增職位」「指派員工」「人力規劃」等動作，今天開始連續出現 FK 違反錯誤：

```
Key (region_id)=(e9c12b6f-...) is not present in table "tb_region_groups"
violates foreign key constraint "org_position_plan_region_id_fkey"
```

盤點後發現：

1. 有人加了一張新表 `public.tb_region_groups`（4 筆：北北基、桃竹區、中彰區、總部）
2. `public.tb_regions` 加了欄位 `region_group_id` 指向 `tb_region_groups`
3. **4 個既有表的 `region_id` FK 從 `tb_regions` 改指 `tb_region_groups`**：
   - `hr.stores_geo.region_id`
   - `hr.org_position_regions.region_id`
   - `hr.org_position_plan.region_id`
   - `hr.org_sales_members.region_id`

第 1、2 點是合理的擴充（引入「大區」概念，分店歸屬到大區），組織儀表板可以接受並利用。

第 3 點影響大：**後三個是組織儀表板專屬的表**，原本設計是 `region_id = tb_regions.id`（個別分店 8 家），FK 被改成指 4 個大區後 → 既有 row 變 dangling + 新增 row 失敗 → 組織儀表板整個功能壞掉。

---

## ✅ 我這邊做了什麼（只動組織儀表板領域的表）

### 1. 把 3 個 FK 改回 `tb_regions`

```sql
-- 這 3 個表完全是組織儀表板專屬，跟 HR 系統沒共用
ALTER TABLE hr.org_position_regions
  ADD CONSTRAINT ..._region_id_fkey FOREIGN KEY (region_id) REFERENCES public.tb_regions(id);

ALTER TABLE hr.org_position_plan
  ADD CONSTRAINT ..._region_id_fkey FOREIGN KEY (region_id) REFERENCES public.tb_regions(id);

ALTER TABLE hr.org_sales_members
  ADD CONSTRAINT ..._region_id_fkey FOREIGN KEY (region_id) REFERENCES public.tb_regions(id);
```

### 2. archive 19 筆 dangling row 到新表

你們之前寫的「每個大區 × 每個職位」的 19 筆人力規劃資料（target_count、leaving_count）：

```sql
-- 看看當時的資料
SELECT payload
FROM hr.archive_org_position_plan_region_groups
ORDER BY archived_at DESC LIMIT 1;
```

`payload` 是 jsonb 陣列，每個元素含：`region_group_id` / `region_group_name` / `position_id` / `target_count` / `leaving_count` / `updated_at`。

→ 如果你們本來想做「大區層級規劃」功能，這份資料可以從這個 archive 還原（建議搭配下面提到的「另建表」做法）。

### 3. `hr.employees` 加 `home_region_id` 欄位

```sql
ALTER TABLE hr.employees
  ADD COLUMN home_region_id uuid REFERENCES public.tb_regions(id) ON DELETE SET NULL;
```

- 組織儀表板用這欄位記「員工主屬分店」
- nullable，**完全 backward-compatible**
- 你們的 `SAFE_EMP_FIELDS` 是明確列欄位（不是 `SELECT *`），不會撞到這個新欄位 → tb-hr 既有功能 0 影響
- 如果你們之後要顯示/編輯「員工屬於哪個區」，建議直接用這欄位（避免兩邊各建一個重複欄位）

### 4. `tb_regions.area` 8 家分店補齊

從你們的 `region_group_id` 對應過來：

| 分店 | area |
|---|---|
| 五股 / 板橋 / 東門 | 北北基 |
| 桃園 / 龜山 / 新竹 | 桃竹區 |
| 烏日 / 水湳 | 中彰區 |

組織儀表板的「大區顯示」直接用 `area` 欄位（用戶確認大區只是想分組顯示、不要獨立層級概念）。命名跟你們 `tb_region_groups.name` 一致，避免使用者看到兩套名字混淆。

---

## ⚠️ 我**刻意沒動**的（你們領域，請確認）

### `hr.stores_geo.region_id` 仍指向 `tb_region_groups`

```
hr.stores_geo (8 筆)
└─ region_id → tb_region_groups (北北基 / 桃竹區 / 中彰區 / 總部)
   不是      → tb_regions (五股 / 板橋 / ... 8 個個別分店)
```

我**刻意沒改回去**，因為 stores_geo 是 tb-hr 打卡的核心表，不確定你們現在設計的意圖。

**疑問**：打卡 GPS 邏輯通常是「精確到分店」（一家店一個 GPS 點 + 半徑），而非「整個大區共用一個 GPS 圈」對嗎？

- ✅ 如果是這樣 → `stores_geo.region_id` 應該指 `tb_regions`（個別分店），這個 FK 是 bug，建議改回 tb_regions
- 🤔 如果你們刻意設計成大區層級紀錄 → 那 GPS 半徑會涵蓋整個區（如「北北基」橫跨五股、板橋、東門），精度可能不夠員工打卡用

**請你確認意圖**。如果要改回 tb_regions，由你們處理（這個我不敢動，怕影響你們打卡邏輯）。

---

## 🟢 建議：跨團隊 schema 變動規矩

這次踩坑的根因：**直接改既有 column 的 FK 指向**，造成既有資料變 dangling、既有程式失效。

建議我們未來照這個走：

### ❌ 不要這樣做
```sql
-- 把既有 column 的 FK 從 A 改指 B
ALTER TABLE hr.org_position_plan
  DROP CONSTRAINT org_position_plan_region_id_fkey;
ALTER TABLE hr.org_position_plan
  ADD CONSTRAINT org_position_plan_region_id_fkey
    FOREIGN KEY (region_id) REFERENCES tb_region_groups(id);  -- ⚠️ 破壞既有資料
```

### ✅ 改成這樣做
```sql
-- 新增一個 column 表達新概念，跟既有 column 並存
ALTER TABLE hr.org_position_plan
  ADD COLUMN region_group_id uuid REFERENCES tb_region_groups(id);
-- region_id 還是指 tb_regions（個別分店）
-- region_group_id 是新概念（大區層級）
-- 兩個層級資料並存、互不影響
```

### 共用表變動前先 ping 對方

下列表是「我們兩邊都會用」的：

- `hr.employees`（HR 主表 + 組織儀表板讀寫）
- `public.tb_regions`（分店主表 + 組織儀表板 / tb-meeting / tb-hr 都用）
- `hr.stores_geo`（HR 打卡用，但組織儀表板原本透過它推導區域）
- `public.tb_users`（tb-meeting 用、組織儀表板透過 hr.employees.tb_user_id 連結）

這些表變動前**先 ping 對方** 30 秒確認影響範圍。30 秒換掉 1 小時 troubleshooting。

### 共用 schema 走遷移流程

`supabase/migrations/` 是兩邊共用的 migration 鏡像。每次改 schema 都應該 commit 對應 .sql 檔，方便：

- 追溯誰改了什麼、何時、為什麼
- 在 dev/staging 環境重現
- 復原（git revert）

---

## 📌 三個 Action Items（請你確認，等回應）

### 1. `hr.stores_geo.region_id` 的指向是 bug 嗎？

如果是 bug → 你那邊改回 `tb_regions(id)`，並把 8 筆 row 的 region_id 改成對應的個別分店 ID。

如果是刻意 → 告訴我為什麼，我這邊好理解你的設計。

### 2. `tb_region_groups` 還要留嗎？

用戶（17310a3-png）說「大區只是想分組顯示用」，已經用 `tb_regions.area` 欄位解決了。

- 如果你那邊有其他用途（例如大區層級權限、跨店排班、區經理身分等）→ 留著沒問題
- 如果只是想分組顯示、現在沒人在用 → 可以一起砍掉乾淨

### 3. 未來的協作規矩 OK 嗎？

- 不直接改既有 column 的 FK
- 共用表變動前先 ping
- migration 都 commit 進 git

如果你有更好的建議也歡迎提。

---

## 📂 相關文件 / SQL 位置

| 內容 | 位置 |
|---|---|
| 完整事件分析跟設計理由 | `docs/schema/COORDINATION_region_groups_2026-05-14.md` |
| 我做的 migrations | Supabase Studio → Database → Migrations，看 `restore_org_plan_sales_fk_to_tb_regions` |
| 19 筆大區規劃 backup | `hr.archive_org_position_plan_region_groups`（jsonb） |
| 組織儀表板 source | https://github.com/17310a3-png/tb-org-dashboard |

有任何疑問隨時找我討論，謝。
