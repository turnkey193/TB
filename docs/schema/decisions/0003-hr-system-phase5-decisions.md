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

### 1c. 打卡方式：**Tier 1 在店內 + Tier 2 外勤**（雙模式）

考慮裝潢業特性（工務常在客戶家、業務外出丈量、設計師跑工地），純 GPS
圍欄會誤殺大量合理打卡。第一期就做雙模式：

#### Tier 1：店內打卡
- GPS 在 8 家店任一家的圍欄內
- **GPS + 自拍照**（前鏡頭拍臉，防代打卡）
- 自動歸類為 `in_store` 模式
- 工作時段算作辦公室時間

#### Tier 2：外勤打卡
- GPS 不在任何店家圍欄內
- **GPS + 工地照片** + 強制輸入：
  - 案件編號 / 客戶名稱（free text，可從 `tb_payment_records` 等已有資料推薦下拉）
  - 工地地址（自動從 GPS 反查 + 員工確認）
- 自動歸類為 `fieldwork` 模式
- 主管事後審核（沒審核的不算進工時）

#### 自動偵測流程
```
員工按打卡 → GPS getCurrentPosition →
   ├ 距離 ≤ allowed_store.radius_meters → Tier 1 自拍 → 直接成功
   └ 不在任何店家圍欄內 → Tier 2 拍工地 + 填案件 → 待主管審核
```

#### 不採用的方式
- WiFi MAC 比對：員工要記連 WiFi，麻煩；外勤店家也沒 WiFi
- iBeacon / NFC：硬體成本 + iPhone 支援差
- QR Code rotating：第一期太複雜，未來可加
- 純 GPS 無備援：誤殺 50% 外勤打卡，業務工務會抱怨

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

從原本 4-4.5 天 → 7-10 天 →
**10-14 天**（再加雙模式打卡 + 照片上傳 + Supabase Storage 整合）

## Schema 新增（套用 Tier 1 + Tier 2 後）

`hr.punches` 需要這些額外欄位：
- `punch_mode` text CHECK in ('in_store', 'fieldwork')
- `selfie_url` text nullable（Tier 1 必填，存 Supabase Storage URL）
- `site_photo_url` text nullable（Tier 2 必填）
- `field_context` text nullable（Tier 2 客戶/案件名稱）
- `field_address` text nullable（Tier 2 反查地址 + 員工確認）
- `related_case_no` text nullable（Tier 2 自動關聯到 tb_payment_records.case_no）

需要建 Supabase Storage bucket：
- `hr-punch-photos`（private bucket，只有 service_role + 主管可讀）
- 自動清理超過 5 年的照片（搭配出勤紀錄保存期）

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
