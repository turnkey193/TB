# ADR-0003: 人資打卡系統 Phase 5 設計決策

**日期**：2026-04-22
**Phase**：5（人資打卡系統第一期）
**狀態**：已確認，等資料齊全 kickoff

## Context

Phase 5 啟動前（已完成 Phase 0-4 + Plan B 子資料夾架構），跟使用者敲定第一期幾個關鍵設計決策。codex 審閱已完成（[`a-majestic-pixel.md`](../../../C:/Users/名御/.claude/plans/a-majestic-pixel.md) 有 15 個調整點，本決策已套用）。

## Decisions

### 1. 員工打卡登入方式：**員工代碼 + 密碼**，可選綁定 **LINE Login**

- 主要登入：員工代碼（員編）+ 密碼（bcrypt）
- 選用：LINE Login binding（讓員工綁完之後手機點 LINE 一鍵打卡，免再輸密碼）
- LINE binding 是 **optional**，不綁定也能用

### 1b. LINE 整合路線：**A → B 漸進升級**（不走 LMA 路線）

- **Phase 5 第一期**：A 一般網頁 + LINE Login binding
  - 零等待，立刻可上線
  - 不需 LINE 審核、不需 OA
- **Phase 5.5（之後升級）**：B LIFF App
  - 員工在 LINE 內無縫打卡，自動帶入 line_user_id
  - 不需 LINE 審核（只要有 LIFF Channel 即可）
  - 預估 2-3 天工作量
- **不採用 C LMA（LINE Mini App）路線**
  - 理由：要送 LINE 審核 2-4 週、要先有 OA 商家認證
  - 之後若需要在 LINE 內可被搜尋、看起來更正規再考慮

### 2. 8 家店 GPS 座標：**使用者提供地址，Claude 用 Google Geocoding 查座標**

- 8 家店：五股、板橋、東門、龜山、桃園、新竹、烏日、水湳
- 使用者提供完整地址 → Claude 透過 Google Maps Geocoding API 取得 lat/lng
- 預設 `radius_meters = 100`，啟用後若實測不準（室內 GPS 飄移），管理員可在後台調整

### 3. 員工資料來源：**Google Sheet 名單 + Excel 模板手動補齊**

- 第一期匯入：使用者提供 Google Sheet 員工名單給 Claude
- 缺漏欄位（薪資、勞健保、銀行帳號等）由使用者填 Excel 模板補齊
- Claude 提供 Excel 模板（含所有 hr.employees 必要欄位 + 工資清冊欄位）
- 上傳時用一次性匯入腳本批次寫入 hr.employees

## 已套用 codex 建議

| codex 建議 | Phase 5 套用方式 |
|---|---|
| 員工可授權多店打卡（不只 home_store） | `hr.employee_allowed_stores` 中間表（Phase 5b 新增） |
| 異常打卡審核流（不直接信 GPS） | `hr.punch_reviews` 表 + 主管審核 UI（Phase 5e 新增） |
| 身分證用欄位級加密、不用 hash | 用 `pgcrypto` extension 加密儲存（可解密供報稅） |
| 加班絕不自動推、必須申請 | 第一期不算加班，只記原始打卡 |
| 工資清冊欄位先補齊 | hr.employees schema 含勞基法第 7、23 條欄位 |
| 法定 5 年保存 + 可匯出明細 | Phase 5e 提供出勤明細 CSV 匯出 |
| Leaflet 地圖點選砍掉 | 改成手填座標 + Google Maps 連結驗證 |
| 員工 CRUD 瘦身 | 第一期只做：建立 / 停用 / 指派店別 / 多店授權 |
| 60 秒鎖太粗 | 改用冪等鍵（idempotency key） |
| 60-50m accuracy 一律拒絕太嚴 | 標記異常但仍記錄、待主管補正 |

## 時程重估

從原本 4-4.5 天 → **7-10 天**（增加多店、審核、加密、稽核軌跡的工作量）

## 資料準備清單

啟動 Phase 5 前需要使用者提供：
1. **8 家店地址**（Claude 拿去 geocode）
2. **員工 Google Sheet** + **填好的 Excel 模板**（Claude 提供模板）
3. **公司勞健保資料夾的格式**（用來設計勞健保 Phase 8 的對接方式 — 但 Phase 5 不用）

## 待後續 Phase 處理

| Phase | 範圍 | 預計時程 |
|---|---|---|
| 6 | 排班 + 假別 + 行事曆 | 5-7 天 |
| 7 | 薪資計算 | 7-10 天 |
| 8 | 勞健保 + 所得稅 | 5-7 天 |
| 9 | 報表匯出 | 3-5 天 |
