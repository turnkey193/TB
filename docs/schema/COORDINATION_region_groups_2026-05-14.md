# 跨專案協調備忘 — region_groups 概念引入後的 FK 衝突

**日期**：2026-05-14
**影響系統**：tb-org-dashboard ↔ tb-hr / 人資系統
**狀態**：tb-org-dashboard 已恢復、tb-hr 那邊待確認意圖

---

## 對方加了什麼

在 Supabase 加了：

1. 新表 `public.tb_region_groups`（4 筆：北北基 / 桃竹區 / 中彰區 / 總部）
2. `public.tb_regions` 加欄位 `region_group_id uuid FK → tb_region_groups`
3. 既有 8 家分店都已分到對應大區（五股→北北基、桃園→桃竹區、烏日→中彰區...）

**這部分合理，不衝突，保留**。

## 對方改錯的地方（造成衝突）

把 4 個既有表的 `region_id` FK 從 `tb_regions` **直接改指** `tb_region_groups`：

| 表 | 影響 |
|---|---|
| `hr.stores_geo.region_id` | tb-hr 打卡系統用，**保留**（對方領域） |
| `hr.org_position_regions.region_id` | 組織儀表板用，**已改回 tb_regions** |
| `hr.org_position_plan.region_id` | 組織儀表板用，**已改回 tb_regions**，並把 19 個 dangling row archive 後刪除 |
| `hr.org_sales_members.region_id` | 組織儀表板用，**已改回 tb_regions**（0 row 影響） |

## 為什麼這樣改是錯的

**不要直接改既有 column 的 FK**。應該**新增獨立的 column**：

```sql
-- 錯誤做法（會破壞既有資料 + 既有程式）
ALTER TABLE hr.org_position_plan
  DROP CONSTRAINT org_position_plan_region_id_fkey;
ALTER TABLE hr.org_position_plan
  ADD CONSTRAINT org_position_plan_region_id_fkey
    FOREIGN KEY (region_id) REFERENCES tb_region_groups(id);

-- 正確做法（兩層並存）
ALTER TABLE hr.org_position_plan
  ADD COLUMN region_group_id uuid REFERENCES tb_region_groups(id);
```

## 兩個系統的設計差異

| 視角 | tb-org-dashboard 的設計 | tb-hr 看起來的方向 |
|---|---|---|
| 人力規劃層級 | 每分店（8 家）+ 集團 | 每大區（4 個）|
| Sidebar 顯示 | 8 個分店 + 集團 | 待確認 |
| `org_position_plan.region_id` | tb_regions.id | 想改成 tb_region_groups.id |

我這邊（用戶要求）**保留分店層級**。

## 如果 tb-hr 那邊真的需要「大區層級規劃」

請另外建表，**不要動既有的** `org_position_plan` / `org_sales_members`：

```sql
CREATE TABLE hr.org_position_plan_by_group (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_group_id uuid REFERENCES tb_region_groups(id) ON DELETE CASCADE,
  position_id text REFERENCES hr.org_positions(id) ON DELETE CASCADE,
  target_count int DEFAULT 0,
  leaving_count int DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);
```

這樣大區層級跟分店層級可以**並存**，互不影響。

## Backup 位置（如果要還原大區層級資料）

19 筆對方寫的「大區層級 plan」資料已存到：

```sql
SELECT payload FROM hr.archive_org_position_plan_region_groups
ORDER BY archived_at DESC LIMIT 1;
```

`payload` 是 jsonb，含每筆 row 的 region_group_id / region_group_name / position_id / target / leaving。

## 跟對方對齊的事項

1. 同意「region_group 是 region 的上層」這個資料模型 ✓
2. 約定**不要動既有 column 的 FK**，要新概念就加新欄位
3. 如果之後需要「大區層級」功能，誰負責建新表？（建議：誰要那個功能誰建）
4. `hr.stores_geo` 我沒動，但它的 region_id 指 tb_region_groups 也怪 — 打卡精確店應該對應分店、不是大區。建議他們確認這個設計
