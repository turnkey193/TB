# Brief: region_groups schema 衝突恢復 + 3 件事要確認

**對象**：tb-hr / 人資打卡系統開發對話
**日期**：2026-05-14
**狀態**：tb-org-dashboard 已恢復；3 個 action items 待確認

---

## 變動歷史推測

某個時點對方在 Supabase 做了這些變動：

1. 建 `public.tb_region_groups`（4 筆：北北基、桃竹區、中彰區、總部）
2. `public.tb_regions` 加 `region_group_id uuid FK → tb_region_groups`，8 家分店都已分組
3. 把以下 4 個 FK 從 `tb_regions` 改指 `tb_region_groups`：
   - `hr.stores_geo.region_id`
   - `hr.org_position_regions.region_id`
   - `hr.org_position_plan.region_id`
   - `hr.org_sales_members.region_id`
4. INSERT 19 筆「每大區 × 每職位」的 plan row 到 `hr.org_position_plan`

第 1、2 點 = 引入大區概念，OK。
第 3 點 = 改既有 column 的 FK，破壞 tb-org-dashboard 既有資料（19 row 變 dangling）+ 程式（FK violation）。

---

## tb-org-dashboard 端的恢復動作

### A. 3 個組織儀表板專屬表的 FK 改回 tb_regions

```sql
ALTER TABLE hr.org_position_regions
  DROP CONSTRAINT org_position_regions_region_id_fkey,
  ADD CONSTRAINT org_position_regions_region_id_fkey
    FOREIGN KEY (region_id) REFERENCES public.tb_regions(id) ON DELETE CASCADE;

ALTER TABLE hr.org_position_plan
  DROP CONSTRAINT org_position_plan_region_id_fkey,
  ADD CONSTRAINT org_position_plan_region_id_fkey
    FOREIGN KEY (region_id) REFERENCES public.tb_regions(id) ON DELETE CASCADE;

ALTER TABLE hr.org_sales_members
  DROP CONSTRAINT org_sales_members_region_id_fkey,
  ADD CONSTRAINT org_sales_members_region_id_fkey
    FOREIGN KEY (region_id) REFERENCES public.tb_regions(id) ON DELETE CASCADE;
```

### B. 19 筆 dangling row archive 後刪除

```sql
-- 看 archive
SELECT payload  -- jsonb array of { region_group_id, region_group_name, position_id, target_count, leaving_count, updated_at }
FROM hr.archive_org_position_plan_region_groups
ORDER BY archived_at DESC LIMIT 1;

DELETE FROM hr.org_position_plan
WHERE region_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.tb_regions r WHERE r.id = org_position_plan.region_id);
```

### C. hr.employees 加 home_region_id

```sql
ALTER TABLE hr.employees
  ADD COLUMN home_region_id uuid REFERENCES public.tb_regions(id) ON DELETE SET NULL;
```

組織儀表板用此欄位記員工主屬分店（取代原本透過 `stores_geo` lookup 的 hack）。
nullable，backward-compatible，tb-hr SAFE_EMP_FIELDS 沒列此欄位不會受影響。

### D. hr.org_employees_view 重建加 home_region_id

```sql
DROP VIEW IF EXISTS hr.org_employees_view;
CREATE VIEW hr.org_employees_view AS
SELECT id, employee_code, full_name, role, department, position,
       home_store_id, home_region_id, hire_date, termination_date,
       is_active, org_position_id, created_at, updated_at
FROM hr.employees;
ALTER VIEW hr.org_employees_view SET (security_invoker = true);
```

view 是組織儀表板讀員工資料用，不會暴露薪資/身分證等敏感欄位。

### E2. 新表 hr.region_supervisors（分店督導指派）

```sql
CREATE TABLE hr.region_supervisors (
  region_id uuid PRIMARY KEY REFERENCES public.tb_regions(id) ON DELETE CASCADE,
  supervisor_id bigint NOT NULL REFERENCES hr.employees(id) ON DELETE CASCADE,
  notes text,
  assigned_at timestamptz DEFAULT now(),
  assigned_by bigint REFERENCES hr.employees(id) ON DELETE SET NULL,
  updated_at timestamptz DEFAULT now()
);
```

設計：一店一督導（PK = region_id），一督導可管多店。
組織儀表板用此顯示「本店督導：XXX」+ 提供「按大區一鍵套用」功能。

**對 tb-hr 的潛在用途**：未來做請假/加班/打卡 review 流程時，可以查
「申請人 home_region_id → region_supervisors → 督導 → 推審核給督導」
而不是 hr.employees.role='manager' 廣播給所有主管。

如果 tb-hr 想用，直接 SELECT supervisor_id 即可，不需要動 schema。

### E. tb_regions.area 8 家補齊（從 region_group_id 對應）

```sql
UPDATE public.tb_regions r
SET area = g.name
FROM public.tb_region_groups g
WHERE r.region_group_id = g.id AND (r.area IS DISTINCT FROM g.name);
```

8 家 area 都填了：五股/板橋/東門=北北基、桃園/龜山/新竹=桃竹區、烏日/水湳=中彰區。
組織儀表板的「分店分組顯示」用 area 欄位，命名跟 tb_region_groups.name 一致。

---

## tb-org-dashboard 沒動的東西

- `hr.stores_geo` 任何欄位 / FK 都沒動
- `hr.employees` 除 home_region_id 之外的欄位沒動（薪資/身分證/銀行/聯絡都沒動）
- `public.tb_users` 沒動
- `public.tb_region_groups` 表本身沒動
- `public.tb_regions.region_group_id` 欄位沒動

---

## 3 個 Action Items

### 1. hr.stores_geo.region_id 指向確認

現況：`hr.stores_geo.region_id` 仍 FK → `tb_region_groups`（8 row 都指大區，dangling vs tb_regions）。

問題：GPS 打卡邏輯預期 region_id 是個別分店（一店一個 GPS 點 + 半徑）還是大區（一區一個範圍）？

- 若預期分店 → 是 bug，請改 FK 回 `tb_regions(id)` + UPDATE 8 row 的 region_id 為對應分店 ID
- 若刻意大區 → 確認 GPS 半徑能涵蓋整個大區（如「北北基」橫跨五股板橋東門，半徑可能要幾十公里），請說明設計

### 2. tb_region_groups 表的去留

用戶（17310a3-png）已澄清：大區只是想分組顯示用，組織儀表板用 `tb_regions.area` 解決。

如果 tb-hr 沒其他用途（排班/權限/區經理身分等），可以一起砍：

```sql
ALTER TABLE public.tb_regions DROP COLUMN region_group_id;
DROP TABLE public.tb_region_groups;
-- 前提：stores_geo.region_id 也改回 tb_regions 後才能砍 tb_region_groups
```

如果有其他用途請保留，但不要把它跟「分店 region_id」混用。

### 3. 大區層級規劃功能（如果你們本來想做）

19 筆 archive 資料表示對方 session 在做「每大區 × 每職位」的人力規劃。

如果真要做，建議**另建表**，不要動 org_position_plan：

```sql
CREATE TABLE hr.org_position_plan_by_group (
  region_group_id uuid REFERENCES tb_region_groups(id) ON DELETE CASCADE,
  position_id text REFERENCES hr.org_positions(id) ON DELETE CASCADE,
  target_count int DEFAULT 0,
  leaving_count int DEFAULT 0,
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (region_group_id, position_id)
);

-- 從 archive 還原
INSERT INTO hr.org_position_plan_by_group (region_group_id, position_id, target_count, leaving_count)
SELECT
  (item->>'region_group_id')::uuid,
  item->>'position_id',
  (item->>'target_count')::int,
  (item->>'leaving_count')::int
FROM hr.archive_org_position_plan_region_groups,
     jsonb_array_elements(payload) AS item
ORDER BY archived_at DESC LIMIT 1;
```

---

## 共用表清單（變動前互相 ping）

| 表 | 兩邊都用 |
|---|---|
| `hr.employees` | ✓ HR 主表 + 組織儀表板讀寫 home_region_id/org_position_id |
| `public.tb_regions` | ✓ 分店主表 + 多系統 |
| `hr.stores_geo` | ✓ 打卡用 + 組織儀表板原透過此 lookup（已改用 home_region_id 直接欄位） |
| `public.tb_users` | ✓ tb-meeting 用 + 組織儀表板透過 hr.employees.tb_user_id 連結 |

未來改這 4 個表的 schema 前先 cross-check。

## 規矩

1. 不改既有 column 的 FK 指向（要新概念加新 column）
2. 共用表變動前 ping 對方
3. migration 都 commit 到 `supabase/migrations/`（兩邊共用鏡像）
