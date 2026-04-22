# Supabase 專案轉移前快照

**時間**：2026-04-21
**專案**：`obgobetnlecbmypvfnsq`
**用途**：轉移 org 後用同一份基準比對，確認資料無遺失

## Row counts（轉移後應該完全一樣）

| Table | Rows |
|---|---:|
| tb_annual_targets | 8 |
| tb_case_notes | 9 |
| tb_expected_signs | 0 |
| tb_payment_records | 38 |
| tb_project_notes | 8 |
| tb_regions | 8 |
| tb_statuses | 6 |
| tb_user_regions | 8 |
| tb_users | 15 |
| tb_weekly_notes | 0 |
| **總計** | **100** |

## Migrations（轉移後應該都在，共 16 個）

| Version | Name |
|---|---|
| 20260415065437 | add_payment_new_columns |
| 20260415070401 | create_case_notes |
| 20260420033359 | create_tb_annual_targets |
| 20260420041543 | create_tb_regions_and_seed |
| 20260421041128 | add_password_hash_to_tb_users |
| 20260421041323 | drop_plaintext_password_from_tb_users |
| 20260421041521 | add_region_id_fk_columns |
| 20260421041534 | enforce_region_id_not_null |
| 20260421041537 | create_tb_user_regions_junction |
| 20260421041613 | create_region_read_views |
| 20260421041930 | create_tb_statuses_lookup |
| 20260421041933 | add_status_fk_constraints |
| 20260421041936 | add_missing_timestamps |
| 20260421041939 | create_updated_at_trigger |
| 20260421042140 | enable_rls_on_all_public_tables |
| 20260421042309 | harden_views_and_functions |

## 轉移後的驗證動作（告訴我轉完了，我自動跑）

1. 重跑上面的 row counts 查詢，應該逐欄完全一致
2. `list_migrations` 應該回傳同樣 16 筆
3. `get_advisors` security 應該只剩 10 個 INFO（與轉移前一致）
4. 啟動 server.js → `curl localhost:3001/api/regions` 應回傳 8 個分店
