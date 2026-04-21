# `public` Schema

截至 **2026-04-21 Phase 4 完成**的狀態。此文件隨 migration 更新。

## 總表清單（10 張表 + 7 個 view）

### 業務表（新結構）

| 表 | 用途 | Rows | RLS | FK 關聯 |
|---|---|---|---|---|
| `tb_users` | 登入帳號（admin / region role） | 15 | ✅ | — |
| `tb_regions` | 分店主表（區域/Google Sheet 設定） | 8 | ✅ | — |
| `tb_user_regions` | 使用者 ↔ 分店多對多中間表（取代逗號字串） | 8 | ✅ | `user_id→tb_users`, `region_id→tb_regions` |
| `tb_statuses` | 狀態 lookup（note / payment 兩個 domain） | 6 | ✅ | — |
| `tb_weekly_notes` | 週會筆記 | 0 | ✅ | `region_id→tb_regions`, `status→tb_statuses` |
| `tb_payment_records` | 請款紀錄 | 38 | ✅ | `region_id→tb_regions`, `contract_status→tb_statuses`, `additional_status→tb_statuses` |
| `tb_expected_signs` | 預計簽約 | 0 | ✅ | `region_id→tb_regions` |
| `tb_project_notes` | 工程筆記 | 8 | ✅ | `region_id→tb_regions` |
| `tb_case_notes` | 案件備註 | 9 | ✅ | `region_id→tb_regions` |
| `tb_annual_targets` | 年度業績目標 | 8 | ✅ | `region_id→tb_regions` |

### Views（讀取端便利層）

| View | 對應表 | 用途 |
|---|---|---|
| `v_tb_weekly_notes` | tb_weekly_notes | 多回 `region_name`（JOIN 自 tb_regions） |
| `v_tb_payment_records` | tb_payment_records | 同上 |
| `v_tb_expected_signs` | tb_expected_signs | 同上 |
| `v_tb_project_notes` | tb_project_notes | 同上 |
| `v_tb_case_notes` | tb_case_notes | 同上 |
| `v_tb_annual_targets` | tb_annual_targets | 同上 |
| `v_tb_users_with_regions` | tb_users | 展開 user 的 `regions_csv` 與 `region_ids` 陣列（從 tb_user_regions 聚合） |

所有 view 都是 `SECURITY INVOKER`（呼叫者身分執行，RLS 正常生效）。

---

## 各表欄位（當前結構）

### `tb_users`

```
id              uuid         PK   gen_random_uuid()
username        text         unique
password_hash   text                        -- bcrypt，Phase 1 取代明碼 password
role            text         default 'region'   -- 'admin' | 'region'
region          text         nullable   -- 舊的逗號字串，保留作為相容層
                                          -- Phase 2 後真實關聯在 tb_user_regions
name            text
created_at      timestamptz  default now()
updated_at      timestamptz  default now()   -- Phase 3 新增，trigger 自動更新
```

### `tb_regions`

```
id           uuid         PK   gen_random_uuid()
name         text         unique
case_sheet   text         nullable   -- Google Sheet ID
work_sheet   text         nullable
case_tab     text         default '進度統計'
sort_order   integer      default 0
is_active    boolean      default true
created_at   timestamptz  default now()
updated_at   timestamptz  default now()
```

### `tb_user_regions` (Phase 2 新增)

```
user_id     uuid         NOT NULL  REFERENCES tb_users(id) ON DELETE CASCADE
region_id   uuid         NOT NULL  REFERENCES tb_regions(id) ON DELETE CASCADE
created_at  timestamptz  default now()
PRIMARY KEY (user_id, region_id)
```

### `tb_statuses` (Phase 3 新增)

```
code         text         PK
domain       text         NOT NULL          -- 'note' | 'payment'
label        text         NOT NULL
sort_order   integer      default 0
is_active    boolean      default true
created_at   timestamptz  default now()
updated_at   timestamptz  default now()
```

**已種資料**：
| code | domain | label |
|---|---|---|
| 未處理 | note | 未處理 |
| 處理中 | note | 處理中 |
| 已處理 | note | 已處理 |
| 時間未到 | payment | 時間未到 |
| 已收款 | payment | 已收款 |
| 收款異常 | payment | 收款異常 |

### `tb_weekly_notes`

```
id            uuid         PK   gen_random_uuid()
region        text                   -- 保留字串欄位作相容層
region_id     uuid         NOT NULL  REFERENCES tb_regions(id)
category      text
content       text
status        text         default '未處理'  REFERENCES tb_statuses(code)
meeting_date  date         default CURRENT_DATE
created_at    timestamptz  default now()
updated_at    timestamptz  default now()
```

### `tb_payment_records`

```
id                 uuid         PK   gen_random_uuid()
region             text
region_id          uuid         NOT NULL  REFERENCES tb_regions(id)
case_no            text
address            text         nullable
invoice_amount     integer      default 0
received_amount    integer      default 0
note               text         nullable
contract_amount    integer      default 0
contract_status    text         default '時間未到'  REFERENCES tb_statuses(code)
additional_amount  integer      default 0
additional_status  text         default '時間未到'  REFERENCES tb_statuses(code)
abnormal_note      text         default ''
created_at         timestamptz  default now()
updated_at         timestamptz  default now()
```

### `tb_expected_signs`

```
id             uuid         PK   gen_random_uuid()
region         text
region_id      uuid         NOT NULL  REFERENCES tb_regions(id)
address        text
amount         text         default ''   -- 歷史格式，未來可改 numeric
expected_date  text         default ''   -- 歷史格式，未來可改 date
note           text         default ''
meeting_date   date         default CURRENT_DATE
created_at     timestamptz  default now()
updated_at     timestamptz  default now()
```

### `tb_project_notes`

```
id           uuid         PK
region       text
region_id    uuid         NOT NULL  REFERENCES tb_regions(id)
case_no      text
note         text         default ''
is_abnormal  boolean      default false
created_at   timestamptz  default now()
updated_at   timestamptz  default now()
```

### `tb_case_notes`

```
id           uuid         PK
region       text         NOT NULL
region_id    uuid         NOT NULL  REFERENCES tb_regions(id)
case_id      text         NOT NULL
note         text         default ''
created_at   timestamptz  default now()
updated_at   timestamptz  default now()
UNIQUE(region, case_id)
```

### `tb_annual_targets`

```
id                     uuid         PK
region                 text         NOT NULL
region_id              uuid         NOT NULL  REFERENCES tb_regions(id)
year                   integer      default EXTRACT(YEAR FROM CURRENT_DATE)
milestone_revenue      integer      default 0
milestone_sign_rate    text         default ''
created_at             timestamptz  default now()
updated_at             timestamptz  default now()
UNIQUE(region, year)
```

---

## Triggers

`set_updated_at()` 函式（`SET search_path = pg_catalog, public`）掛在以下表：
`tb_regions`, `tb_users`, `tb_weekly_notes`, `tb_payment_records`, `tb_expected_signs`,
`tb_project_notes`, `tb_case_notes`, `tb_annual_targets`, `tb_statuses`

每次 `UPDATE` 自動把 `updated_at` 設為 `now()`。

---

## RLS 政策摘要

- 10 張表全部啟用 RLS
- 不建任何政策 = `anon` 與 `authenticated` 預設全部拒絕
- `service_role` 自動繞過 RLS
- 所有 `v_tb_*` view 都是 `SECURITY INVOKER`（不繞過 RLS）
- 詳情見 `decisions/0002-rls-backend-only.md`

---

## 歷史技術債（未在 Phase 0-4 處理，留給未來）

- `region` 字串欄位仍存在於 6 張業務表與 `tb_users`：為了前端相容保留，等 App.jsx 全面改用 `region_id` 後再 drop
- `tb_annual_targets.milestone_sign_rate` 是 text（應為 numeric/percent）
- `tb_expected_signs.amount`、`expected_date` 是 text（應為 numeric、date）
- `tb_users.region` 與 `tb_user_regions` 並存，寫入端由 `syncUserRegions` 維護一致性
