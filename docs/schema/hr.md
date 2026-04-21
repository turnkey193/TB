# `hr` Schema（佔位）

**狀態：尚未建立**

人資薪資打卡系統的資料表會放在這個 schema，屬於 Phase 5 的工作。

Phase 5 尚未啟動，等 Phase 0-4 完成後再開 kickoff 討論。

設計規劃參考 `C:\Users\名御\.claude\plans\a-majestic-pixel.md` 的 Phase 5 段落，第一期預計包含：

- `hr.stores_geo` — 店家 GPS 座標與地理圍欄半徑
- `hr.employees` — 員工基本資料（可選 FK 連結 `public.tb_users`）
- `hr.punches` — GPS 打卡紀錄（含稽核欄位）
